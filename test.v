`timescale 1ns / 1ps

module tb_knn_classification;

    reg clk;
    reg rst_n;
    reg [63:0] test_vector;
    wire [3:0] c1, c2, c3, c4, c5, final_class;

    // Instantiate the DUT
    knn_classification dut (
        .clk(clk),
        .rst_n(rst_n),
        .test_vector(test_vector),
        .c1(c1),
        .c2(c2),
        .c3(c3),
        .c4(c4),
        .c5(c5),
        .final_class(final_class)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 10ns period

    integer i;

    initial begin
        // Initialize
        rst_n = 0;
        test_vector = {16'd100, 16'd200, 16'd150, 16'd50}; // Example test input
        
        // Hold reset for 1 cycle
        @(posedge clk);
        rst_n = 1;  // release reset after first cycle

        // Wait 157 cycles for final output
        for (i = 0; i < 158; i = i + 1) begin
            @(posedge clk);
        end

        // Display final top 5 + voted class
        $display("Top 5 classes: %d %d %d %d %d", c1, c2, c3, c4, c5);
        $display("Final voted class: %d", final_class);

        $stop;
    end

endmodule
