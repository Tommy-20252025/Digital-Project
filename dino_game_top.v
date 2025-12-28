`define TimeExp 32'd416666 
`define TimeTick 32'd2499 
`define TimeStart 32'd5000  // 新增：開始畫面閃爍時鐘

module dino_game_top(
    input clk, rst, 
    input jump, crouch,
    output [7:0] dinor, 
    output [15:0] outc,
    output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

    wire clkdiv, clkdis; 
    wire [2:0] dinonow; 
    wire [4:0] xcoor;   
    wire state, shape;  
    wire [1:0] game_state; 
	 // 開始畫面使能信號
    // 1. 時鐘分頻
    freqdiv_gen f1(.clk(clk), .rst(rst), .exp(`TimeExp), .out(clkdiv));
    freqdiv_gen f2(.clk(clk), .rst(rst), .exp(`TimeTick), .out(clkdis));


    // 2. 恐龍行為
    dinologic_core d1(.clk(clkdiv), .rst(rst), .jump(jump), .crouch(crouch), .sprite_id(dinonow));

    // 3. 隨機生成
    random_gen r1(.clk(clkdiv), .rst(rst), .out(state));

    // 4. 移動邏輯
    obstacle_move m1(.clk(clkdiv), .rst(rst), .state(state),.game_state(game_state),  .xcoor(xcoor), .shape(shape));

    // 5. 綜合顯示模組 (碰撞偵測與畫面控制都在這裡)
    display_combined display_unit(
        .clk(clkdis), .rst(rst),
		  .crouch(crouch),   .jump(jump), // 用於開始遊戲
        .dinonow(dinonow), 
        .shape(shape),     
        .xcoor(xcoor),     
        .dinor(dinor), 
        .outc(outc),       
        .game_state(game_state)
    );

    // 6. 計分板 (根據 game_state 決定是否計分)
    score_counter my_score(
        .clk(clk),              
        .rst(rst),
        .game_state(game_state), 
		  .jump(jump),.crouch(crouch),
        .hex0(HEX0), .hex1(HEX1), .hex2(HEX2), .hex3(HEX3), .hex4(HEX4), .hex5(HEX5)
    );

endmodule

// --- 修正後的顯示與碰撞模組 (碰撞後全黑) ---
module display_combined(
    input clk, rst, shape,    
    input jump, // 用於開始遊戲
	 input crouch,
    input [2:0] dinonow,
    input [4:0] xcoor,
    output reg [7:0] dinor,
    output reg [15:0] outc,
    output reg [1:0] game_state
);
    reg [2:0] row_idx;
    reg [15:0] dino_row_data;
    reg [15:0] obs_raw_data;
    reg [31:0] obs_shifted;
    wire [2:0] next_row = row_idx + 1;
    reg [23:0] blink_counter;
    reg blink_state;
    
    // 開始畫面圖案 (8行 x 16列)
    reg [15:0] start_pattern [0:7];
    // 結束畫面圖案 (8行 x 16列)
    reg [15:0] end_pattern [0:7];
    
    // 初始化圖案
    initial begin
        // 開始畫面 (向上箭頭)
        start_pattern[0] = 16'b0000000000000000;  
        start_pattern[1] = 16'b0000000010000000;
        start_pattern[2] = 16'b0000000011000000;  
        start_pattern[3] = 16'b0000000011100000;  
        start_pattern[4] = 16'b0000000011000000;
        start_pattern[5] = 16'b0000000010000000;  
        start_pattern[6] = 16'b0000000000000000;  
        start_pattern[7] = 16'b0000000000000000;
        
        // 結束畫面 (GAME OVER 的簡化顯示)
        end_pattern[0] = 16'b0000000000000000;  
        end_pattern[1] = 16'b0000000000000000;
        end_pattern[2] = 16'b1110100010110000;  // GAME
        end_pattern[3] = 16'b1000100110101000;  
        end_pattern[4] = 16'b1110101010100100;
        end_pattern[5] = 16'b1000110010101000;  // OVER
        end_pattern[6] = 16'b1110100010110000;  
        end_pattern[7] = 16'b0000000000000000;
    end
     
    always @(posedge clk or negedge rst) begin
        if (!rst) begin 
            row_idx <= 0; 
            dinor <= 8'hFE; 
            outc <= 0; 
            game_state <= 0;
            blink_counter <= 0;
            blink_state <= 0;
        end 
        else begin
            // 掃描永遠持續
            row_idx <= next_row;
            dinor <= ~(8'b00000001 << next_row);
            
            // 閃爍控制
            if (blink_counter >= 5000) begin
                blink_counter <= 0;
                blink_state <= ~blink_state;
            end 
            else begin
                blink_counter <= blink_counter + 1;
            end
            
            case (game_state)
                2'd0: begin // 開始畫面狀態
					 outc <= 16'b0;
                    if (!jump||!crouch) begin  // 按下跳躍鍵開始遊戲
                        game_state <= 1;
                     //   outc <= 0;  // 清除畫面
                    end
                    else begin
                        // 閃爍顯示開始畫面
                        if (blink_state) begin
                            outc <= start_pattern[row_idx];
                        end 
                        else begin
                            outc <= 16'b0;
                        end
                    end
                end
                
                2'd1: begin // 遊戲進行中狀態
                    // --- 1. 恐龍資料 ---
                    case (dinonow)
                        3'd0: case(next_row) 
                            3'd5: dino_row_data=16'b0001100000000000; 
                            3'd4: dino_row_data=16'b0001010000000000; 
                            3'd3: dino_row_data=16'b0101100000000000; 
                            3'd2: dino_row_data=16'b0111100000000000; 
                            3'd1: dino_row_data=16'b0011000000000000; 
                            3'd0: dino_row_data=16'b0010100000000000; 
                            default: dino_row_data=0; endcase
                        3'd1: case(next_row) 
                            3'd5: dino_row_data=16'b0001100000000000; 
                            3'd4: dino_row_data=16'b0001010000000000; 
                            3'd3: dino_row_data=16'b0101100000000000; 
                            3'd2: dino_row_data=16'b0111100000000000; 
                            3'd1: dino_row_data=16'b0011000000000000; 
                            3'd0: dino_row_data=16'b0101000000000000; 
                            default: dino_row_data=0; endcase
                        3'd2: case(next_row) 
                            3'd7: dino_row_data=16'b0100000000000000; 
                            3'd6: dino_row_data=16'b0010011000000000; 
                            3'd5: dino_row_data=16'b0011110100000000; 
                            3'd4: dino_row_data=16'b0001111000000000; 
                            3'd3: dino_row_data=16'b0001010000000000; 
                            default: dino_row_data=0; endcase
                        3'd3: case(next_row) 
                            3'd7: dino_row_data=16'b0100000000000000; 
                            3'd6: dino_row_data=16'b0010011000000000; 
                            3'd5: dino_row_data=16'b0011110100000000; 
                            3'd4: dino_row_data=16'b0001111000000000; 
                            3'd3: dino_row_data=16'b0010001000000000; 
                            default: dino_row_data=0; endcase
                        3'd4: case(next_row) 
                            3'd3: dino_row_data=16'b0100110000000000; 
                            3'd2: dino_row_data=16'b0111111000000000; 
                            3'd1: dino_row_data=16'b0011100000000000; 
                            3'd0: dino_row_data=16'b0010010000000000; 
                            default: dino_row_data=0; endcase
                        3'd5: case(next_row) 
                            3'd3: dino_row_data=16'b0100110000000000; 
                            3'd2: dino_row_data=16'b0111111000000000; 
                            3'd1: dino_row_data=16'b0011100000000000; 
                            3'd0: dino_row_data=16'b0100100000000000; 
                            default: dino_row_data=0; endcase
                        default: dino_row_data = 0;
                    endcase

                    // --- 2. 障礙物原始資料 ---
                    if (shape == 0) begin // Cactus
                        case (next_row) 
                            3'd2: obs_raw_data=16'b0000000000000101; 
                            3'd1: obs_raw_data=16'b0000000000001011; 
                            3'd0: obs_raw_data=16'b0000000000001001; 
                            default: obs_raw_data=0; endcase
                    end else begin // Bird
                        case (next_row) 
                            3'd7: obs_raw_data=16'b0000000000000010; 
                            3'd6: obs_raw_data=16'b0000000000000110; 
                            3'd5: obs_raw_data=16'b0000000000010111; 
                            3'd4: obs_raw_data=16'b0000000000001110; 
                            default: obs_raw_data=0; endcase
                    end

                    // 計算位移
                    obs_shifted = {16'b0, obs_raw_data} << xcoor;
                    
                    // 碰撞偵測與輸出
                    if (dino_row_data & obs_shifted[31:16]) begin 
                        game_state <= 2; // 碰撞後切換到結束狀態
                        outc <= dino_row_data | obs_shifted[31:16]; // 顯示碰撞瞬間
                    end else begin
                        outc <= dino_row_data | obs_shifted[31:16]; // 正常顯示
                    end
                end
                
                2'd2: begin // 結束畫面狀態
					 outc <= 16'b0; 
                    if (!jump||!crouch) begin  // 按下跳躍鍵重新開始
                        game_state <= 0;
                      //  outc <= 0;
                    end
                    else begin
                        // 閃爍顯示結束畫面
                        if (blink_state) begin
                            outc <= end_pattern[row_idx];
                        end 
                        else begin
                            outc <= 16'b0;
                        end
                    end
                end
                
                default: begin
                    game_state <= 0;
                    outc <= 0;
                end
            endcase
        end
    end
endmodule

// --- 輔助模組：通用分頻器 ---
module freqdiv_gen(input clk, rst, input [31:0] exp, output reg out);
    reg [31:0] count;
    always @(posedge clk or negedge rst) begin
        if (!rst) 
            {count, out} <= 0;
        else if (count == exp) begin 
            count <= 0; out <= ~out; 
        end else 
            count <= count + 1;
    end
endmodule

// --- 輔助模組：恐龍邏輯 ---
module dinologic_core(input clk, rst, jump, crouch, output reg [2:0] sprite_id);
    parameter RUN = 2'b00, JUMP = 2'b01, CROUCH = 2'b10;
    reg [1:0] state;
    reg anim_toggle;
    reg [6:0] holdt;
    reg [3:0] anim_cnt;
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin 
            state <= RUN; anim_toggle <= 0; holdt <= 0; 
        end else begin
            if (anim_cnt < 4'd10) begin // 調整這個數值可改變換腳速度 (10代表每10幀換一次腳)
                anim_cnt <= anim_cnt + 1;
            end else begin
                anim_cnt <= 0;
                anim_toggle <= ~anim_toggle;
            end
            case (state)
                RUN: if (!jump) 
                        state <= JUMP; 
                    else if (!crouch) 
                        state <= CROUCH;
                JUMP: if (holdt < 60) 
                        holdt <= holdt + 1; 
                    else begin 
                        holdt <= 0; state <= RUN; 
                    end
                CROUCH: if (crouch) 
                        state <= RUN;
            endcase
        end
    end
    always @(*) begin
        case (state)
            RUN:    sprite_id = anim_toggle ? 3'd1 : 3'd0;
            JUMP:   sprite_id = anim_toggle ? 3'd3 : 3'd2;
            CROUCH: sprite_id = anim_toggle ? 3'd5 : 3'd4;
            default: sprite_id = 3'd0;
        endcase
    end
endmodule

// --- 輔助模組：LFSR 隨機數 ---
module random_gen(input clk, rst, output reg out);
    reg [15:0] lfsr;
    wire feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];
    always @(posedge clk or negedge rst) begin
        if (!rst) begin 
            lfsr <= 16'hACE1; out <= 0; 
        end else begin 
            lfsr <= {lfsr[14:0], feedback}; out <= lfsr[15]; 
        end
    end
endmodule

// --- 輔助模組：障礙物移動 ---
module obstacle_move(
    input clk, rst, 
    input [1:0] game_state,  // 新增：遊戲狀態輸入
    input state, 
    output reg [4:0] xcoor, 
    output reg shape
);
    reg [2:0] delay;
    reg [31:0] start_delay_counter;  // 新增：開始延遲計數器
    reg delay_complete;               // 新增：延遲完成標誌
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin 
            xcoor <= 0; 
            shape <= 0; 
            delay <= 0; 
            start_delay_counter <= 0;
            delay_complete <= 0;
        end 
        else begin
            case (game_state)
                2'd0: begin // 開始畫面狀態：重置所有障礙物相關狀態
                    xcoor <= 0;
                    shape <= 0;
                    delay <= 0;
                    start_delay_counter <= 0;
                    delay_complete <= 0;
                end
                
                2'd1: begin // 遊戲進行中狀態
                    // 延遲2秒邏輯
                    if (!delay_complete) begin
                        // 計算2秒延遲 (假設 clkdiv 頻率約為 60Hz，2秒需要 120 個週期)
                        // 可以根據實際時鐘頻率調整這個值
                        if (start_delay_counter < 32'd120) begin // 大約2秒
                            start_delay_counter <= start_delay_counter + 1;
                        end 
                        else begin
                            delay_complete <= 1;
                            start_delay_counter <= 0;
                        end
                    end 
                    else begin
                        // 延遲完成後，開始正常移動障礙物
                        if (delay < 3'd5) 
                            delay <= delay + 1;
                        else begin
                            delay <= 0;
                            if (xcoor == 31) begin 
                                xcoor <= 0; 
                                shape <= state; 
                            end else xcoor <= xcoor + 1;
                        end
                    end
                end
                
                2'd2: begin // 結束畫面狀態：停止障礙物移動但保持當前狀態
                    // 保持當前位置不變
                    // 不移動障礙物
                end
                
                default: begin
                    xcoor <= 0;
                    shape <= 0;
                    delay <= 0;
                    start_delay_counter <= 0;
                    delay_complete <= 0;
                end
            endcase
        end
    end
endmodule

module score_counter(
    input clk,              // 請接板子原本的 MAX10_CLK1_50 (50MHz)
    input rst,  jump,crouch,            // Reset Button
    input [1:0] game_state, // 0:Reset, 1:Run, 2:Over
    output [6:0] hex0,      // Digit 0 (改成 7 bits)
    output [6:0] hex1,      // Digit 1
    output [6:0] hex2,      // Digit 2
    output [6:0] hex3,      // Digit 3
    output [6:0] hex4,      // Digit 4
    output [6:0] hex5       // Digit 5
);

    // --- 設定速度：50MHz / 5M = 10Hz (0.1秒加一分) ---
    parameter SCORE_SPEED = 5000000; 
    
    reg [31:0] time_cnt;
    wire tick_score; 

    // 1. 計時器
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            time_cnt <= 0;
        end
        else if (game_state == 2'd1) begin // 只有在「遊戲進行中」才計數
            if(time_cnt >= SCORE_SPEED) 
                time_cnt <= 0;
            else 
                time_cnt <= time_cnt + 1;
        end
        else begin // 只有在「遊戲進行中」才計數
time_cnt <= 0;
        end
		  // 如果 game_state 是 2 (結束) 或 0 (未開始)，計時器就停住不跑
    end
	 
    // 產生加分脈衝
    assign tick_score = (time_cnt == SCORE_SPEED);

    // 2. 六位數 BCD 計數器 (000000~999999)
    reg [3:0] digit0, digit1, digit2, digit3, digit4, digit5;

    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            digit0 <= 0; digit1 <= 0; digit2 <= 0;
            digit3 <= 0; digit4 <= 0; digit5 <= 0;
        end
        else if (tick_score && (game_state == 2'd1)) begin 
            if(digit0 == 4'd9) begin
                digit0 <= 0;
                if(digit1 == 4'd9) begin
                    digit1 <= 0;
                    if(digit2 == 4'd9) begin
                        digit2 <= 0;
                        if(digit3 == 4'd9) begin
                            digit3 <= 0;
                            if(digit4 == 4'd9) begin
                                digit4 <= 0;
                                if(digit5 == 4'd9) digit5 <= 0; // 破十萬歸零
                                else digit5 <= digit5 + 1;
                            end else digit4 <= digit4 + 1;
                        end else digit3 <= digit3 + 1;
                    end else digit2 <= digit2 + 1;
                end else digit1 <= digit1 + 1;
            end else digit0 <= digit0 + 1;
        end
		  else if ((game_state == 2'd00)||(game_state == 2'd10)) begin
					if(!jump||!crouch) begin
		            digit0 <= 0; digit1 <= 0; digit2 <= 0;
						digit3 <= 0; digit4 <= 0; digit5 <= 0;
					end
		  end
    end

    // 3. 七段顯示器解碼
    // 0是亮，1是滅 (共陽極)
    // 對應順序通常是 [6:0] = g,f,e,d,c,b,a
    function [6:0] seg7_decoder;
        input [3:0] num;
        begin
            case(num)
                4'h0: seg7_decoder = 7'b1000000; // 顯示 0
                4'h1: seg7_decoder = 7'b1111001; // 顯示 1
                4'h2: seg7_decoder = 7'b0100100; // 顯示 2
                4'h3: seg7_decoder = 7'b0110000; // 顯示 3
                4'h4: seg7_decoder = 7'b0011001; // 顯示 4
                4'h5: seg7_decoder = 7'b0010010; // 顯示 5
                4'h6: seg7_decoder = 7'b0000010; // 顯示 6
                4'h7: seg7_decoder = 7'b1111000; // 顯示 7
                4'h8: seg7_decoder = 7'b0000000; // 顯示 8
                4'h9: seg7_decoder = 7'b0010000; // 顯示 9
                default: seg7_decoder = 7'b1111111; // 錯誤時全滅
            endcase
        end
    endfunction
	
	 // 輸出到接腳
    assign hex0 = seg7_decoder(digit0);
    assign hex1 = seg7_decoder(digit1);
    assign hex2 = seg7_decoder(digit2);
    assign hex3 = seg7_decoder(digit3);
    assign hex4 = seg7_decoder(digit4);
    assign hex5 = seg7_decoder(digit5);

endmodule
