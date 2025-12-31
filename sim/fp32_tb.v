`timescale 1ns / 1ps

module tb_approx_l;

    // =========================================================================
    // Parameter Definitions
    // =========================================================================
    parameter D_WIDTH         = 32;
    parameter M_WIDTH         = 23;
    parameter E_WIDTH         = 8;
    parameter M               = 48;
    parameter PRECISION_LEVEL = 0; // 0 for default, 1 for 4-plane, 2 for 8-plane

    // =========================================================================
    // Signal Definitions
    // =========================================================================
    reg  [D_WIDTH-1:0] floating1_in;
    reg  [D_WIDTH-1:0] floating2_in;
    wire [D_WIDTH-1:0] floating_division_out;

    // =========================================================================
    // Statistical Variable Definitions (New)
    // =========================================================================
    shortreal sum_ae;       // Sum of Absolute Error
    shortreal sum_re;       // Sum of Relative Error
    shortreal sum_se;       // Sum of Squared Error
    integer   test_count;   // Test sample counter
    
    shortreal final_mae;
    shortreal final_mred;
    shortreal final_rmse;

    // =========================================================================
    // DUT (Device Under Test) Instantiation
    // =========================================================================
//    approx_l_divider u_approx_l (
//        .a(floating1_in),
//        .b(floating2_in),
//        .q(floating_division_out)
//    );
    approx_l_div_fp32 u_div (
        .a(floating1_in),
        .b(floating2_in),
        .q(floating_division_out)
    );
    // =========================================================================
    // Helper Function: Bit Conversion
    // =========================================================================
    function shortreal bits_to_float(input [31:0] val);
        return $bitstoshortreal(val);
    endfunction

    // =========================================================================
    // Test Flow
    // =========================================================================
    
    // Variables to store single calculation results
    shortreal real_a, real_b;
    shortreal golden_res;
    shortreal approx_res;
    shortreal abs_err;      // Absolute error of current test |approx - golden|
    shortreal rel_err;      // Relative error of current test |approx - golden| / |golden|
    shortreal sq_err;       // Squared error of current test (approx - golden)^2
    
    integer i;

    initial begin
        // Initialize statistical variables
        floating1_in = 0;
        floating2_in = 0;
        sum_ae = 0;
        sum_re = 0;
        sum_se = 0;
        test_count = 0;
        
        $display("---------------------------------------------------------------------------------------------------");
        $display("Starting Testbench for approx_l (Precision Level: %0d)", PRECISION_LEVEL);
        $display("Time\t\t A / B \t\t\t Golden \t Approx \t Abs Error \t Rel Error(%)");
        $display("---------------------------------------------------------------------------------------------------");

        // 1. Basic Test: Simple Values
        run_test(32'h3F800000, 32'h3F800000); // 1.0 / 1.0
        run_test(32'h40000000, 32'h3F800000); // 2.0 / 1.0
        run_test(32'h40400000, 32'h40000000); // 3.0 / 2.0 = 1.5
        run_test(32'h41200000, 32'h40A00000); // 10.0 / 5.0 = 2.0

        // 2. Random Test
        for (i = 0; i < 10000; i = i + 1) begin // Increase test count for more accurate statistics
            // Generate random non-zero floating point numbers
            floating1_in = $urandom_range(32'h3F000000, 32'h40000000); 
            floating2_in = $urandom_range(32'h3F000000, 32'h40000000);
            
            if (floating2_in == 0) floating2_in = 32'h3F800000; 

            run_test(floating1_in, floating2_in);
        end

        // 3. Sign Bit Test (Negative Division)
        run_test(32'hBF800000, 32'h3F800000); // -1.0 / 1.0
        run_test(32'hC0000000, 32'hC0000000); // -2.0 / -2.0

        // =========================================================================
        // Calculate and print final statistical metrics
        // =========================================================================
        if (test_count > 0) begin
            final_mae  = sum_ae / test_count;
            final_mred = sum_re / test_count;
            final_rmse = $sqrt(sum_se / test_count);
        end else begin
            final_mae = 0; final_mred = 0; final_rmse = 0;
        end

        $display("---------------------------------------------------------------------------------------------------");
        $display("Testbench Completed.");
        $display("Total Tests: %0d", test_count);
        $display("---------------------------------------------------------------------------------------------------");
        $display("Final Error Metrics:");
        $display("MAE  (Mean Absolute Error)        : %e", final_mae);
        $display("MRED (Mean Relative Error Dist.)  : %e", final_mred);
        $display("RMSE (Root Mean Square Error)     : %e", final_rmse);
        $display("---------------------------------------------------------------------------------------------------");
        
        $finish;
    end

    // =========================================================================
    // Task: Execute single test, print error, and accumulate statistics
    // =========================================================================
    task run_test(input [31:0] in1, input [31:0] in2);
        begin
            // Drive inputs
            floating1_in = in1;
            floating2_in = in2;

            // Wait for logic to settle
            #10;

            // Get real values
            real_a = bits_to_float(floating1_in);
            real_b = bits_to_float(floating2_in);

            // Calculate Golden
            golden_res = real_a / real_b;

            // Get Approx
            approx_res = bits_to_float(floating_division_out);

            // ---------------------------------------------------------
            // Error Calculation
            // ---------------------------------------------------------
            
            // 1. Absolute Error
            abs_err = (approx_res > golden_res) ? (approx_res - golden_res) : (golden_res - approx_res);
            
            // 2. Relative Error
            if (golden_res != 0.0)
                rel_err = abs_err / ((golden_res > 0) ? golden_res : -golden_res);
            else
                rel_err = 0.0;

            // 3. Squared Error
            sq_err = abs_err * abs_err;

            // ---------------------------------------------------------
            // Update Accumulators
            // ---------------------------------------------------------
            sum_ae = sum_ae + abs_err;
            sum_re = sum_re + rel_err;
            sum_se = sum_se + sq_err;
            test_count = test_count + 1;

            // ---------------------------------------------------------
            // Print single line result (To avoid flooding, could choose to print only first few or errors)
            // Keeping original print here, but displaying MRED in percentage format for readability
            // ---------------------------------------------------------
            // Note: rel_err is decimal (e.g., 0.01), need * 100 for percentage
            $display("%0t\t %6.4f / %6.4f \t %6.6f \t %6.6f \t %1.6f \t %2.4f%%", 
                     $time, real_a, real_b, golden_res, approx_res, (approx_res - golden_res), rel_err * 100.0);
        end
    endtask

endmodule