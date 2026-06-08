module slib_clock_div #(
    parameter int RATIO = 4
) (
    input  logic CLK,
    input  logic RST,
    input  logic CE,
    output logic Q
);
    logic [$clog2(RATIO)-1:0] iCounter;
    logic                     iQ;

    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            iCounter <= '0;
            iQ       <= 1'b0;
        end else begin
            iQ <= 1'b0;
            if (CE) begin
                if (iCounter == RATIO-1) begin
                    iQ       <= 1'b1;
                    iCounter <= '0;
                end else begin
                    iCounter <= iCounter + 1'b1;
                end
            end
        end
    end

    assign Q = iQ;
endmodule
