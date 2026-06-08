module slib_edge_detect (
    input  logic CLK,
    input  logic RST,
    input  logic D,
    output logic RE,
    output logic FE
);
    logic iDd;

    always_ff @(posedge CLK or posedge RST) begin
        if (RST) iDd <= 1'b0;
        else     iDd <= D;
    end

    assign RE = ~iDd &  D;
    assign FE =  iDd & ~D;
endmodule
