module slib_input_sync (
    input  logic CLK,
    input  logic RST,
    input  logic D,
    output logic Q
);
    logic [1:0] iD;

    always_ff @(posedge CLK or posedge RST) begin
        if (RST) iD <= 2'b00;
        else begin
            iD[0] <= D;
            iD[1] <= iD[0];
        end
    end

    assign Q = iD[1];
endmodule
