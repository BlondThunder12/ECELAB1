// (c) Technion IIT, Department of Electrical Engineering 2018 

// Implements mux 4=>1 with case statement
// combinatorial

module mux_4to1_case 	
 ( 
   input logic [3:0] datain,
	input logic [1:0] select,
	output logic outd
	);

//-------------------------------------------------------------------------
// &&&&&&&&&&&&&&  fill your code and paste into the report
//-------------------------------------------------------------------------
	always_comb
	begin

		case (select)
        2'b00: begin
            outd = datain[0];
        end
        2'b01: begin
            outd = datain[1];
        end
        2'b10: begin
            outd = datain[2];
        end
        2'b11: begin
            outd = datain[3];
        end
        default: begin
            outd = 1'bx;
        end
    endcase

	end
//--------------------------------------------------------------------------
// &&&&&&&&&&&&&&  end of paste into the report 
//--------------------------------------------------------------------------

endmodule

