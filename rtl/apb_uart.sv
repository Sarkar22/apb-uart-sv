module apb_uart (
    input  logic        CLK,
    input  logic        RSTN,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [2:0]  PADDR,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR,
    output logic        INT,
    output logic        OUT1N,
    output logic        OUT2N,
    output logic        RTSN,
    output logic        DTRN,
    input  logic        CTSN,
    input  logic        DSRN,
    input  logic        DCDN,
    input  logic        RIN,
    input  logic        SIN,
    output logic        SOUT
);
    // Active-high reset
    logic iRST;
    assign iRST = ~RSTN;

    // APB decode
    logic iWrite, iRead;
    assign iWrite = PSEL & PENABLE &  PWRITE;
    assign iRead  = PSEL & PENABLE & ~PWRITE;

    // Register access strobes
    logic iRBRRead, iTHRWrite, iDLLWrite, iDLMWrite, iIERWrite;
    logic iIIRRead, iFCRWrite, iLCRWrite, iMCRWrite;
    logic iLSRRead, iMSRRead,  iSCRWrite;

    logic iLCR_DLAB;  // forward declaration (set later)

    assign iRBRRead  = iRead  & (PADDR == 3'b000) & ~iLCR_DLAB;
    assign iTHRWrite = iWrite & (PADDR == 3'b000) & ~iLCR_DLAB;
    assign iDLLWrite = iWrite & (PADDR == 3'b000) &  iLCR_DLAB;
    assign iDLMWrite = iWrite & (PADDR == 3'b001) &  iLCR_DLAB;
    assign iIERWrite = iWrite & (PADDR == 3'b001) & ~iLCR_DLAB;
    assign iIIRRead  = iRead  & (PADDR == 3'b010);
    assign iFCRWrite = iWrite & (PADDR == 3'b010);
    assign iLCRWrite = iWrite & (PADDR == 3'b011);
    assign iMCRWrite = iWrite & (PADDR == 3'b100);
    assign iLSRRead  = iRead  & (PADDR == 3'b101);
    assign iMSRRead  = iRead  & (PADDR == 3'b110);
    assign iSCRWrite = iWrite & (PADDR == 3'b111);

    // Input synchronizers
    logic iSINr, iCTSNs, iDSRNs, iDCDNs, iRINs;
    slib_input_sync UART_IS_SIN (.CLK(CLK), .RST(iRST), .D(SIN),  .Q(iSINr));
    slib_input_sync UART_IS_CTS (.CLK(CLK), .RST(iRST), .D(CTSN), .Q(iCTSNs));
    slib_input_sync UART_IS_DSR (.CLK(CLK), .RST(iRST), .D(DSRN), .Q(iDSRNs));
    slib_input_sync UART_IS_DCD (.CLK(CLK), .RST(iRST), .D(DCDN), .Q(iDCDNs));
    slib_input_sync UART_IS_RI  (.CLK(CLK), .RST(iRST), .D(RIN),  .Q(iRINs));

    // Input filters for modem control signals
    logic iBaudtick2x;  // forward declaration
    logic iCTSn, iDSRn, iDCDn, iRIn;
    slib_input_filter #(.SIZE(2)) UART_IF_CTS (.CLK(CLK), .RST(iRST), .CE(iBaudtick2x), .D(iCTSNs), .Q(iCTSn));
    slib_input_filter #(.SIZE(2)) UART_IF_DSR (.CLK(CLK), .RST(iRST), .CE(iBaudtick2x), .D(iDSRNs), .Q(iDSRn));
    slib_input_filter #(.SIZE(2)) UART_IF_DCD (.CLK(CLK), .RST(iRST), .CE(iBaudtick2x), .D(iDCDNs), .Q(iDCDn));
    slib_input_filter #(.SIZE(2)) UART_IF_RI  (.CLK(CLK), .RST(iRST), .CE(iBaudtick2x), .D(iRINs),  .Q(iRIn));

    // Divisor latch registers
    logic [7:0] iDLL, iDLM;
    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST) begin
            iDLL <= 8'h00;
            iDLM <= 8'h00;
        end else begin
            if (iDLLWrite) iDLL <= PWDATA[7:0];
            if (iDLMWrite) iDLM <= PWDATA[7:0];
        end
    end

    // Interrupt enable register (bits 7:4 are always 0)
    logic [7:0] iIER;
    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST)        iIER <= 8'h00;
        else if (iIERWrite) iIER[3:0] <= PWDATA[3:0];
    end
    // bits 7:4 stay 0 (reset to 0, never updated)
    logic iIER_ERBI, iIER_ETBEI, iIER_ELSI, iIER_EDSSI;
    assign iIER_ERBI  = iIER[0];
    assign iIER_ETBEI = iIER[1];
    assign iIER_ELSI  = iIER[2];
    assign iIER_EDSSI = iIER[3];

    // Line control register
    logic [7:0] iLCR;
    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST)        iLCR <= 8'h00;
        else if (iLCRWrite) iLCR <= PWDATA[7:0];
    end
    assign iLCR_DLAB = iLCR[7];
    logic iLCR_STB, iLCR_PEN, iLCR_EPS, iLCR_SP, iLCR_BC;
    logic [1:0] iLCR_WLS;
    assign iLCR_WLS = iLCR[1:0];
    assign iLCR_STB = iLCR[2];
    assign iLCR_PEN = iLCR[3];
    assign iLCR_EPS = iLCR[4];
    assign iLCR_SP  = iLCR[5];
    assign iLCR_BC  = iLCR[6];

    // Modem control register (bits 7:6 always 0)
    logic [7:0] iMCR;
    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST)        iMCR <= 8'h00;
        else if (iMCRWrite) iMCR[5:0] <= PWDATA[5:0];
    end
    logic iMCR_DTR, iMCR_RTS, iMCR_OUT1, iMCR_OUT2, iMCR_LOOP, iMCR_AFE;
    assign iMCR_DTR  = iMCR[0];
    assign iMCR_RTS  = iMCR[1];
    assign iMCR_OUT1 = iMCR[2];
    assign iMCR_OUT2 = iMCR[3];
    assign iMCR_LOOP = iMCR[4];
    assign iMCR_AFE  = iMCR[5];

    // Scratch register
    logic [7:0] iSCR;
    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST)        iSCR <= 8'h00;
        else if (iSCRWrite) iSCR <= PWDATA[7:0];
    end

    // FCR register
    logic iFCR_FIFOEnable, iFCR_RXFIFOReset, iFCR_TXFIFOReset;
    logic iFCR_DMAMode, iFCR_FIFO64E;
    logic [1:0] iFCR_RXTrigger;

    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST) begin
            iFCR_FIFOEnable  <= 1'b0;
            iFCR_RXFIFOReset <= 1'b0;
            iFCR_TXFIFOReset <= 1'b0;
            iFCR_DMAMode     <= 1'b0;
            iFCR_FIFO64E     <= 1'b0;
            iFCR_RXTrigger   <= 2'b00;
        end else begin
            iFCR_RXFIFOReset <= 1'b0;
            iFCR_TXFIFOReset <= 1'b0;
            if (iFCRWrite) begin
                iFCR_FIFOEnable <= PWDATA[0];
                iFCR_DMAMode    <= PWDATA[3];
                iFCR_RXTrigger  <= PWDATA[7:6];
                if (iLCR_DLAB)
                    iFCR_FIFO64E <= PWDATA[5];
                // RX FIFO reset
                if (PWDATA[1] || (!iFCR_FIFOEnable && PWDATA[0]) ||
                                  (iFCR_FIFOEnable && !PWDATA[0]))
                    iFCR_RXFIFOReset <= 1'b1;
                // TX FIFO reset
                if (PWDATA[2] || (!iFCR_FIFOEnable && PWDATA[0]) ||
                                  (iFCR_FIFOEnable && !PWDATA[0]))
                    iFCR_TXFIFOReset <= 1'b1;
            end
        end
    end

    // Baudrate generation
    logic [15:0] iBaudgenDiv;
    logic        iBaudtick16x;
    logic        iBAUDOUTN, iRCLK;
    assign iBaudgenDiv = {iDLM, iDLL};

    uart_baudgen UART_BG16 (
        .CLK    (CLK),
        .RST    (iRST),
        .CE     (1'b1),
        .CLEAR  (1'b0),
        .DIVIDER(iBaudgenDiv),
        .BAUDTICK(iBaudtick16x)
    );
    slib_clock_div #(.RATIO(8)) UART_BG2 (
        .CLK(CLK), .RST(iRST), .CE(iBaudtick16x), .Q(iBaudtick2x)
    );
    slib_edge_detect UART_RCLK (
        .CLK(CLK), .RST(iRST), .D(iBAUDOUTN), .RE(iRCLK), .FE()
    );

    // TX FIFO (WIDTH=8, SIZE_E=6 -> depth 64)
    logic [7:0] iTXFIFOQ;
    logic       iTXFIFOEmpty, iTXFIFO64Full;
    logic [5:0] iTXFIFOUsage;
    logic       iTXFIFOWrite, iTXFIFORead, iTXFIFOClear;
    logic       iTXFIFOFull, iTXFIFO16Full;

    slib_fifo #(.WIDTH(8), .SIZE_E(6)) UART_TXFF (
        .CLK  (CLK),
        .RST  (iRST),
        .CLEAR(iTXFIFOClear),
        .WRITE(iTXFIFOWrite),
        .READ (iTXFIFORead),
        .D    (PWDATA[7:0]),
        .Q    (iTXFIFOQ),
        .EMPTY(iTXFIFOEmpty),
        .FULL (iTXFIFO64Full),
        .USAGE(iTXFIFOUsage)
    );
    assign iTXFIFO16Full = iTXFIFOUsage[4];
    assign iTXFIFOFull   = iFCR_FIFO64E ? iTXFIFO64Full : iTXFIFO16Full;
    assign iTXFIFOWrite  = iTHRWrite &
                           ((~iFCR_FIFOEnable & iTXFIFOEmpty) |
                            ( iFCR_FIFOEnable & ~iTXFIFOFull));
    assign iTXFIFOClear  = iFCR_TXFIFOReset;

    // RX FIFO (WIDTH=11 for data+PE+FE+BI, SIZE_E=6)
    logic [10:0] iRXFIFOD, iRXFIFOQ;
    logic        iRXFIFOEmpty, iRXFIFO64Full;
    logic [5:0]  iRXFIFOUsage;
    logic        iRXFIFOWrite, iRXFIFORead, iRXFIFOClear;
    logic        iRXFIFOFull, iRXFIFO16Full;
    logic        iRXFIFOTrigger, iRXFIFO16Trigger, iRXFIFO64Trigger;
    logic        iRXFIFOPE, iRXFIFOFE, iRXFIFOBI;

    slib_fifo #(.WIDTH(11), .SIZE_E(6)) UART_RXFF (
        .CLK  (CLK),
        .RST  (iRST),
        .CLEAR(iRXFIFOClear),
        .WRITE(iRXFIFOWrite),
        .READ (iRXFIFORead),
        .D    (iRXFIFOD),
        .Q    (iRXFIFOQ),
        .EMPTY(iRXFIFOEmpty),
        .FULL (iRXFIFO64Full),
        .USAGE(iRXFIFOUsage)
    );
    assign iRXFIFORead    = iRBRRead;
    assign iRXFIFO16Full  = iRXFIFOUsage[4];
    assign iRXFIFOFull    = iFCR_FIFO64E ? iRXFIFO64Full : iRXFIFO16Full;

    // RX FIFO trigger levels (16-byte mode: 1, 4, 8, 14)
    assign iRXFIFO16Trigger =
        ((iFCR_RXTrigger == 2'b00) & ~iRXFIFOEmpty)                              |
        ((iFCR_RXTrigger == 2'b01) & (iRXFIFOUsage[2] | iRXFIFOUsage[3]))        |
        ((iFCR_RXTrigger == 2'b10) & iRXFIFOUsage[3])                            |
        ((iFCR_RXTrigger == 2'b11) & iRXFIFOUsage[3] & iRXFIFOUsage[2] & iRXFIFOUsage[1]) |
        iRXFIFO16Full;

    // RX FIFO trigger levels (64-byte mode: 1, 16, 32, 56)
    assign iRXFIFO64Trigger =
        ((iFCR_RXTrigger == 2'b00) & ~iRXFIFOEmpty)                              |
        ((iFCR_RXTrigger == 2'b01) & (iRXFIFOUsage[4] | iRXFIFOUsage[5]))        |
        ((iFCR_RXTrigger == 2'b10) & iRXFIFOUsage[5])                            |
        ((iFCR_RXTrigger == 2'b11) & iRXFIFOUsage[5] & iRXFIFOUsage[4] & iRXFIFOUsage[3]) |
        iRXFIFO64Full;

    assign iRXFIFOTrigger = iFCR_FIFO64E ? iRXFIFO64Trigger : iRXFIFO16Trigger;

    // Transmitter
    logic [7:0] iTSR;
    logic       iTXStart, iTXClear, iTXFinished, iTXRunning;
    logic       iSOUT;
    assign iTXClear = 1'b0;

    uart_transmitter UART_TX (
        .CLK      (CLK),
        .RST      (iRST),
        .TXCLK    (iBaudtick2x),
        .TXSTART  (iTXStart),
        .CLEAR    (iTXClear),
        .WLS      (iLCR_WLS),
        .STB      (iLCR_STB),
        .PEN      (iLCR_PEN),
        .EPS      (iLCR_EPS),
        .SP       (iLCR_SP),
        .BC       (iLCR_BC),
        .DIN      (iTSR),
        .TXFINISHED(iTXFinished),
        .SOUT     (iSOUT)
    );

    // Receiver
    logic        iSIN;
    logic        iRXFinished, iRXClear;
    logic [7:0]  iRXData;
    logic        iRXPE, iRXFE, iRXBI;
    assign iRXClear = 1'b0;
    assign iSIN = iMCR_LOOP ? iSOUT : iSINr;

    uart_receiver UART_RX (
        .CLK      (CLK),
        .RST      (iRST),
        .RXCLK    (iRCLK),
        .RXCLEAR  (iRXClear),
        .WLS      (iLCR_WLS),
        .STB      (iLCR_STB),
        .PEN      (iLCR_PEN),
        .EPS      (iLCR_EPS),
        .SP       (iLCR_SP),
        .SIN      (iSIN),
        .PE       (iRXPE),
        .FE       (iRXFE),
        .BI       (iRXBI),
        .DOUT     (iRXData),
        .RXFINISHED(iRXFinished)
    );

    // TX enable
    logic iTXEnable;
    logic iMSR_CTS;  // forward
    assign iTXEnable = ~iTXFIFOEmpty & (~iMCR_AFE | (iMCR_AFE & iMSR_CTS));

    // TX process (IDLE -> TXSTART -> TXRUN -> TXEND)
    localparam [1:0] TX_IDLE=2'd0, TX_TXSTART=2'd1, TX_TXRUN=2'd2, TX_TXEND=2'd3;
    logic [1:0] TXState;

    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST) begin
            TXState     <= TX_IDLE;
            iTSR        <= 8'h00;
            iTXStart    <= 1'b0;
            iTXFIFORead <= 1'b0;
            iTXRunning  <= 1'b0;
        end else begin
            iTXStart    <= 1'b0;
            iTXFIFORead <= 1'b0;
            iTXRunning  <= 1'b0;
            case (TXState)
                TX_IDLE:    if (iTXEnable) begin
                                iTXStart <= 1'b1;
                                TXState  <= TX_TXSTART;
                            end
                TX_TXSTART: begin
                                iTSR        <= iTXFIFOQ;
                                iTXStart    <= 1'b1;
                                iTXFIFORead <= 1'b1;
                                TXState     <= TX_TXRUN;
                            end
                TX_TXRUN:   begin
                                iTXRunning <= 1'b1;
                                iTXStart   <= 1'b1;
                                if (iTXFinished) TXState <= TX_TXEND;
                            end
                TX_TXEND:   TXState <= TX_IDLE;
                default:    TXState <= TX_IDLE;
            endcase
        end
    end

    // RX process (IDLE -> RXSAVE)
    localparam [0:0] RX_IDLE=1'b0, RX_RXSAVE=1'b1;
    logic RXState;

    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST) begin
            RXState      <= RX_IDLE;
            iRXFIFOWrite <= 1'b0;
            iRXFIFOClear <= 1'b0;
            iRXFIFOD     <= 11'h000;
        end else begin
            iRXFIFOWrite <= 1'b0;
            iRXFIFOClear <= iFCR_RXFIFOReset;
            case (RXState)
                RX_IDLE:   if (iRXFinished) begin
                                iRXFIFOD <= {iRXBI, iRXFE, iRXPE, iRXData};
                                if (!iFCR_FIFOEnable)
                                    iRXFIFOClear <= 1'b1;
                                RXState <= RX_RXSAVE;
                            end
                RX_RXSAVE: begin
                                if (!iFCR_FIFOEnable)
                                    iRXFIFOWrite <= 1'b1;
                                else if (!iRXFIFOFull)
                                    iRXFIFOWrite <= 1'b1;
                                RXState <= RX_IDLE;
                            end
                default:   RXState <= RX_IDLE;
            endcase
        end
    end

    // RX FIFO error flags
    assign iRXFIFOPE = ~iRXFIFOEmpty & iRXFIFOQ[8];
    assign iRXFIFOFE = ~iRXFIFOEmpty & iRXFIFOQ[9];
    assign iRXFIFOBI = ~iRXFIFOEmpty & iRXFIFOQ[10];

    logic iPERE, iFERE, iBIRE;
    slib_edge_detect UART_PEDET (.CLK(CLK), .RST(iRST), .D(iRXFIFOPE), .RE(iPERE), .FE());
    slib_edge_detect UART_FEDET (.CLK(CLK), .RST(iRST), .D(iRXFIFOFE), .RE(iFERE), .FE());
    slib_edge_detect UART_BIDET (.CLK(CLK), .RST(iRST), .D(iRXFIFOBI), .RE(iBIRE), .FE());

    // LSR register
    logic [7:0] iLSR;
    logic iLSR_DR, iLSR_OE, iLSR_PE, iLSR_FE_bit, iLSR_BI;
    logic iLSR_THRE, iLSR_TEMT, iLSR_THRNF, iLSR_FIFOERR;

    logic iFEIncrement, iFEDecrement;
    int   iFECounter;

    assign iFEIncrement = iRXFIFOWrite & (iRXFIFOD[10:8] != 3'b000);
    assign iFEDecrement = (iFECounter != 0) & ~iRXFIFOEmpty &
                          (iPERE | iFERE | iBIRE);

    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST) begin
            iLSR_OE      <= 1'b0;
            iLSR_PE      <= 1'b0;
            iLSR_FE_bit  <= 1'b0;
            iLSR_BI      <= 1'b0;
            iFECounter   <= 0;
            iLSR_FIFOERR <= 1'b0;
        end else begin
            // Overrun error
            if ((~iFCR_FIFOEnable & iLSR_DR & iRXFinished) |
                ( iFCR_FIFOEnable & iRXFIFOFull & iRXFinished))
                iLSR_OE <= 1'b1;
            else if (iLSRRead)
                iLSR_OE <= 1'b0;
            // Parity error
            if (iPERE)       iLSR_PE <= 1'b1;
            else if (iLSRRead) iLSR_PE <= 1'b0;
            // Frame error
            if (iFERE)       iLSR_FE_bit <= 1'b1;
            else if (iLSRRead) iLSR_FE_bit <= 1'b0;
            // Break interrupt
            if (iBIRE)       iLSR_BI <= 1'b1;
            else if (iLSRRead) iLSR_BI <= 1'b0;
            // FIFO error flag
            if (iFECounter != 0)
                iLSR_FIFOERR <= 1'b1;
            else if (iRXFIFOEmpty | (iRXFIFOQ[10:8] == 3'b000))
                iLSR_FIFOERR <= 1'b0;
            // FIFO error counter
            if (iRXFIFOClear)
                iFECounter <= 0;
            else begin
                if ( iFEIncrement & ~iFEDecrement) iFECounter <= iFECounter + 1;
                if (~iFEIncrement &  iFEDecrement) iFECounter <= iFECounter - 1;
            end
        end
    end

    assign iLSR_DR    = ~iRXFIFOEmpty | iRXFIFOWrite;
    assign iLSR_THRE  = iTXFIFOEmpty;
    assign iLSR_TEMT  = ~iTXRunning & iLSR_THRE;
    assign iLSR_THRNF = (~iFCR_FIFOEnable & iTXFIFOEmpty) |
                        ( iFCR_FIFOEnable & ~iTXFIFOFull);

    assign iLSR[0] = iLSR_DR;
    assign iLSR[1] = iLSR_OE;
    assign iLSR[2] = iLSR_PE;
    assign iLSR[3] = iLSR_FE_bit;
    assign iLSR[4] = iLSR_BI;
    assign iLSR[5] = iLSR_THRNF;
    assign iLSR[6] = iLSR_TEMT;
    assign iLSR[7] = iFCR_FIFOEnable & iLSR_FIFOERR;

    // Modem status register
    logic iMSR_DSR, iMSR_RI, iMSR_DCD;
    logic iMSR_dCTS, iMSR_dDSR, iMSR_TERI, iMSR_dDCD;
    logic iCTSnRE, iCTSnFE, iDSRnRE, iDSRnFE, iRInRE, iRInFE, iDCDnRE, iDCDnFE;
    logic iRTS;
    logic [7:0] iMSR;

    assign iMSR_CTS = (iMCR_LOOP & iRTS)       | (~iMCR_LOOP & ~iCTSn);
    assign iMSR_DSR = (iMCR_LOOP & iMCR_DTR)   | (~iMCR_LOOP & ~iDSRn);
    assign iMSR_RI  = (iMCR_LOOP & iMCR_OUT1)  | (~iMCR_LOOP & ~iRIn);
    assign iMSR_DCD = (iMCR_LOOP & iMCR_OUT2)  | (~iMCR_LOOP & ~iDCDn);

    slib_edge_detect UART_ED_CTS (.CLK(CLK), .RST(iRST), .D(iMSR_CTS), .RE(iCTSnRE), .FE(iCTSnFE));
    slib_edge_detect UART_ED_DSR (.CLK(CLK), .RST(iRST), .D(iMSR_DSR), .RE(iDSRnRE), .FE(iDSRnFE));
    slib_edge_detect UART_ED_RI  (.CLK(CLK), .RST(iRST), .D(iMSR_RI),  .RE(iRInRE),  .FE(iRInFE));
    slib_edge_detect UART_ED_DCD (.CLK(CLK), .RST(iRST), .D(iMSR_DCD), .RE(iDCDnRE), .FE(iDCDnFE));

    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST) begin
            iMSR_dCTS <= 1'b0; iMSR_dDSR <= 1'b0;
            iMSR_TERI <= 1'b0; iMSR_dDCD <= 1'b0;
        end else begin
            if (iCTSnRE | iCTSnFE) iMSR_dCTS <= 1'b1;
            else if (iMSRRead)     iMSR_dCTS <= 1'b0;
            if (iDSRnRE | iDSRnFE) iMSR_dDSR <= 1'b1;
            else if (iMSRRead)     iMSR_dDSR <= 1'b0;
            if (iRInFE)            iMSR_TERI <= 1'b1;
            else if (iMSRRead)     iMSR_TERI <= 1'b0;
            if (iDCDnRE | iDCDnFE) iMSR_dDCD <= 1'b1;
            else if (iMSRRead)     iMSR_dDCD <= 1'b0;
        end
    end
    assign iMSR = {iMSR_DCD, iMSR_RI, iMSR_DSR, iMSR_CTS,
                   iMSR_dDCD, iMSR_TERI, iMSR_dDSR, iMSR_dCTS};

    // Automatic flow control
    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST)
            iRTS <= 1'b0;
        else begin
            if (~iMCR_RTS | (iMCR_AFE & iRXFIFOTrigger))
                iRTS <= 1'b0;
            else if (iMCR_RTS & (~iMCR_AFE | (iMCR_AFE & iRXFIFOEmpty)))
                iRTS <= 1'b1;
        end
    end

    // Interrupt controller
    logic iRDAInterrupt, iCharTimeout;
    logic iLSR_THRERE, iTHRInterrupt;
    logic [3:0] iIIR_lo;
    logic [7:0] iIIR;

    assign iRDAInterrupt = (~iFCR_FIFOEnable & iLSR_DR) |
                           ( iFCR_FIFOEnable & iRXFIFOTrigger);

    uart_interrupt UART_IIC (
        .CLK(CLK), .RST(iRST),
        .IER(iIER[3:0]),
        .LSR(iLSR[4:0]),
        .THI(iTHRInterrupt),
        .RDA(iRDAInterrupt),
        .CTI(iCharTimeout),
        .AFE(iMCR_AFE),
        .MSR(iMSR[3:0]),
        .IIR(iIIR_lo),
        .INT(INT)
    );

    assign iIIR[3:0] = iIIR_lo;
    assign iIIR[4]   = 1'b0;
    assign iIIR[5]   = iFCR_FIFOEnable ? iFCR_FIFO64E : 1'b0;
    assign iIIR[6]   = iFCR_FIFOEnable;
    assign iIIR[7]   = iFCR_FIFOEnable;

    // THR empty rising edge for interrupt
    slib_edge_detect UART_IIC_THRE_ED (
        .CLK(CLK), .RST(iRST), .D(iLSR_THRE), .RE(iLSR_THRERE), .FE()
    );

    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST)
            iTHRInterrupt <= 1'b0;
        else begin
            if (iLSR_THRERE | iFCR_TXFIFOReset |
                (iIERWrite & PWDATA[1] & iLSR_THRE))
                iTHRInterrupt <= 1'b1;
            else if ((iIIRRead & (iIIR[3:1] == 3'b001)) | iTHRWrite)
                iTHRInterrupt <= 1'b0;
        end
    end

    // Character timeout counter (FIFO mode)
    logic [5:0] iTimeoutCount;

    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST) begin
            iTimeoutCount <= 6'h00;
            iCharTimeout  <= 1'b0;
        end else begin
            if (iRXFIFOEmpty | iRBRRead | iRXFIFOWrite)
                iTimeoutCount <= 6'h00;
            else if (~iRXFIFOEmpty & iBaudtick2x & ~iTimeoutCount[5])
                iTimeoutCount <= iTimeoutCount + 1'b1;

            if (iFCR_FIFOEnable) begin
                if (iRBRRead)             iCharTimeout <= 1'b0;
                else if (iTimeoutCount[5]) iCharTimeout <= 1'b1;
            end else
                iCharTimeout <= 1'b0;
        end
    end

    // RBR (read from RX FIFO output)
    logic [7:0] iRBR;
    assign iRBR = iRXFIFOQ[7:0];

    // Output registers (registered, as in VHDL OUTREGS process)
    always_ff @(posedge CLK or posedge iRST) begin
        if (iRST) begin
            iBAUDOUTN <= 1'b1;
            OUT1N     <= 1'b1;
            OUT2N     <= 1'b1;
            RTSN      <= 1'b1;
            DTRN      <= 1'b1;
            SOUT      <= 1'b1;
        end else begin
            iBAUDOUTN <= 1'b0;
            OUT1N     <= 1'b0;
            OUT2N     <= 1'b0;
            RTSN      <= 1'b0;
            DTRN      <= 1'b0;
            SOUT      <= 1'b0;
            if (~iBaudtick16x)                 iBAUDOUTN <= 1'b1;
            if ( iMCR_LOOP | ~iMCR_OUT1)       OUT1N     <= 1'b1;
            if ( iMCR_LOOP | ~iMCR_OUT2)       OUT2N     <= 1'b1;
            if ( iMCR_LOOP | ~iRTS)            RTSN      <= 1'b1;
            if ( iMCR_LOOP | ~iMCR_DTR)        DTRN      <= 1'b1;
            if ( iMCR_LOOP |  iSOUT)           SOUT      <= 1'b1;
        end
    end

    // APB read data mux – full 32 bits driven here (upper 24 always 0)
    always @(*) begin
        case (PADDR)
            3'b000: PRDATA = {24'h0, iLCR_DLAB ? iDLL : iRBR};
            3'b001: PRDATA = {24'h0, iLCR_DLAB ? iDLM : iIER[7:0]};
            3'b010: PRDATA = {24'h0, iIIR};
            3'b011: PRDATA = {24'h0, iLCR};
            3'b100: PRDATA = {24'h0, iMCR};
            3'b101: PRDATA = {24'h0, iLSR};
            3'b110: PRDATA = {24'h0, iMSR};
            3'b111: PRDATA = {24'h0, iSCR};
            default: PRDATA = {24'h0, iRBR};
        endcase
    end
    assign PREADY       = 1'b1;
    assign PSLVERR      = 1'b0;

endmodule
