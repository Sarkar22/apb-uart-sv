module slib_mv_filter #(
    parameter int WIDTH     = 4,
    parameter int THRESHOLD = 10
) (
    input  logic CLK,
    input  logic RST,
    input  logic SAMPLE,
    input  logic CLEAR,
    input  logic D,
    output logic Q
);
    logic [WIDTH:0] iCounter;
    logic           iQ;

    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            iCounter <= '0;
            iQ       <= 1'b0;
        end else begin
            if (iCounter >= THRESHOLD)
                iQ <= 1'b1;
            else begin
                if (SAMPLE && D)
                    iCounter <= iCounter + 1'b1;
            end
            if (CLEAR) begin
                iCounter <= '0;
                iQ       <= 1'b0;
            end
        end
    end

    assign Q = iQ;
endmodule
