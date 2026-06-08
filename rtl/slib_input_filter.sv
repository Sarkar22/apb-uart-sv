module slib_input_filter #(
    parameter int SIZE = 4
) (
    input  logic CLK,
    input  logic RST,
    input  logic CE,
    input  logic D,
    output logic Q
);
    // Range 0 to SIZE — use enough bits
    logic [$clog2(SIZE+1):0] iCount;

    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            iCount <= '0;
            Q      <= 1'b0;
        end else begin
            if (CE) begin
                if (D && iCount != SIZE)
                    iCount <= iCount + 1'b1;
                else if (!D && iCount != '0)
                    iCount <= iCount - 1'b1;
            end
            if (iCount == SIZE)   Q <= 1'b1;
            else if (iCount == '0) Q <= 1'b0;
        end
    end
endmodule
