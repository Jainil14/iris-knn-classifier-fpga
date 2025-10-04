`timescale 1ns / 1ps

module knn_classification (
    input  wire        clk,           
    input  wire        rst_n,         
    input  wire [63:0] test_vector,   // Test features: {pw[63:48], pl[47:32], sw[31:16], sl[15:0]}
    output wire [3:0]  c1, c2, c3, c4, c5,  // Top 5 sorted classes
    output wire [3:0]  final_class   
);

    // Internal Signals
  
    reg [33:0] dist_buffer;
    reg [3:0]  class_buffer;
    reg        valid_buffer;
    reg        sorter_reset;
    reg [4:0]  data_counter;
    reg        processing_complete;
    
   
    // ROM
  
 
 reg [65:0] rom [0:149];
initial begin
    rom[0] = {16'h0033, 16'h0023, 16'h000E, 16'h0002, 2'b00};
    rom[1] = {16'h0031, 16'h001E, 16'h000E, 16'h0002, 2'b00};
    rom[2] = {16'h002F, 16'h0020, 16'h000D, 16'h0002, 2'b00};
    rom[3] = {16'h002E, 16'h001F, 16'h000F, 16'h0002, 2'b00};
    rom[4] = {16'h0032, 16'h0024, 16'h000E, 16'h0002, 2'b00};
    rom[5] = {16'h0036, 16'h0027, 16'h0011, 16'h0004, 2'b00};
    rom[6] = {16'h002E, 16'h0022, 16'h000E, 16'h0003, 2'b00};
    rom[7] = {16'h0032, 16'h0022, 16'h000F, 16'h0002, 2'b00};
    rom[8] = {16'h002C, 16'h001D, 16'h000E, 16'h0002, 2'b00};
    rom[9] = {16'h0031, 16'h001F, 16'h000F, 16'h0001, 2'b00};
    rom[10] = {16'h0036, 16'h0025, 16'h000F, 16'h0002, 2'b00};
    rom[11] = {16'h0030, 16'h0022, 16'h0010, 16'h0002, 2'b00};
    rom[12] = {16'h0030, 16'h001E, 16'h000E, 16'h0001, 2'b00};
    rom[13] = {16'h002B, 16'h001E, 16'h000B, 16'h0001, 2'b00};
    rom[14] = {16'h003A, 16'h0028, 16'h000C, 16'h0002, 2'b00};
    rom[15] = {16'h0039, 16'h002C, 16'h000F, 16'h0004, 2'b00};
    rom[16] = {16'h0036, 16'h0027, 16'h000D, 16'h0004, 2'b00};
    rom[17] = {16'h0033, 16'h0023, 16'h000E, 16'h0003, 2'b00};
    rom[18] = {16'h0039, 16'h0026, 16'h0011, 16'h0003, 2'b00};
    rom[19] = {16'h0033, 16'h0026, 16'h000F, 16'h0003, 2'b00};
    rom[20] = {16'h0036, 16'h0022, 16'h0011, 16'h0002, 2'b00};
    rom[21] = {16'h0033, 16'h0025, 16'h000F, 16'h0004, 2'b00};
    rom[22] = {16'h002E, 16'h0024, 16'h000A, 16'h0002, 2'b00};
    rom[23] = {16'h0033, 16'h0021, 16'h0011, 16'h0005, 2'b00};
    rom[24] = {16'h0030, 16'h0022, 16'h0013, 16'h0002, 2'b00};
    rom[25] = {16'h0032, 16'h001E, 16'h0010, 16'h0002, 2'b00};
    rom[26] = {16'h0032, 16'h0022, 16'h0010, 16'h0004, 2'b00};
    rom[27] = {16'h0034, 16'h0023, 16'h000F, 16'h0002, 2'b00};
    rom[28] = {16'h0034, 16'h0022, 16'h000E, 16'h0002, 2'b00};
    rom[29] = {16'h002F, 16'h0020, 16'h0010, 16'h0002, 2'b00};
    rom[30] = {16'h0030, 16'h001F, 16'h0010, 16'h0002, 2'b00};
    rom[31] = {16'h0036, 16'h0022, 16'h000F, 16'h0004, 2'b00};
    rom[32] = {16'h0034, 16'h0029, 16'h000F, 16'h0001, 2'b00};
    rom[33] = {16'h0037, 16'h002A, 16'h000E, 16'h0002, 2'b00};
    rom[34] = {16'h0031, 16'h001F, 16'h000F, 16'h0001, 2'b00};
    rom[35] = {16'h0032, 16'h0020, 16'h000C, 16'h0002, 2'b00};
    rom[36] = {16'h0037, 16'h0023, 16'h000D, 16'h0002, 2'b00};
    rom[37] = {16'h0031, 16'h001F, 16'h000F, 16'h0001, 2'b00};
    rom[38] = {16'h002C, 16'h001E, 16'h000D, 16'h0002, 2'b00};
    rom[39] = {16'h0033, 16'h0022, 16'h000F, 16'h0002, 2'b00};
    rom[40] = {16'h0032, 16'h0023, 16'h000D, 16'h0003, 2'b00};
    rom[41] = {16'h002D, 16'h0017, 16'h000D, 16'h0003, 2'b00};
    rom[42] = {16'h002C, 16'h0020, 16'h000D, 16'h0002, 2'b00};
    rom[43] = {16'h0032, 16'h0023, 16'h0010, 16'h0006, 2'b00};
    rom[44] = {16'h0033, 16'h0026, 16'h0013, 16'h0004, 2'b00};
    rom[45] = {16'h0030, 16'h001E, 16'h000E, 16'h0003, 2'b00};
    rom[46] = {16'h0033, 16'h0026, 16'h0010, 16'h0002, 2'b00};
    rom[47] = {16'h002E, 16'h0020, 16'h000E, 16'h0002, 2'b00};
    rom[48] = {16'h0035, 16'h0025, 16'h000F, 16'h0002, 2'b00};
    rom[49] = {16'h0032, 16'h0021, 16'h000E, 16'h0002, 2'b00};
    rom[50] = {16'h0046, 16'h0020, 16'h002F, 16'h000E, 2'b01};
    rom[51] = {16'h0040, 16'h0020, 16'h002D, 16'h000F, 2'b01};
    rom[52] = {16'h0045, 16'h001F, 16'h0031, 16'h000F, 2'b01};
    rom[53] = {16'h0037, 16'h0017, 16'h0028, 16'h000D, 2'b01};
    rom[54] = {16'h0041, 16'h001C, 16'h002E, 16'h000F, 2'b01};
    rom[55] = {16'h0039, 16'h001C, 16'h002D, 16'h000D, 2'b01};
    rom[56] = {16'h003F, 16'h0021, 16'h002F, 16'h0010, 2'b01};
    rom[57] = {16'h0031, 16'h0018, 16'h0021, 16'h000A, 2'b01};
    rom[58] = {16'h0042, 16'h001D, 16'h002E, 16'h000D, 2'b01};
    rom[59] = {16'h0034, 16'h001B, 16'h0027, 16'h000E, 2'b01};
    rom[60] = {16'h0032, 16'h0014, 16'h0023, 16'h000A, 2'b01};
    rom[61] = {16'h003B, 16'h001E, 16'h002A, 16'h000F, 2'b01};
    rom[62] = {16'h003C, 16'h0016, 16'h0028, 16'h000A, 2'b01};
    rom[63] = {16'h003D, 16'h001D, 16'h002F, 16'h000E, 2'b01};
    rom[64] = {16'h0038, 16'h001D, 16'h0024, 16'h000D, 2'b01};
    rom[65] = {16'h0043, 16'h001F, 16'h002C, 16'h000E, 2'b01};
    rom[66] = {16'h0038, 16'h001E, 16'h002D, 16'h000F, 2'b01};
    rom[67] = {16'h003A, 16'h001B, 16'h0029, 16'h000A, 2'b01};
    rom[68] = {16'h003E, 16'h0016, 16'h002D, 16'h000F, 2'b01};
    rom[69] = {16'h0038, 16'h0019, 16'h0027, 16'h000B, 2'b01};
    rom[70] = {16'h003B, 16'h0020, 16'h0030, 16'h0012, 2'b01};
    rom[71] = {16'h003D, 16'h001C, 16'h0028, 16'h000D, 2'b01};
    rom[72] = {16'h003F, 16'h0019, 16'h0031, 16'h000F, 2'b01};
    rom[73] = {16'h003D, 16'h001C, 16'h002F, 16'h000C, 2'b01};
    rom[74] = {16'h0040, 16'h001D, 16'h002B, 16'h000D, 2'b01};
    rom[75] = {16'h0042, 16'h001E, 16'h002C, 16'h000E, 2'b01};
    rom[76] = {16'h0044, 16'h001C, 16'h0030, 16'h000E, 2'b01};
    rom[77] = {16'h0043, 16'h001E, 16'h0032, 16'h0011, 2'b01};
    rom[78] = {16'h003C, 16'h001D, 16'h002D, 16'h000F, 2'b01};
    rom[79] = {16'h0039, 16'h001A, 16'h0023, 16'h000A, 2'b01};
    rom[80] = {16'h0037, 16'h0018, 16'h0026, 16'h000B, 2'b01};
    rom[81] = {16'h0037, 16'h0018, 16'h0025, 16'h000A, 2'b01};
    rom[82] = {16'h003A, 16'h001B, 16'h0027, 16'h000C, 2'b01};
    rom[83] = {16'h003C, 16'h001B, 16'h0033, 16'h0010, 2'b01};
    rom[84] = {16'h0036, 16'h001E, 16'h002D, 16'h000F, 2'b01};
    rom[85] = {16'h003C, 16'h0022, 16'h002D, 16'h0010, 2'b01};
    rom[86] = {16'h0043, 16'h001F, 16'h002F, 16'h000F, 2'b01};
    rom[87] = {16'h003F, 16'h0017, 16'h002C, 16'h000D, 2'b01};
    rom[88] = {16'h0038, 16'h001E, 16'h0029, 16'h000D, 2'b01};
    rom[89] = {16'h0037, 16'h001E, 16'h0028, 16'h000D, 2'b01};
    rom[90] = {16'h0037, 16'h0019, 16'h002C, 16'h000C, 2'b01};
    rom[91] = {16'h003D, 16'h001E, 16'h002E, 16'h000E, 2'b01};
    rom[92] = {16'h003A, 16'h001A, 16'h0028, 16'h000C, 2'b01};
    rom[93] = {16'h0032, 16'h0017, 16'h0021, 16'h000A, 2'b01};
    rom[94] = {16'h0038, 16'h001B, 16'h002A, 16'h000D, 2'b01};
    rom[95] = {16'h0039, 16'h001E, 16'h002A, 16'h000C, 2'b01};
    rom[96] = {16'h0039, 16'h001D, 16'h002A, 16'h000D, 2'b01};
    rom[97] = {16'h003E, 16'h001D, 16'h002B, 16'h000D, 2'b01};
    rom[98] = {16'h0033, 16'h0019, 16'h001E, 16'h000B, 2'b01};
    rom[99] = {16'h0039, 16'h001C, 16'h0029, 16'h000D, 2'b01};
    rom[100] = {16'h003F, 16'h0021, 16'h003C, 16'h0019, 2'b10};
    rom[101] = {16'h003A, 16'h001B, 16'h0033, 16'h0013, 2'b10};
    rom[102] = {16'h0047, 16'h001E, 16'h003B, 16'h0015, 2'b10};
    rom[103] = {16'h003F, 16'h001D, 16'h0038, 16'h0012, 2'b10};
    rom[104] = {16'h0041, 16'h001E, 16'h003A, 16'h0016, 2'b10};
    rom[105] = {16'h004C, 16'h001E, 16'h0042, 16'h0015, 2'b10};
    rom[106] = {16'h0031, 16'h0019, 16'h002D, 16'h0011, 2'b10};
    rom[107] = {16'h0049, 16'h001D, 16'h003F, 16'h0012, 2'b10};
    rom[108] = {16'h0043, 16'h0024, 16'h003A, 16'h0012, 2'b10};
    rom[109] = {16'h0048, 16'h0020, 16'h003D, 16'h0019, 2'b10};
    rom[110] = {16'h0041, 16'h0020, 16'h0033, 16'h0014, 2'b10};
    rom[111] = {16'h0040, 16'h001B, 16'h0035, 16'h0013, 2'b10};
    rom[112] = {16'h0044, 16'h001E, 16'h0037, 16'h0015, 2'b10};
    rom[113] = {16'h0039, 16'h0019, 16'h0032, 16'h0014, 2'b10};
    rom[114] = {16'h003A, 16'h001C, 16'h0033, 16'h0018, 2'b10};
    rom[115] = {16'h0040, 16'h0020, 16'h0035, 16'h0017, 2'b10};
    rom[116] = {16'h0041, 16'h001E, 16'h0037, 16'h0012, 2'b10};
    rom[117] = {16'h004D, 16'h0026, 16'h0043, 16'h0016, 2'b10};
    rom[118] = {16'h004D, 16'h001A, 16'h0045, 16'h0017, 2'b10};
    rom[119] = {16'h003C, 16'h0016, 16'h0032, 16'h000F, 2'b10};
    rom[120] = {16'h0045, 16'h0020, 16'h0039, 16'h0017, 2'b10};
    rom[121] = {16'h0038, 16'h001C, 16'h0031, 16'h0014, 2'b10};
    rom[122] = {16'h004D, 16'h001C, 16'h0043, 16'h0014, 2'b10};
    rom[123] = {16'h003F, 16'h001B, 16'h0031, 16'h0012, 2'b10};
    rom[124] = {16'h0043, 16'h0021, 16'h0039, 16'h0015, 2'b10};
    rom[125] = {16'h0048, 16'h0020, 16'h003C, 16'h0012, 2'b10};
    rom[126] = {16'h003E, 16'h001C, 16'h0030, 16'h0012, 2'b10};
    rom[127] = {16'h003D, 16'h001E, 16'h0031, 16'h0012, 2'b10};
    rom[128] = {16'h0040, 16'h001C, 16'h0038, 16'h0015, 2'b10};
    rom[129] = {16'h0048, 16'h001E, 16'h003A, 16'h0010, 2'b10};
    rom[130] = {16'h004A, 16'h001C, 16'h003D, 16'h0013, 2'b10};
    rom[131] = {16'h004F, 16'h0026, 16'h0040, 16'h0014, 2'b10};
    rom[132] = {16'h0040, 16'h001C, 16'h0038, 16'h0016, 2'b10};
    rom[133] = {16'h003F, 16'h001C, 16'h0033, 16'h000F, 2'b10};
    rom[134] = {16'h003D, 16'h001A, 16'h0038, 16'h000E, 2'b10};
    rom[135] = {16'h004D, 16'h001E, 16'h003D, 16'h0017, 2'b10};
    rom[136] = {16'h003F, 16'h0022, 16'h0038, 16'h0018, 2'b10};
    rom[137] = {16'h0040, 16'h001F, 16'h0037, 16'h0012, 2'b10};
    rom[138] = {16'h003C, 16'h001E, 16'h0030, 16'h0012, 2'b10};
    rom[139] = {16'h0045, 16'h001F, 16'h0036, 16'h0015, 2'b10};
    rom[140] = {16'h0043, 16'h001F, 16'h0038, 16'h0018, 2'b10};
    rom[141] = {16'h0045, 16'h001F, 16'h0033, 16'h0017, 2'b10};
    rom[142] = {16'h003A, 16'h001B, 16'h0033, 16'h0013, 2'b10};
    rom[143] = {16'h0044, 16'h0020, 16'h003B, 16'h0017, 2'b10};
    rom[144] = {16'h0043, 16'h0021, 16'h0039, 16'h0019, 2'b10};
    rom[145] = {16'h0043, 16'h001E, 16'h0034, 16'h0017, 2'b10};
    rom[146] = {16'h003F, 16'h0019, 16'h0032, 16'h0013, 2'b10};
    rom[147] = {16'h0041, 16'h001E, 16'h0034, 16'h0014, 2'b10};
    rom[148] = {16'h003E, 16'h0022, 16'h0036, 16'h0017, 2'b10};
    rom[149] = {16'h003B, 16'h001E, 16'h0033, 16'h0012, 2'b10};
end
   
    // ROM Sequencer
    
    reg [7:0] rom_addr;
    reg [4:0] point_count;
    wire [65:0] rom_data = rom[rom_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rom_addr  <= 8'd0;
            point_count <= 8'd0;
            data_counter <= 8'd0;
            processing_complete <= 1'b0;
        end else if (rom_addr < 8'd149) begin
            rom_addr   <= rom_addr + 1'b1;
            point_count <= point_count + 1'b1;
            data_counter <= data_counter + 1'b1;
            
            if (data_counter == 8'd149) begin
                processing_complete <= 1'b1;
            end
        end
    end

    
    // Feature Extraction
   
    wire [15:0] pw = rom_data[65:50];
    wire [15:0] pl = rom_data[49:34];
    wire [15:0] sw = rom_data[33:18];
    wire [15:0] sl = rom_data[17:2];
    wire [1:0]  rom_class = rom_data[1:0];

    wire [15:0] test_pw = test_vector[63:48];
    wire [15:0] test_pl = test_vector[47:32];
    wire [15:0] test_sw = test_vector[31:16];
    wire [15:0] test_sl = test_vector[15:0];

    wire valid_in = (point_count <= 8'd149);

   
    // Euclidean Pipeline

    reg signed [16:0] diff_sl, diff_sw, diff_pl, diff_pw;
    reg signed [33:0] sq_sl, sq_sw, sq_pl, sq_pw;
    reg signed [33:0] final_sum;

    reg valid_stage1, valid_stage2, valid_stage3;
    reg [1:0] class_stage1, class_stage2, class_stage3;

    // Pipeline Stage 1: Differences
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            diff_sl     <= 17'd0;
            diff_sw     <= 17'd0;
            diff_pl     <= 17'd0;
            diff_pw     <= 17'd0;
            class_stage1 <= 2'b0;
            valid_stage1 <= 1'b0;
        end else begin
            diff_sl     <= $signed({1'b0, sl}) - $signed({1'b0, test_sl});
            diff_sw     <= $signed({1'b0, sw}) - $signed({1'b0, test_sw});
            diff_pl     <= $signed({1'b0, pl}) - $signed({1'b0, test_pl});
            diff_pw     <= $signed({1'b0, pw}) - $signed({1'b0, test_pw});
            class_stage1 <= rom_class;
            valid_stage1 <= valid_in;
        end
    end

    // Pipeline Stage 2: Squaring
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sq_sl       <= 34'd0;
            sq_sw       <= 34'd0;
            sq_pl       <= 34'd0;
            sq_pw       <= 34'd0;
            class_stage2 <= 2'b0;
            valid_stage2 <= 1'b0;
        end else begin
            sq_sl       <= diff_sl * diff_sl;
            sq_sw       <= diff_sw * diff_sw;
            sq_pl       <= diff_pl * diff_pl;
            sq_pw       <= diff_pw * diff_pw;
            class_stage2 <= class_stage1;
            valid_stage2 <= valid_stage1;
        end
    end

    // Pipeline Stage 3: Summation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_sum   <= 34'd0;
            class_stage3 <= 2'b0;
            valid_stage3 <= 1'b0;
        end else begin
            final_sum   <= sq_sl + sq_sw + sq_pl + sq_pw;
            class_stage3 <= class_stage2;
            valid_stage3 <= valid_stage2;
        end
    end

    // Pipeline Stage 4: Output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dist_buffer <= 34'd0;
            class_buffer <= 4'd0;
            valid_buffer <= 1'b0;
        end else begin
            dist_buffer <= final_sum;
            class_buffer <= {2'b00, class_stage3}; // Convert to 4-bit
            valid_buffer <= valid_stage3;
        end
    end

   
    // Sorter Implementation
 
    reg [33:0] r1_reg, r2_reg, r3_reg, r4_reg, r5_reg;
    reg [3:0] c1_reg, c2_reg, c3_reg, c4_reg, c5_reg;
    reg [8:0] sorter_count;
    reg sorter_done;
    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sorter_reset <= 1'b1;
        end else if (valid_buffer) begin
            sorter_reset <= 1'b0;
        end
    end

    // Sorter main
    always @(posedge clk) begin
        if (sorter_reset) begin
            r1_reg <= 34'h3FFFFFFFF; 
            r2_reg <= 34'h3FFFFFFFF; 
            r3_reg <= 34'h3FFFFFFFF;
            r4_reg <= 34'h3FFFFFFFF; 
            r5_reg <= 34'h3FFFFFFFF;
            c1_reg <= 4'b1111; 
            c2_reg <= 4'b1111; 
            c3_reg <= 4'b1111;
            c4_reg <= 4'b1111; 
            c5_reg <= 4'b1111;
            sorter_count <= 8'd0;
            sorter_done <= 1'b0;
        end else if (!sorter_done && valid_buffer) begin
           
     // Sorter insertion
     
            if (dist_buffer < r1_reg) begin
                r1_reg <= dist_buffer; c1_reg <= class_buffer;
                r2_reg <= r1_reg;      c2_reg <= c1_reg;
                r3_reg <= r2_reg;      c3_reg <= c2_reg;
                r4_reg <= r3_reg;      c4_reg <= c3_reg;
                r5_reg <= r4_reg;      c5_reg <= c4_reg;
            end else if (dist_buffer < r2_reg) begin
                r1_reg <= r1_reg;      c1_reg <= c1_reg;
                r2_reg <= dist_buffer; c2_reg <= class_buffer;
                r3_reg <= r2_reg;      c3_reg <= c2_reg;
                r4_reg <= r3_reg;      c4_reg <= c3_reg;
                r5_reg <= r4_reg;      c5_reg <= c4_reg;
            end else if (dist_buffer < r3_reg) begin
                r1_reg <= r1_reg;      c1_reg <= c1_reg;
                r2_reg <= r2_reg;      c2_reg <= c2_reg;
                r3_reg <= dist_buffer; c3_reg <= class_buffer;
                r4_reg <= r3_reg;      c4_reg <= c3_reg;
                r5_reg <= r4_reg;      c5_reg <= c4_reg;
            end else if (dist_buffer < r4_reg) begin
                r1_reg <= r1_reg;      c1_reg <= c1_reg;
                r2_reg <= r2_reg;      c2_reg <= c2_reg;
                r3_reg <= r3_reg;      c3_reg <= c3_reg;
                r4_reg <= dist_buffer; c4_reg <= class_buffer;
                r5_reg <= r4_reg;      c5_reg <= c4_reg;
            end else if (dist_buffer < r5_reg) begin
                r1_reg <= r1_reg;      c1_reg <= c1_reg;
                r2_reg <= r2_reg;      c2_reg <= c2_reg;
                r3_reg <= r3_reg;      c3_reg <= c3_reg;
                r4_reg <= r4_reg;      c4_reg <= c4_reg;
                r5_reg <= dist_buffer; c5_reg <= class_buffer;
            end
            
            sorter_count <= sorter_count + 1'b1;
            if (sorter_count == 8'd149) sorter_done <= 1'b1;
        end
    end

 
// Voting Block

reg [3:0] voted_class;
reg voting_done;
reg [2:0] vote_stage;
         reg [2:0] cnt0, cnt1, cnt2, cnt3;
         
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        voted_class <= 4'b0;
        voting_done <= 1'b0;
        vote_stage <= 3'b0;
    end else if (sorter_done && !voting_done) begin
        case (vote_stage)
            3'b000: begin
                
                vote_stage <= 3'b001;
            end
            3'b001: begin
               
                cnt0 = (c1_reg == 4'd0) + (c2_reg == 4'd0) + (c3_reg == 4'd0) + (c4_reg == 4'd0) + (c5_reg == 4'd0);
                cnt1 = (c1_reg == 4'd1) + (c2_reg == 4'd1) + (c3_reg == 4'd1) + (c4_reg == 4'd1) + (c5_reg == 4'd1);
                cnt2 = (c1_reg == 4'd2) + (c2_reg == 4'd2) + (c3_reg == 4'd2) + (c4_reg == 4'd2) + (c5_reg == 4'd2);
                cnt3 = (c1_reg == 4'd3) + (c2_reg == 4'd3) + (c3_reg == 4'd3) + (c4_reg == 4'd3) + (c5_reg == 4'd3);
                
              
                if (cnt0 >= cnt1 && cnt0 >= cnt2 && cnt0 >= cnt3)
                    voted_class <= 4'd0;
                else if (cnt1 >= cnt0 && cnt1 >= cnt2 && cnt1 >= cnt3)
                    voted_class <= 4'd1;
                else if (cnt2 >= cnt0 && cnt2 >= cnt1 && cnt2 >= cnt3)
                    voted_class <= 4'd2;
                else
                    voted_class <= 4'd3;
                
                voting_done <= 1'b1;
                vote_stage <= 3'b010;
            end
            default: begin
            end
        endcase
    end
end

    assign c1 = c1_reg;
    assign c2 = c2_reg;
    assign c3 = c3_reg;
    assign c4 = c4_reg;
    assign c5 = c5_reg;
    assign final_class = voted_class;

endmodule