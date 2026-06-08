// Counter with overflow detection.
// The overflow bit auto-clears one cycle after it is set,
// matching the VHDL "last-assignment-wins" behaviour in the same process.
module slib_counter #(
    parameter int WIDTH = 4
) (
    input  logic             CLK,
    input  logic             RST,
    input  logic             CLEAR,
    input  logic             LOAD,
    input  logic             ENABLE,
    input  logic             DOWN,
    input  logic [WIDTH-1:0] D,
    output logic [WIDTH-1:0] Q,
    output logic             OVERFLOW
);
    logic [WIDTH:0] iCounter;

    always_ff @(posedge CLK or posedge RST) begin
        if (RST)
            iCounter <= '0;
        else begin
            if (CLEAR)
                iCounter <= '0;
            else if (LOAD)
                iCounter <= {1'b0, D};
            else if (ENABLE) begin
                if (!DOWN) iCounter <= iCounter + {{WIDTH{1'b0}}, 1'b1};
                else       iCounter <= iCounter - {{WIDTH{1'b0}}, 1'b1};
            end
            // Auto-clear overflow bit (checks OLD value; last-assignment wins for bit WIDTH)
            if (iCounter[WIDTH])
                iCounter[WIDTH] <= 1'b0;
        end
    end

    assign Q        = iCounter[WIDTH-1:0];
    assign OVERFLOW = iCounter[WIDTH];
endmodule
