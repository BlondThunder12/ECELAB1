// (c) Technion IIT, Department of Electrical Engineering 2018 

// Implements the hexadecimal to 7Segment conversion unit
// by using a two-dimensional array

module hexss 
	(
	input logic [3:0] hexin, // Data input: hex numbers 0 to f
	input logic darkN, 
	input logic LampTest, 	// Aditional inputs
	output logic [6:0] ss 	// Output for 7Seg display
	);
	
//------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  fill your code and paste into the report
//------------------------------------------------------------------------------------

// Declaration of two-dimensional array that holds the 7seg codes

// Fill your code here
	logic [0:15] [0:6] SevenSeg = {
		7'b1000000, //0
		7'b1111001,	//1
		7'b0100100, //2
		7'b0110000, //3
		7'b0011001, //4
		7'b0010010, //5
		7'b0000010, //6
		7'b1111000, //7
		7'b0000000, //8
		7'b0010000, //9
		7'b0001000, //A
		7'b0000011, //B
		7'b1000110, //C
		7'b0100001, //D
		7'b0000110, //E
		7'b0001110, //F
	};
always_comb
begin

// Fill your code here
	if (!darkN) begin
		ss = 7'b0000000;
	end
	else if (LampTest) begin
		ss = 7'b1111111;
	end
	else begin
		ss = SevenSeg[hexin];
	end
end

//-------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  end of paste into the report 
//-------------------------------------------------------------------------------------

endmodule


