// (c) Technion IIT, Department of Electrical Engineering 2020 
// Written By David Bar-On  June 2018 

module byterec 	
 ( 
   input	   logic  clk,
	input	   logic  resetN, 
	input	   logic  din_new,
	input	   logic  [7:0] din,
   output  logic [8:0]	keyCode,	
   output  logic 	make,	
   output  logic 	brakk	

	 
  ) ;


     enum  logic [3:0] {   idle_ST     ,   // initial state
									normal_ST,    // normal key only 
									break_ST , //braek , waiting for next key 
									break_normal_ST , //braek + noraml  
									extended_ST ,//extended, waiting for next key 
									extended_normal_ST ,//extended + normal
									extended_break_ST ,  //extended + break , waiting for next key 
									extended_break_normal_ST }  //extended + break + normal 
	 SM_BYTEREC;


  logic extended  ; // extended bit acts as msb of code table
  logic oe  ; // output enable of output register
  logic normal_code;
  logic ext_code;
  logic rel_code;

  
  // commade decoder    code classifier (combinatorial)
		assign normal_code  = (( din > 16'd00 ) &&  ( din < 16'd132 ))  ; // normal code up to 131
		assign ext_code  =  ( din == 16'd224 ); // extended code E0
		assign rel_code  =  ( din == 16'd240 ) ; // relese code   F0

//  possible sequences 
// normal                  ->  0XX + make 
// extended(e0)  + normal  ->  1XX + make 
// brakee (F0)  + normal  ->  0XX + brake 
// extended(e0)  + brakee (F0)  + normal  ->  1XX + brake 
	
	
	
  
// next state and output latch 
	always_ff @(posedge clk or negedge resetN)
	begin: fsm_sync_proc
		if (resetN == 1'b0) begin 
			SM_BYTEREC <= idle_ST ; 
			keyCode <= 8'h00 ;
  		end 	
		else begin 
 	
			case ( SM_BYTEREC )
	  
//       =======			
	   	idle_ST : begin 
//       =======			
					make  <= 1'b0 ;
					brakk <= 1'b0 ;
 
					if (din_new == 1'b1) begin
						if ( normal_code )
							SM_BYTEREC <= normal_ST ;
						else if (rel_code )
							SM_BYTEREC <= break_ST ;
						else if (ext_code )
							SM_BYTEREC <= extended_ST ;
					end  
				end  // idle
			
//       =============			
			normal_ST : begin // normal key only 
//       =============			
					keyCode <= { 1'b0, {din [7:0]}} ;	
					make  <= 1'b1 ;
					SM_BYTEREC <= idle_ST ;

				end 
					 
//       ========			
			break_ST : begin //braek , waiting for next key 
//       ========			
					if  (din_new == 1'b1) begin 
						if ( normal_code )
							SM_BYTEREC <= break_normal_ST ;
						else // error 
						SM_BYTEREC <= idle_ST ;

					end  
			end 
				
//       ========			
			break_normal_ST : begin //braek + normal
//       ========			
						keyCode <= { 1'b0, {din [7:0]}} ;	
						brakk  <= 1'b1 ;
						SM_BYTEREC <= idle_ST ;
			end 
				
			
//       ===========			
			extended_ST : begin//extended, waiting for next key 
//       ===========		

					if (din_new == 1'b1) begin
						if ( normal_code )  
							SM_BYTEREC <= extended_normal_ST ;
						else if (rel_code )
							SM_BYTEREC <= extended_break_ST ;
						else /// error 
							SM_BYTEREC <= idle_ST ;
					end  
	
			end 
//       ===========			
			extended_normal_ST : begin//extended + normal
//       ===========		
							keyCode <= { 1'b1, {din [7:0]}} ;	
							make  <= 1'b1 ;
							SM_BYTEREC <= idle_ST ;	
			end 

//       ========			
			extended_break_ST : begin //extended + braek , waiting for next key 
//       ========			
					if  (din_new == 1'b1) begin 
						if ( normal_code )  
							SM_BYTEREC <= extended_break_normal_ST ;
						else /// error 
							SM_BYTEREC <= idle_ST ;
					end  
			end 
//       ========			
			extended_break_normal_ST : begin //extended + braek + normal
//       ========			
						keyCode <= { 1'b1, {din [7:0]}} ;	
						brakk  <= 1'b1 ;
						SM_BYTEREC <= idle_ST ;

			end 
	  
//      ========		
			default : begin   
//      ========			
					SM_BYTEREC <= idle_ST ;  // bad states recovery
				end // default
				
			endcase 
		end //else
		
	end // end fsm_sync_proc
  
 
endmodule

