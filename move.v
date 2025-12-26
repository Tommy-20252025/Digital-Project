
module move(clk,rst,jump,crouch,dinor,outc, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5);	


   start_screen start_mod(
       .clk(clk),
       .rst(rst),
       .enable(game_state == 2'b00),
       .dinor(dinor),
       .outc(outc)
   );
    
endmodule
