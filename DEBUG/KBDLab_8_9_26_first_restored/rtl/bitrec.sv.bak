// (c) Technion IIT, Department of Electrical Engineering 2018 
// Written By David Bar-On  June 2018 

module bitrec 	
 ( 
	input	logic  clk,
	input	logic  resetN, 
	input	logic  kbd_dat,
	input	logic  kbd_clk,
	output logic [7:0] dout,	
	output logic dout_new, 
	output logic parity_ok
  ) ;


  enum  logic [2:0] {IDLE_ST, // initial state
					LOW_CLK_ST, // after clock low 
					HI_CLK_ST, // after clock hi 
					CHK_DATA_ST, // after all bits recieved 
					NEW_DATA_ST // valid parity laod new data 
					}    SM_BITREC ; /* for simulation --> synthesis keep = 1 */
				

  logic [3:0] cntr; 
  logic [9:0] shift_reg;  
  
  
//---------------------------------------------------------------------------
// &&&&&&&&&&&&  please change to the correct number and insert in the report 
//---------------------------------------------------------------------------	
  
  localparam NUM_OF_BITS = 4'd0 ;  //????

always_ff @(posedge clk or negedge resetN)
begin: fsm_sync_proc
	if (resetN == 1'b0) begin 
		SM_BITREC <= IDLE_ST ; 
		cntr <= 4'h0  ;
		shift_reg <= 10'h000 ; 
		dout <= 8'b0 ;
		dout_new  <= 1'b0 ; 
	
	end 	

	else begin 
	case( SM_BITREC )
	
//    ===========
		IDLE_ST: begin
//    ===========
			dout_new  <= 1'b0 ;
			cntr <= 4'h0  ;
				
			if( (kbd_clk == 1'b0) && (kbd_dat == 1'b0) ) begin
				SM_BITREC <= LOW_CLK_ST;
				shift_reg <= 10'h000 ;
			end
		end //idle 
					
//----------------------------------------------------------------
// &&&&&&&&&&&&&&  fill your code and paste to the report #1 
//----------------------------------------------------------------			
//
//    ===========		
		LOW_CLK_ST: begin
//    ===========
			if (kbd_clk == 1'b1)
				begin 
					
 			// &&&&&&&&&&&&&&  fill your code please 		
			
				end 
		end //low_clk 

//    ===========		
		HI_CLK_ST: begin
//    ===========
		// &&&&&&&&&&&&&&&&  fill your code please 
								
		end //hi_clk 

//    ===========		
		CHK_DATA_ST: begin 
//    ===========
		// &&&&&&&&&&&&&&  fill your code please
			
		end //chk_data  

//    ===========
		 NEW_DATA_ST: begin 
//    ===========
		// &&&&&&&&&&&&&& fill your code please 
		end //new_data 
		
//    =======		
		default : begin   
//    =======			
				SM_BITREC <= IDLE_ST ; // bad states recovery
			end // default
	
	endcase  
   
//-------------------------------------------------------------
// &&&&&&&&&&&&&&  end of paste  SM to the report #1 
//-------------------------------------------------------------

	end // else clk 
end // fsm_sync_proc  

// parity Calc 
assign parity_ok = shift_reg[8] ^ shift_reg[7] ^ shift_reg[6] ^ shift_reg[5] ^ shift_reg[3] 
       ^ shift_reg[2] ^ shift_reg[1] ^ shift_reg[1] ^ shift_reg[0]; 

endmodule

