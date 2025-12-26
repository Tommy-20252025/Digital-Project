module start_screen(
    input clk,          // 顯示掃描時鐘（10kHz）
    input rst,          // 重置信號
    input enable,       // 關鍵：使能信號，當 enable=1 時模組才工作
    output reg [7:0] dinor,   // 行選擇輸出
    output reg [15:0] outc    // 列資料輸出
);
    
    // 掃描計數器
    reg [2:0] row_idx;
    // 閃爍控制計數器
    reg [23:0] blink_counter;
    reg blink_state;
    // 開始畫面圖案定義（8行 x 16列）
    reg [15:0] start_pattern [0:7];
    
    // 初始化開始畫面圖案
    initial begin
        start_pattern[0] = 16'b0000000000000000;  
        start_pattern[1] = 16'b0000000010000000;
        start_pattern[2] = 16'b0000000011000000;  
        start_pattern[3] = 16'b0000000011100000;  
        start_pattern[4] = 16'b0000000011000000;
        start_pattern[5] = 16'b0000000010000000;  
        start_pattern[6] = 16'b0000000000000000;  
        start_pattern[7] = 16'b0000000000000000;  
    end
    
    // 行掃描計數器
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            row_idx <= 3'd0;
        end else if (enable) begin
            row_idx <= row_idx + 1;
        end
    end
    
    // 閃爍控制（0.5秒間隔）
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            blink_counter <= 0;
            blink_state <= 0;
        end else if (enable) begin
            if (blink_counter >= 5000) begin
                blink_counter <= 0;
                blink_state <= ~blink_state;
            end else begin
                blink_counter <= blink_counter + 1;
            end
        end
    end
    
    // 輸出控制
    always @(*) begin
        if (enable) begin
            dinor = ~(8'b00000001 << row_idx);
            
            if (blink_state) begin
                outc = start_pattern[row_idx];
            end else begin
                outc = 16'b0;
            end
        end else begin
            dinor = 8'b11111111;
            outc = 16'b0;
        end
    end
    
endmodule