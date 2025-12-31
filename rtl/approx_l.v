//Approx-L: Nearly Unbiased Approximate Floating-Point Divider with Multi-level Linearization
//yss

module approx_l_div_fp32 #(
  parameter int FRAC_BITS = 23,
  parameter int EXP_BITS  = 8,
  parameter int BIAS      = 127,

  // Reciprocal LUT: paper mentions small LUT (e.g., 16~32 entries).
  parameter int RECIP_ADDR_BITS = 8,   // 256 entries by default
  parameter int LEVEL = 0             // 0=No compensation, 1=4 planes, 2=8 planes, 3=16 planes
)(
  input  logic [31:0] a,
  input  logic [31:0] b,
  output logic [31:0] q
);

  localparam int M_W = FRAC_BITS + 1;   // Q1.FRAC => 1 integer bit + FRAC fractional bits
  localparam int EXT_W = FRAC_BITS + 4; // enough for scaled comparisons (<=8x,7x)

  // ----------------------------
  // Unpack FP32
  // ----------------------------
  logic sa, sb;
  logic [EXP_BITS-1:0] ea, eb;
  logic [FRAC_BITS-1:0] fa, fb;

  assign sa = a[31];
  assign ea = a[30:23];
  assign fa = a[22:0];

  assign sb = b[31];
  assign eb = b[30:23];
  assign fb = b[22:0];

  logic a_is_zero, b_is_zero, a_is_inf, b_is_inf, a_is_nan, b_is_nan;
  always_comb begin
    a_is_zero = (ea == '0) && (fa == '0);
    b_is_zero = (eb == '0) && (fb == '0);

    a_is_inf  = (ea == '1) && (fa == '0);
    b_is_inf  = (eb == '1) && (fb == '0);

    a_is_nan  = (ea == '1) && (fa != '0);
    b_is_nan  = (eb == '1) && (fb != '0);
  end

  // Subnormals not fully supported in this replica (treat as zero for simplicity)
  logic a_is_subn, b_is_subn;
  always_comb begin
    a_is_subn = (ea == '0) && (fa != '0);
    b_is_subn = (eb == '0) && (fb != '0);
  end

  // ----------------------------
  // x,y in [0,1): take fraction fields
  // ----------------------------
  logic [FRAC_BITS-1:0] x, y;
  assign x = fa;
  assign y = fb;

  // Compare x and y for Eq.(9)
  logic x_gt_y;
  assign x_gt_y = (x > y);

  // ----------------------------
  // Helper: multiply by small integer (0..7) using shift+add
  // ----------------------------
  function automatic logic [EXT_W-1:0] mul_small(
    input logic [FRAC_BITS-1:0] v,
    input int unsigned n
  );
    logic [EXT_W-1:0] vv;
    begin
      vv = {{(EXT_W-FRAC_BITS){1'b0}}, v};
      unique case (n)
        0: mul_small = '0;
        1: mul_small = vv;
        2: mul_small = (vv << 1);
        3: mul_small = (vv << 1) + vv;
        4: mul_small = (vv << 2);
        5: mul_small = (vv << 2) + vv;
        6: mul_small = (vv << 2) + (vv << 1);
        7: mul_small = (vv << 2) + (vv << 1) + vv;
        default: mul_small = vv * n; // shouldn't happen
      endcase
    end
  endfunction

  // Compare y < (num/2^den_sh) * x  <=>  (y << den_sh) < (x * num)
  function automatic logic lt_ratio_num_pow2den(
    input logic [FRAC_BITS-1:0] yy,
    input logic [FRAC_BITS-1:0] xx,
    input int unsigned num,              // 1..7
    input int unsigned den_sh            // 0..3 for /1,/2,/4,/8
  );
    logic [EXT_W-1:0] lhs, rhs;
    begin
      lhs = {{(EXT_W-FRAC_BITS){1'b0}}, yy} << den_sh;
      rhs = mul_small(xx, num);
      lt_ratio_num_pow2den = (lhs < rhs);
    end
  endfunction

  // Compare y < K*x where K is integer 2,3,4 (no division)
  function automatic logic lt_kx_int(
    input logic [FRAC_BITS-1:0] yy,
    input logic [FRAC_BITS-1:0] xx,
    input int unsigned k
  );
    logic [EXT_W-1:0] lhs, rhs;
    begin
      lhs = {{(EXT_W-FRAC_BITS){1'b0}}, yy};
      rhs = mul_small(xx, k);
      lt_kx_int = (lhs < rhs);
    end
  endfunction

  // ----------------------------
  // Eq.(9) Mantissa approximation in Q1.FRAC
  // m_lin = 1 + x - y
  // t     = 1 + y - x, m_recip ~= 1/t
  // ----------------------------
  logic signed [M_W:0] one_q1;
  assign one_q1 = $signed({1'b0, 1'b1, {FRAC_BITS{1'b0}}}); // 1.0 in Q1.FRAC

  logic signed [M_W:0] m_lin;
  logic signed [M_W:0] t_q1;

  always_comb begin
    m_lin = one_q1
          + $signed({1'b0, 1'b0, x})
          - $signed({1'b0, 1'b0, y});

    t_q1  = one_q1
          + $signed({1'b0, 1'b0, y})
          - $signed({1'b0, 1'b0, x}); // in x<=y region: t in [1,2)
  end

  // Reciprocal LUT (normalized input t in [1,2))
  logic [RECIP_ADDR_BITS-1:0] recip_addr;
  always_comb begin
    // t = 1.xxx, use MSBs of fraction as address
    recip_addr = t_q1[FRAC_BITS-1 -: RECIP_ADDR_BITS];
  end

  logic [M_W-1:0] recip_q1frac; // Q1.FRAC
  recip_lut_q1frac #(
    .FRAC_BITS (FRAC_BITS),
    .ADDR_BITS (RECIP_ADDR_BITS)
  ) u_recip (
    .addr (recip_addr),
    .r_q1frac (recip_q1frac)
  );

  logic signed [M_W:0] m_approx;
  always_comb begin
    if (x_gt_y) m_approx = m_lin;
    else        m_approx = $signed({1'b0, recip_q1frac});
  end

  // ----------------------------
  // Table II Region selection + coefficients (A,B,C)
  // Regions are defined over x,y in [0,1) exactly as Table II.
  // ----------------------------
  typedef struct packed {
    logic a_neg; logic [5:0] a_sh; // A = +/- 1/2^a_sh
    logic b_neg; logic [5:0] b_sh; // B = +/- 1/2^b_sh
    logic c_neg; logic [5:0] c_sh; // C = +/- 1/2^c_sh (constant)
    logic b_is_zero;
  } coeff_t;

  coeff_t coeff;

  // Shift term: term = sign * (val >> sh), val in Q1.FRAC (with integer bit 0)
// Shift term: term = sign * (val >> sh), val in Q1.FRAC (with integer bit 0)
  function automatic signed [M_W:0] term_from_frac(
    input logic [FRAC_BITS-1:0] v_q0,
    input logic neg,
    input logic [5:0] sh
  );
   logic signed  [M_W:0] tmp;
    begin
      tmp = $signed({1'b0, 1'b0, v_q0}); // Q1.FRAC with integer 0
      tmp = tmp >>> sh;
      if (neg) tmp = -tmp;
      term_from_frac = tmp;              // <-- 改这里：不要用 return
    end
  endfunction

  // Constant term: +/- 1/2^sh in Q1.FRAC
  function automatic signed [M_W:0] const_pow2(
    input logic neg,
    input logic [5:0] sh
  );
   logic signed [M_W:0] tmp;
    begin
      tmp = one_q1 >>> sh;
      if (neg) tmp = -tmp;
      const_pow2 = tmp;                  // <-- 改这里：不要用 return
    end
  endfunction

  // Region index
  int unsigned rid;

  always_comb begin
    rid = 0;
    coeff = '0;

    // default: no compensation
    if (LEVEL == 0) begin
      coeff = '0;
    end
    else if (LEVEL == 1) begin
      // Level 1 (4 planes):
      // R0: 0 <= y < 0.5x
      // R1: 0.5x <= y < x
      // R2: x <= y < 2x
      // R3: 2x <= y
      if (lt_ratio_num_pow2den(y, x, 1, 1)) begin
        rid = 0;
        // A=-1/16, B=-1/4, C= 1/64
        coeff.a_neg=1; coeff.a_sh=4;
        coeff.b_neg=1; coeff.b_sh=2;
        coeff.c_neg=0; coeff.c_sh=6;
      end
      else if (y < x) begin
        rid = 1;
        // A=-1/4, B= 1/4, C=-1/128
        coeff.a_neg=1; coeff.a_sh=2;
        coeff.b_neg=0; coeff.b_sh=2;
        coeff.c_neg=1; coeff.c_sh=7;
      end
      else if (lt_kx_int(y, x, 2)) begin
        rid = 2;
        // A=-1/16, B= 1/8, C=-1/128
        coeff.a_neg=1; coeff.a_sh=4;
        coeff.b_neg=0; coeff.b_sh=3;
        coeff.c_neg=1; coeff.c_sh=7;
      end
      else begin
        rid = 3;
        // A= 1/8, B= 1/32, C=-1/128
        coeff.a_neg=0; coeff.a_sh=3;
        coeff.b_neg=0; coeff.b_sh=5;
        coeff.c_neg=1; coeff.c_sh=7;
      end
    end
    else if (LEVEL == 2) begin
      // Level 2 (8 planes):
      // R0: y < 0.25x
      // R1: 0.25x <= y < 0.5x
      // R2: 0.5x <= y < 0.75x
      // R3: 0.75x <= y < x
      // R4: x <= y < 1.5x
      // R5: 1.5x <= y < 2x
      // R6: 2x <= y < 3x
      // R7: 3x <= y
      if (lt_ratio_num_pow2den(y, x, 1, 2)) begin
        rid = 0;
        // A=-1/32, B=-1/2, C=1/64
        coeff.a_neg=1; coeff.a_sh=5;
        coeff.b_neg=1; coeff.b_sh=1;
        coeff.c_neg=0; coeff.c_sh=6;
      end
      else if (lt_ratio_num_pow2den(y, x, 1, 1)) begin
        rid = 1;
        // A=-1/4, B=1/16, C=1/16
        coeff.a_neg=1; coeff.a_sh=2;
        coeff.b_neg=0; coeff.b_sh=4;
        coeff.c_neg=0; coeff.c_sh=4;
      end
      else if (lt_ratio_num_pow2den(y, x, 3, 2)) begin
        rid = 2;
        // A=-1/4, B=1/8, C=1/32
        coeff.a_neg=1; coeff.a_sh=2;
        coeff.b_neg=0; coeff.b_sh=3;
        coeff.c_neg=0; coeff.c_sh=5;
      end
      else if (y < x) begin
        rid = 3;
        // A=-1/2, B=1/2, C=1/128
        coeff.a_neg=1; coeff.a_sh=1;
        coeff.b_neg=0; coeff.b_sh=1;
        coeff.c_neg=0; coeff.c_sh=7;
      end
      else if (lt_ratio_num_pow2den(y, x, 3, 1)) begin // y < 1.5x  <=> 2y < 3x
        rid = 4;
        // A=-1/4, B=1/4, C=1/256
        coeff.a_neg=1; coeff.a_sh=2;
        coeff.b_neg=0; coeff.b_sh=2;
        coeff.c_neg=0; coeff.c_sh=8;
      end
      else if (lt_kx_int(y, x, 2)) begin
        rid = 5;
        // A=1/16, B=1/16, C=-1/64
        coeff.a_neg=0; coeff.a_sh=4;
        coeff.b_neg=0; coeff.b_sh=4;
        coeff.c_neg=1; coeff.c_sh=6;
      end
      else if (lt_kx_int(y, x, 3)) begin
        rid = 6;
        // A=1/8, B=1/32, C=-1/128
        coeff.a_neg=0; coeff.a_sh=3;
        coeff.b_neg=0; coeff.b_sh=5;
        coeff.c_neg=1; coeff.c_sh=7;
      end
      else begin
        rid = 7;
        // A=1/4, B=0, C=-1/256
        coeff.a_neg=0; coeff.a_sh=2;
        coeff.b_is_zero = 1'b1;
        coeff.c_neg=1; coeff.c_sh=8;
      end
    end
    else begin
      // LEVEL >= 3 : Level 3 (16 planes) per Table II
      // Boundaries: 0.125,0.25,0.375,0.5,0.625,0.75,0.875,1,1.25,1.5,1.75,2,2.5,3,4
      if (lt_ratio_num_pow2den(y, x, 1, 3)) begin // 0.125x
        rid = 0;
        // A=-1/32, B=-1/2, C=1/64
        coeff.a_neg=1; coeff.a_sh=5;
        coeff.b_neg=1; coeff.b_sh=1;
        coeff.c_neg=0; coeff.c_sh=6;
      end
      else if (lt_ratio_num_pow2den(y, x, 1, 2)) begin // 0.25x
        rid = 1;
        // A=-1/8, B=-1/8, C=1/32
        coeff.a_neg=1; coeff.a_sh=3;
        coeff.b_neg=1; coeff.b_sh=3;
        coeff.c_neg=0; coeff.c_sh=5;
      end
      else if (lt_ratio_num_pow2den(y, x, 3, 3)) begin // 0.375x = 3/8
        rid = 2;
        // A=-1/8, B=-1/8, C=1/32
        coeff.a_neg=1; coeff.a_sh=3;
        coeff.b_neg=1; coeff.b_sh=3;
        coeff.c_neg=0; coeff.c_sh=5;
      end
      else if (lt_ratio_num_pow2den(y, x, 1, 1)) begin // 0.5x
        rid = 3;
        // A=-1/4, B=1/16, C=1/16
        coeff.a_neg=1; coeff.a_sh=2;
        coeff.b_neg=0; coeff.b_sh=4;
        coeff.c_neg=0; coeff.c_sh=4;
      end
      else if (lt_ratio_num_pow2den(y, x, 5, 3)) begin // 0.625x = 5/8
        rid = 4;
        // A=-1/4, B=1/16, C=1/16
        coeff.a_neg=1; coeff.a_sh=2;
        coeff.b_neg=0; coeff.b_sh=4;
        coeff.c_neg=0; coeff.c_sh=4;
      end
      else if (lt_ratio_num_pow2den(y, x, 3, 2)) begin // 0.75x = 3/4
        rid = 5;
        // A=-1/8, B=-1/32, C=1/32
        coeff.a_neg=1; coeff.a_sh=3;
        coeff.b_neg=1; coeff.b_sh=5;
        coeff.c_neg=0; coeff.c_sh=5;
      end
      else if (lt_ratio_num_pow2den(y, x, 7, 3)) begin // 0.875x = 7/8
        rid = 6;
        // A=-1/2, B=1/2, C=1/64
        coeff.a_neg=1; coeff.a_sh=1;
        coeff.b_neg=0; coeff.b_sh=1;
        coeff.c_neg=0; coeff.c_sh=6;
      end
      else if (y < x) begin
        rid = 7;
        // A=-1/2, B=1/2, C=1/256
        coeff.a_neg=1; coeff.a_sh=1;
        coeff.b_neg=0; coeff.b_sh=1;
        coeff.c_neg=0; coeff.c_sh=8;
      end
      else if (lt_ratio_num_pow2den(y, x, 5, 2)) begin // 1.25x = 5/4
        rid = 8;
        // A=-1/4, B=1/4, C=1/256
        coeff.a_neg=1; coeff.a_sh=2;
        coeff.b_neg=0; coeff.b_sh=2;
        coeff.c_neg=0; coeff.c_sh=8;
      end
      else if (lt_ratio_num_pow2den(y, x, 3, 1)) begin // 1.5x = 3/2
        rid = 9;
        // A=-1/16, B=1/8, C=-1/128
        coeff.a_neg=1; coeff.a_sh=4;
        coeff.b_neg=0; coeff.b_sh=3;
        coeff.c_neg=1; coeff.c_sh=7;
      end
      else if (lt_ratio_num_pow2den(y, x, 7, 2)) begin // 1.75x = 7/4
        rid = 10;
        // A=1/16, B=1/16, C=-1/64
        coeff.a_neg=0; coeff.a_sh=4;
        coeff.b_neg=0; coeff.b_sh=4;
        coeff.c_neg=1; coeff.c_sh=6;
      end
      else if (lt_kx_int(y, x, 2)) begin
        rid = 11;
        // A=1/8, B=1/32, C=-1/64
        coeff.a_neg=0; coeff.a_sh=3;
        coeff.b_neg=0; coeff.b_sh=5;
        coeff.c_neg=1; coeff.c_sh=6;
      end
      else if (lt_ratio_num_pow2den(y, x, 5, 1)) begin // 2.5x = 5/2
        rid = 12;
        // A=1/8, B=1/32, C=-1/128
        coeff.a_neg=0; coeff.a_sh=3;
        coeff.b_neg=0; coeff.b_sh=5;
        coeff.c_neg=1; coeff.c_sh=7;
      end
      else if (lt_kx_int(y, x, 3)) begin
        rid = 13;
        // A=1/8, B=1/32, C=-1/128
        coeff.a_neg=0; coeff.a_sh=3;
        coeff.b_neg=0; coeff.b_sh=5;
        coeff.c_neg=1; coeff.c_sh=7;
      end
      else if (lt_kx_int(y, x, 4)) begin
        rid = 14;
        // A=1/8, B=1/32, C=-1/128
        coeff.a_neg=0; coeff.a_sh=3;
        coeff.b_neg=0; coeff.b_sh=5;
        coeff.c_neg=1; coeff.c_sh=7;
      end
      else begin
        rid = 15;
        // A=1/4, B=0, C=-1/256
        coeff.a_neg=0; coeff.a_sh=2;
        coeff.b_is_zero = 1'b1;
        coeff.c_neg=1; coeff.c_sh=8;
      end
    end
  end

  // ----------------------------
  // Compute compensation plane P = A*x + B*y + C  (Eq.(16),(17))
  // Then apply: m_refined = m_approx + P   (since m_err = m - m_approx)
  // ----------------------------
  logic signed [M_W:0] p;
  always_comb begin
    if (LEVEL == 0) begin
      p = '0;
    end else begin
      p = term_from_frac(x, coeff.a_neg, coeff.a_sh)
        + (coeff.b_is_zero ? '0 : term_from_frac(y, coeff.b_neg, coeff.b_sh))
        + const_pow2(coeff.c_neg, coeff.c_sh);
    end
  end

  logic signed [M_W:0] m_refined;
  always_comb begin
    m_refined = m_approx + p;
  end

  // ----------------------------
  // Exponent/sign and 1-bit normalization (paper: only +/-1 shift needed)
  // ----------------------------
  logic so;
  assign so = sa ^ sb;

  logic signed [10:0] exp_unbias_a, exp_unbias_b;
  logic signed [10:0] exp_q;
  logic signed [2:0]  exp_adj;
  logic [M_W:0] mant_norm;

  always_comb begin
    exp_unbias_a = $signed({1'b0, ea}) - BIAS;
    exp_unbias_b = $signed({1'b0, eb}) - BIAS;
    exp_adj = 0;

    mant_norm = (m_refined < 0) ? '0 : m_refined[M_W:0];

    // normalize to [1,2)
    if (mant_norm < (1 << FRAC_BITS)) begin
      mant_norm = mant_norm << 1;
      exp_adj   = -1;
    end else if (mant_norm >= (2 << FRAC_BITS)) begin
      mant_norm = mant_norm >> 1;
      exp_adj   = +1;
    end

    exp_q = exp_unbias_a - exp_unbias_b + exp_adj + BIAS;
  end

  // Pack output (truncate fraction; no IEEE rounding modes here)
  logic [EXP_BITS-1:0] eq;
  logic [FRAC_BITS-1:0] fq;
  always_comb begin
    eq = exp_q[EXP_BITS-1:0];
    fq = mant_norm[FRAC_BITS-1:0];

    // Minimal special cases
    if (a_is_nan || b_is_nan) begin
      q = {1'b0, 8'hFF, 23'h400000};          // qNaN
    end else if (a_is_inf && b_is_inf) begin
      q = {1'b0, 8'hFF, 23'h400000};          // NaN
    end else if (a_is_inf) begin
      q = {so, 8'hFF, 23'h0};                 // inf / finite
    end else if (b_is_inf) begin
      q = {so, 8'h00, 23'h0};                 // finite / inf => 0
    end else if (b_is_zero || b_is_subn) begin
      q = {so, 8'hFF, 23'h0};                 // divide by 0 => inf
    end else if (a_is_zero || a_is_subn) begin
      q = {so, 8'h00, 23'h0};                 // 0 / finite => 0
    end else begin
      // overflow/underflow clamp
      if (exp_q >= 255)       q = {so, 8'hFF, 23'h0};
      else if (exp_q <= 0)    q = {so, 8'h00, 23'h0};
      else                    q = {so, eq, fq};
    end
  end

endmodule

module recip_lut_q1frac #(
  parameter int FRAC_BITS = 23,
  parameter int ADDR_BITS = 5
)(
  input  logic [ADDR_BITS-1:0] addr,
  output logic [FRAC_BITS:0]    r_q1frac   // Q1.FRAC, range about (0.5..1]
);
  localparam int DEPTH = 1 << ADDR_BITS;

  // r_scaled = round( 2^FRAC / (1 + addr/2^ADDR) )
  //         = round( 2^(FRAC+ADDR) / (2^ADDR + addr) )
  function automatic int unsigned entry(input int unsigned i);
    int unsigned denom;
    longint unsigned num;
    begin
      denom = (1 << ADDR_BITS) + i;
      num   = 1;
      num   = num << (FRAC_BITS + ADDR_BITS);
      entry = (num + (denom >> 1)) / denom; // rounding
    end
  endfunction

  wire [FRAC_BITS:0] rom [0:DEPTH-1];

  genvar k;
  generate
    for (k = 0; k < DEPTH; k++) begin : GEN
      localparam int unsigned VAL = entry(k);
      assign rom[k] = VAL[FRAC_BITS:0];
    end
  endgenerate

  always_comb begin
    r_q1frac = rom[addr];
  end
endmodule