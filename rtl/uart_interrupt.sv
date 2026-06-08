module uart_interrupt (
    input  logic        CLK,
    input  logic        RST,
    input  logic [3:0]  IER,
    input  logic [4:0]  LSR,
    input  logic        THI,
    input  logic        RDA,
    input  logic        CTI,
    input  logic        AFE,
    input  logic [3:0]  MSR,
    output logic [3:0]  IIR,
    output logic        INT
);
    logic iRLSInterrupt;
    logic iRDAInterrupt;
    logic iCTIInterrupt;
    logic iTHRInterrupt;
    logic iMSRInterrupt;
    logic [3:0] iIIR;

    assign iRLSInterrupt = IER[2] & (LSR[1] | LSR[2] | LSR[3] | LSR[4]);
    assign iRDAInterrupt = IER[0] & RDA;
    assign iCTIInterrupt = IER[0] & CTI;
    assign iTHRInterrupt = IER[1] & THI;
    assign iMSRInterrupt = IER[3] & ((MSR[0] & ~AFE) | MSR[1] | MSR[2] | MSR[3]);

    always_ff @(posedge CLK or posedge RST) begin
        if (RST)
            iIIR <= 4'b0001;
        else begin
            if      (iRLSInterrupt) iIIR <= 4'b0110;
            else if (iCTIInterrupt) iIIR <= 4'b1100;
            else if (iRDAInterrupt) iIIR <= 4'b0100;
            else if (iTHRInterrupt) iIIR <= 4'b0010;
            else if (iMSRInterrupt) iIIR <= 4'b0000;
            else                    iIIR <= 4'b0001;
        end
    end

    assign IIR = iIIR;
    assign INT = ~iIIR[0];
endmodule
