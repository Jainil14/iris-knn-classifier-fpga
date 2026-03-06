`timescale 1ns/1ps

module knn_integrated_system (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] test_vector,
    output wire        busy,
    output wire        result_valid,
    output wire [1:0]  c1,
    output wire [1:0]  c2,
    output wire [1:0]  c3,
    output wire [1:0]  c4,
    output wire [1:0]  c5,
    output wire [1:0]  final_class
);


    //-----------------------------------------------------------
    // Parameters
    //-----------------------------------------------------------
    parameter N_POINTS = 150;
    localparam MAX_DIST  = 20'hFFFFF;

    // Pipeline depth:
    // BRAM + diff + square + sum + buffer = 5 stages
    localparam FLUSH_CYC = 4;
        reg [7:0] rom_addr;

    //-----------------------------------------------------------
    // FSM
    //-----------------------------------------------------------
    localparam IDLE        = 3'd0;
    localparam LOAD_POINTS = 3'd1;
    localparam FLUSH_PIPE  = 3'd2;
    localparam VOTE1       = 3'd3;
    localparam VOTE2       = 3'd4;
    localparam DONE        = 3'd5;

    reg [2:0] state, next_state;
    reg [2:0] flush_count;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case(state)
            IDLE:        if(start) next_state = LOAD_POINTS;
            LOAD_POINTS: if(rom_addr == (N_POINTS-1)) next_state = FLUSH_PIPE;
            FLUSH_PIPE:  if(flush_count == 3'd0)       next_state = VOTE1;
            VOTE1:       next_state = VOTE2;
            VOTE2:       next_state = DONE;
            DONE:        next_state = IDLE;
        endcase
    end

    //-----------------------------------------------------------
    // ROM address + flush counter
    //-----------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            rom_addr <= 8'd0;
        else if(state == IDLE)
            rom_addr <= 8'd0;
        else if(state == LOAD_POINTS && rom_addr < (N_POINTS-1))
            rom_addr <= rom_addr + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            flush_count <= 3'd0;
        else if(state == LOAD_POINTS && rom_addr==(N_POINTS-1))
            flush_count <= FLUSH_CYC;
        else if(state == FLUSH_PIPE && flush_count > 3'd0)
            flush_count <= flush_count - 1'b1;
    end

    //-----------------------------------------------------------
    // Synchronous BRAM dataset: 150 x 34 bits
    //-----------------------------------------------------------
        (* ram_extract = "yes" *)
(* rom_style="block", ram_style="block" *)
    reg [33:0] rom [0:N_POINTS-1];

    initial $readmemb("dataset.mem", rom);

    reg [33:0] rom_data;

    always @(posedge clk) begin
            
            rom_data <= rom[rom_addr];
    end

    //-----------------------------------------------------------
    // Latch test vector
    //-----------------------------------------------------------
    reg [31:0] test_vector_reg;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            test_vector_reg <= 32'd0;
        else if(start && !busy)
            test_vector_reg <= test_vector;
    end

    //-----------------------------------------------------------
    // Extract features
    //-----------------------------------------------------------
    wire [7:0] SL = rom_data[33:26];
    wire [7:0] SW = rom_data[25:18];
    wire [7:0] PL = rom_data[17:10];
    wire [7:0] PW = rom_data[9:2];
    wire [1:0] rom_class = rom_data[1:0];

    wire [7:0] tSL = test_vector_reg[31:24];
    wire [7:0] tSW = test_vector_reg[23:16];
    wire [7:0] tPL = test_vector_reg[15:8];
    wire [7:0] tPW = test_vector_reg[7:0];

    //-----------------------------------------------------------
    // Valid pipeline: 5 stages
    //-----------------------------------------------------------
    reg v0,v1,v2,v3,v4;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            v0 <= 0; v1<=0; v2<=0; v3<=0; v4<=0;
        end else begin
            v0 <= (state==LOAD_POINTS);
            v1 <= v0;
            v2 <= v1;
            v3 <= v2;
            v4 <= v3;
        end
    end

    wire valid_stage1 = v1;
    wire valid_stage2 = v2;
    wire valid_stage3 = v3;
    wire valid_buf    = v4;

    //-----------------------------------------------------------
    // Stage 1: diff (with CE)
    //-----------------------------------------------------------
    wire ce_stage1 = (state==LOAD_POINTS);

    reg signed [8:0] dSL,dSW,dPL,dPW;
    reg [1:0] class_s1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dSL<=0; dSW<=0; dPL<=0; dPW<=0;
            class_s1<=0;
        end else if(ce_stage1) begin
            dSL <= $signed({1'b0,SL}) - $signed({1'b0,tSL});
            dSW <= $signed({1'b0,SW}) - $signed({1'b0,tSW});
            dPL <= $signed({1'b0,PL}) - $signed({1'b0,tPL});
            dPW <= $signed({1'b0,PW}) - $signed({1'b0,tPW});
            class_s1 <= rom_class;
        end
    end

    //-----------------------------------------------------------
    // Stage 2: square (DSP)
    //-----------------------------------------------------------
    (* use_dsp="no" *) reg signed [17:0] sqSL,sqSW,sqPL,sqPW;
    reg [1:0] class_s2;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sqSL<=0; sqSW<=0; sqPL<=0; sqPW<=0;
            class_s2<=0;
        end else begin
            sqSL <= dSL * dSL;
            sqSW <= dSW * dSW;
            sqPL <= dPL * dPL;
            sqPW <= dPW * dPW;
            class_s2 <= class_s1;
        end
    end

    //-----------------------------------------------------------
    // Stage 3: sum
    //-----------------------------------------------------------
    reg [19:0] sum3;
    reg [1:0]  class_s3;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sum3 <= 0;
            class_s3<=0;
        end else begin
            sum3 <= sqSL + sqSW + sqPL + sqPW;
            class_s3 <= class_s2;
        end
    end

    //-----------------------------------------------------------
    // Stage 4: output buffer
    //-----------------------------------------------------------
    reg [19:0] dist_buf;
    reg [1:0]  class_buf;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dist_buf <= 0;
            class_buf<=0;
        end else begin
            dist_buf <= sum3;
            class_buf<= class_s3;
        end
    end

    //-----------------------------------------------------------
    // Sorter reset pulse
    //-----------------------------------------------------------
    reg sorter_reset;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            sorter_reset <= 1'b0;
        else if(state!=LOAD_POINTS && next_state==LOAD_POINTS)
            sorter_reset <= 1'b1;
        else
            sorter_reset <= 1'b0;
    end

    //-----------------------------------------------------------
    // Insertion sorter (Top 5)
    //-----------------------------------------------------------
    reg [19:0] r1,r2,r3,r4,r5;
    reg [1:0]  c1r,c2r,c3r,c4r,c5r;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            r1<=MAX_DIST; r2<=MAX_DIST; r3<=MAX_DIST; r4<=MAX_DIST; r5<=MAX_DIST;
            c1r<=3; c2r<=3; c3r<=3; c4r<=3; c5r<=3;
        end else if(sorter_reset) begin
            r1<=MAX_DIST; r2<=MAX_DIST; r3<=MAX_DIST; r4<=MAX_DIST; r5<=MAX_DIST;
            c1r<=3; c2r<=3; c3r<=3; c4r<=3; c5r<=3;
        end else if(valid_buf) begin
            if(dist_buf<r1) begin
                r5<=r4; r4<=r3; r3<=r2; r2<=r1; r1<=dist_buf;
                c5r<=c4r; c4r<=c3r; c3r<=c2r; c2r<=c1r; c1r<=class_buf;
            end else if(dist_buf<r2) begin
                r5<=r4; r4<=r3; r3<=r2; r2<=dist_buf;
                c5r<=c4r; c4r<=c3r; c3r<=c2r; c2r<=class_buf;
            end else if(dist_buf<r3) begin
                r5<=r4; r4<=r3; r3<=dist_buf;
                c5r<=c4r; c4r<=c3r; c3r<=class_buf;
            end else if(dist_buf<r4) begin
                r5<=r4; r4<=dist_buf;
                c5r<=c4r; c4r<=class_buf;
            end else if(dist_buf<r5) begin
                r5<=dist_buf;
                c5r<=class_buf;
            end
        end
    end

    assign c1 = c1r;
    assign c2 = c2r;
    assign c3 = c3r;
    assign c4 = c4r;
    assign c5 = c5r;

    //-----------------------------------------------------------
    // Voting
    //-----------------------------------------------------------
    reg [2:0] n0,n1,n2;
    reg [1:0] voted;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            n0<=0; n1<=0; n2<=0;
        end else if(state==VOTE1) begin
            n0 <= (c1r==0)+(c2r==0)+(c3r==0)+(c4r==0)+(c5r==0);
            n1 <= (c1r==1)+(c2r==1)+(c3r==1)+(c4r==1)+(c5r==1);
            n2 <= (c1r==2)+(c2r==2)+(c3r==2)+(c4r==2)+(c5r==2);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            voted <= 2'd0;
        else if(state==VOTE2) begin
            if(n0>=n1 && n0>=n2)      voted<=2'd0;
            else if(n1>=n2)          voted<=2'd1;
            else                     voted<=2'd2;
        end
    end

    assign final_class = voted;

    //-----------------------------------------------------------
    // Handshake
    //-----------------------------------------------------------
    assign busy = (state==LOAD_POINTS) || (state==FLUSH_PIPE) || (state==VOTE1) || (state==VOTE2);

    reg rv;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            rv<=1'b0;
        else if(state==VOTE2 && next_state==DONE)
            rv<=1'b1;
        else
            rv<=1'b0;
    end

    assign result_valid = rv;

endmodule