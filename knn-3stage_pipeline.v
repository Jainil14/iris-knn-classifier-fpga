`timescale 1ns / 1ps

//============================================================================
// Module: knn_integrated_system (BRAM-OPTIMIZED)
// Description: K-Nearest Neighbors classifier for Iris dataset
// Updates: 
//   - Forced BRAM inference using (* ram_style = "block" *)
//   - Adjusted pipeline for 1-cycle BRAM read latency
//============================================================================

module knn_integrated_system (
    input  wire        clk,           
    input  wire        rst_n,         
    input  wire        start,         
    input  wire [31:0] test_vector,   
    output wire        busy,          
    output wire        result_valid,  
    output wire [3:0]  c1, c2, c3, c4, c5,
    output wire [3:0]  final_class    
);

    //========================================================================
    // Parameters
    //========================================================================
    parameter N_POINTS = 150;
    parameter PIPE_DEPTH = 4;        // Increased by 1 due to BRAM latency
    parameter FLUSH_CYCLES = 3;      // PIPE_DEPTH - 1
    parameter MAX_DIST = 20'hFFFFF;
    parameter INVALID_CLASS = 4'hF;
    
    //========================================================================
    // FSM State Encoding
    //========================================================================
    localparam [2:0] IDLE        = 3'b000;
    localparam [2:0] LOAD_POINTS = 3'b001;
    localparam [2:0] FLUSH_PIPE  = 3'b010;
    localparam [2:0] VOTE        = 3'b011;
    localparam [2:0] DONE        = 3'b100;
    
    //========================================================================
    // Section: BRAM ROM Storage
    //========================================================================
    // Force Vivado to use Block RAM instead of LUTs
    (* ram_style = "block" *) reg [33:0] rom [0:N_POINTS-1]; 
    initial $readmemb("dataset_iris_final_lat.mem", rom);
    
    reg [7:0] rom_addr;
    reg [33:0] rom_data; // Synchronous BRAM output

    always @(posedge clk) begin
        rom_data <= rom[rom_addr];
    end
    
    //========================================================================
    // Section: Control Logic & Pipeline Alignment
    //========================================================================
    reg [2:0] state, next_state;
    reg [1:0] flush_count;
    reg [31:0] test_vector_reg;
    reg valid_bram; // Latency alignment for BRAM read

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:        if (start) next_state = LOAD_POINTS;
            LOAD_POINTS: if (rom_addr == (N_POINTS - 1)) next_state = FLUSH_PIPE;
            FLUSH_PIPE:  if (flush_count == 2'd0) next_state = VOTE;
            VOTE:        next_state = DONE;
            DONE:        next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rom_addr <= 8'd0;
        else if (state == IDLE) rom_addr <= 8'd0;
        else if ((state == LOAD_POINTS) && (rom_addr < (N_POINTS - 1)))
            rom_addr <= rom_addr + 1'b1;
    end

    // valid_bram delays the 'start' of calculations by 1 cycle to wait for BRAM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_bram <= 1'b0;
        else valid_bram <= (state == LOAD_POINTS);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) test_vector_reg <= 32'd0;
        else if (start && state == IDLE) test_vector_reg <= test_vector;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) flush_count <= 2'd0;
        else if ((state == LOAD_POINTS) && (rom_addr == (N_POINTS - 1)))
            flush_count <= FLUSH_CYCLES;
        else if ((state == FLUSH_PIPE) && (flush_count > 2'd0))
            flush_count <= flush_count - 1'b1;
    end

    //========================================================================
    // Section: Feature Extraction (Now from Synchronous BRAM)
    //========================================================================
    wire [7:0] sl = rom_data[33:26];
    wire [7:0] sw = rom_data[25:18];
    wire [7:0] pl = rom_data[17:10];
    wire [7:0] pw = rom_data[9:2];
    wire [1:0] rom_class = rom_data[1:0];

    wire [7:0] test_sl = test_vector_reg[31:24];
    wire [7:0] test_sw = test_vector_reg[23:16];
    wire [7:0] test_pl = test_vector_reg[15:8];
    wire [7:0] test_pw = test_vector_reg[7:0];

    //========================================================================
    // Pipeline Stages (Total 3 Calculation Stages + 1 BRAM Stage = 4 Cycles)
    //========================================================================
    
    // Stage 1: Difference
    reg signed [8:0] diff_sl, diff_sw, diff_pl, diff_pw;
    reg [1:0] class_stage1;
    reg valid_stage1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage1 <= 1'b0;
        end else begin
            diff_sl <= $signed({1'b0, sl}) - $signed({1'b0, test_sl});
            diff_sw <= $signed({1'b0, sw}) - $signed({1'b0, test_sw});
            diff_pl <= $signed({1'b0, pl}) - $signed({1'b0, test_pl});
            diff_pw <= $signed({1'b0, pw}) - $signed({1'b0, test_pw});
            class_stage1 <= rom_class;
            valid_stage1 <= valid_bram;
        end
    end

    // Stage 2: Squares
    (*use_dsp="yes"*)
    reg signed [17:0] sq_sl, sq_sw, sq_pl, sq_pw;
    reg [1:0] class_stage2;
    reg valid_stage2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_stage2 <= 1'b0;
        else begin
            sq_sl <= diff_sl * diff_sl;
            sq_sw <= diff_sw * diff_sw;
            sq_pl <= diff_pl * diff_pl;
            sq_pw <= diff_pw * diff_pw;
            class_stage2 <= class_stage1;
            valid_stage2 <= valid_stage1;
        end
    end

    // Stage 3: Sum
    reg [19:0] final_sum;
    reg [1:0] class_stage3;
    reg valid_stage3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_stage3 <= 1'b0;
        else begin
            final_sum <= sq_sl + sq_sw + sq_pl + sq_pw;
            class_stage3 <= class_stage2;
            valid_stage3 <= valid_stage2;
        end
    end

    // Pipeline Output Buffer
    reg [19:0] dist_buffer;
    reg [3:0]  class_buffer;
    reg        valid_buffer;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_buffer <= 1'b0;
        else begin
            dist_buffer <= final_sum;
            class_buffer <= {2'b00, class_stage3};
            valid_buffer <= valid_stage3;
        end
    end

    //========================================================================
    // Section: Top-5 Sorter & Majority Vote (Logic remains the same)
    //========================================================================
    reg [19:0] r1, r2, r3, r4, r5;
    reg [3:0]  c1_reg, c2_reg, c3_reg, c4_reg, c5_reg;
    reg sorter_reset;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sorter_reset <= 1'b0;
        else sorter_reset <= ((state != LOAD_POINTS) && (next_state == LOAD_POINTS));
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || sorter_reset) begin
            r1 <= MAX_DIST; r2 <= MAX_DIST; r3 <= MAX_DIST; r4 <= MAX_DIST; r5 <= MAX_DIST;
            c1_reg <= INVALID_CLASS; c2_reg <= INVALID_CLASS; c3_reg <= INVALID_CLASS; 
            c4_reg <= INVALID_CLASS; c5_reg <= INVALID_CLASS;
        end else if (valid_buffer) begin
            if (dist_buffer < r1) begin
                r5 <= r4; r4 <= r3; r3 <= r2; r2 <= r1; r1 <= dist_buffer;
                c5_reg <= c4_reg; c4_reg <= c3_reg; c3_reg <= c2_reg; c2_reg <= c1_reg; c1_reg <= class_buffer;
            end else if (dist_buffer < r2) begin
                r5 <= r4; r4 <= r3; r3 <= r2; r2 <= dist_buffer;
                c5_reg <= c4_reg; c4_reg <= c3_reg; c3_reg <= c2_reg; c2_reg <= class_buffer;
            end else if (dist_buffer < r3) begin
                r5 <= r4; r4 <= r3; r3 <= dist_buffer;
                c5_reg <= c4_reg; c4_reg <= c3_reg; c3_reg <= class_buffer;
            end else if (dist_buffer < r4) begin
                r5 <= r4; r4 <= dist_buffer;
                c5_reg <= c4_reg; c4_reg <= class_buffer;
            end else if (dist_buffer < r5) begin
                r5 <= dist_buffer;
                c5_reg <= class_buffer;
            end
        end
    end

    assign {c1, c2, c3, c4, c5} = {c1_reg, c2_reg, c3_reg, c4_reg, c5_reg};

    // Voting Logic
    wire [2:0] cnt0 = (c1_reg==0)+(c2_reg==0)+(c3_reg==0)+(c4_reg==0)+(c5_reg==0);
    wire [2:0] cnt1 = (c1_reg==1)+(c2_reg==1)+(c3_reg==1)+(c4_reg==1)+(c5_reg==1);
    wire [2:0] cnt2 = (c1_reg==2)+(c2_reg==2)+(c3_reg==2)+(c4_reg==2)+(c5_reg==2);

    reg [3:0] voted_class_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) voted_class_reg <= 4'd0;
        else if (state == VOTE) begin
            if ((cnt0 >= cnt1) && (cnt0 >= cnt2)) voted_class_reg <= 4'd0;
            else if (cnt1 >= cnt2) voted_class_reg <= 4'd1;
            else voted_class_reg <= 4'd2;
        end
    end

    assign final_class = voted_class_reg;
    assign busy = (state != IDLE && state != DONE);

    reg result_valid_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) result_valid_reg <= 1'b0;
        else result_valid_reg <= (state == VOTE && next_state == DONE);
    end
    assign result_valid = result_valid_reg;

endmodule