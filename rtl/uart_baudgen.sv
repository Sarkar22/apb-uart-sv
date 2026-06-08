module uart_baudgen (
    input  logic        CLK,
    input  logic        RST,
    input  logic        CE,
    input  logic        CLEAR,
    input  logic [15:0] DIVIDER,
    output logic        BAUDTICK
);
    logic [15:0] iCounter;

    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            iCounter <= 16'h0;
            BAUDTICK <= 1'b0;
        end else begin
            if (CLEAR)
                iCounter <= 16'h0;
            else if (CE)
                iCounter <= iCounter + 1'b1;

            BAUDTICK <= 1'b0;
            if (iCounter == DIVIDER) begin
                iCounter <= 16'h0;
                BAUDTICK <= 1'b1;
            end
        end
    end
endmodule
