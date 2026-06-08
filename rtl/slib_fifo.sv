module slib_fifo #(
    parameter int WIDTH  = 8,
    parameter int SIZE_E = 6
) (
    input  logic              CLK,
    input  logic              RST,
    input  logic              CLEAR,
    input  logic              WRITE,
    input  logic              READ,
    input  logic [WIDTH-1:0]  D,
    output logic [WIDTH-1:0]  Q,
    output logic              EMPTY,
    output logic              FULL,
    output logic [SIZE_E-1:0] USAGE
);
    localparam int DEPTH = 1 << SIZE_E;

    logic [WIDTH-1:0]  iFIFOMem [0:DEPTH-1];
    logic [SIZE_E:0]   iWRAddr;
    logic [SIZE_E:0]   iRDAddr;
    logic [SIZE_E-1:0] iUSAGE;
    logic              iEMPTY;
    logic              iFULL;

    // Full: lower bits equal but MSB differs (one extra wrap)
    assign iFULL = (iRDAddr[SIZE_E-1:0] == iWRAddr[SIZE_E-1:0]) &&
                   (iRDAddr[SIZE_E]     != iWRAddr[SIZE_E]);

    // Address counters and empty flag
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            iWRAddr <= '0;
            iRDAddr <= '0;
            iEMPTY  <= 1'b1;
        end else begin
            if (WRITE && !iFULL)  iWRAddr <= iWRAddr + 1'b1;
            if (READ  && !iEMPTY) iRDAddr <= iRDAddr + 1'b1;
            if (CLEAR) begin
                iWRAddr <= '0;
                iRDAddr <= '0;
            end
            if (iRDAddr == iWRAddr) iEMPTY <= 1'b1;
            else                     iEMPTY <= 1'b0;
        end
    end

    // Memory read/write
    integer i;
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            for (i = 0; i < DEPTH; i = i+1)
                iFIFOMem[i] <= '0;
            Q <= '0;
        end else begin
            if (WRITE && !iFULL)
                iFIFOMem[iWRAddr[SIZE_E-1:0]] <= D;
            Q <= iFIFOMem[iRDAddr[SIZE_E-1:0]];
        end
    end

    // Usage counter
    always_ff @(posedge CLK or posedge RST) begin
        if (RST)
            iUSAGE <= '0;
        else begin
            if (CLEAR)
                iUSAGE <= '0;
            else begin
                if (!READ  && WRITE && !iFULL)  iUSAGE <= iUSAGE + 1'b1;
                if (!WRITE && READ  && !iEMPTY) iUSAGE <= iUSAGE - 1'b1;
            end
        end
    end

    assign EMPTY = iEMPTY;
    assign FULL  = iFULL;
    assign USAGE = iUSAGE;
endmodule
