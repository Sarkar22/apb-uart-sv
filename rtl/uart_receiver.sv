module uart_receiver (
    input  logic        CLK,
    input  logic        RST,
    input  logic        RXCLK,
    input  logic        RXCLEAR,
    input  logic [1:0]  WLS,
    input  logic        STB,
    input  logic        PEN,
    input  logic        EPS,
    input  logic        SP,
    input  logic        SIN,
    output logic        PE,
    output logic        FE,
    output logic        BI,
    output logic [7:0]  DOUT,
    output logic        RXFINISHED
);
    localparam [2:0] IDLE=0, START=1, DATA=2, PAR=3, STOP=4, MWAIT=5;

    logic [3:0] iBaudCount;
    logic       iBaudCountClear;
    logic       iBaudStep;
    logic       iBaudStepD;
    logic       iFilterClear;
    logic       iFSIN;
    logic       iFStopBit;
    logic       iParity;
    logic       iParityReceived;
    logic [3:0] iDataCount;       // range 0..8, 4 bits sufficient
    logic       iDataCountInit;
    logic       iDataCountFinish;
    logic       iRXFinished;
    logic       iFE_int;
    logic       iBI_int;
    logic       iNoStopReceived;
    logic [7:0] iDOUT;
    logic [2:0] CState, NState;

    // Baudrate counter: overflows every 16 RXCLK pulses -> iBaudStep
    slib_counter #(.WIDTH(4)) RX_BRC (
        .CLK     (CLK),
        .RST     (RST),
        .CLEAR   (iBaudCountClear),
        .LOAD    (1'b0),
        .ENABLE  (RXCLK),
        .DOWN    (1'b0),
        .D       (4'h0),
        .Q       (iBaudCount),
        .OVERFLOW(iBaudStep)
    );

    // Majority-vote filter (samples SIN over 16x clock, fires when >=10 high)
    slib_mv_filter #(.WIDTH(4), .THRESHOLD(10)) RX_MVF (
        .CLK   (CLK),
        .RST   (RST),
        .SAMPLE(RXCLK),
        .CLEAR (iFilterClear),
        .D     (SIN),
        .Q     (iFSIN)
    );

    // Input filter for stop-bit detection
    slib_input_filter #(.SIZE(4)) RX_IFSB (
        .CLK(CLK),
        .RST(RST),
        .CE (RXCLK),
        .D  (SIN),
        .Q  (iFStopBit)
    );

    // iBaudStepD: iBaudStep delayed one clock
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) iBaudStepD <= 1'b0;
        else     iBaudStepD <= iBaudStep;
    end

    assign iFilterClear = iBaudStepD | iBaudCountClear;

    // Parity over all 8 received bits
    assign iParity = iDOUT[7] ^ iDOUT[6] ^ iDOUT[5] ^ iDOUT[4] ^
                     iDOUT[3] ^ iDOUT[2] ^ iDOUT[1] ^ iDOUT[0] ^ (~EPS);

    // Data-bit capture (serial shift into indexed position)
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            iDataCount <= 4'h0;
            iDOUT      <= 8'h00;
        end else begin
            if (iDataCountInit) begin
                iDataCount <= 4'h0;
                iDOUT      <= 8'h00;
            end else if (iBaudStep && !iDataCountFinish) begin
                case (iDataCount)
                    4'd0: iDOUT[0] <= iFSIN;
                    4'd1: iDOUT[1] <= iFSIN;
                    4'd2: iDOUT[2] <= iFSIN;
                    4'd3: iDOUT[3] <= iFSIN;
                    4'd4: iDOUT[4] <= iFSIN;
                    4'd5: iDOUT[5] <= iFSIN;
                    4'd6: iDOUT[6] <= iFSIN;
                    4'd7: iDOUT[7] <= iFSIN;
                    default: ;
                endcase
                iDataCount <= iDataCount + 4'h1;
            end
        end
    end

    assign iDataCountFinish = ((WLS == 2'b00) && (iDataCount == 4'd5)) ||
                              ((WLS == 2'b01) && (iDataCount == 4'd6)) ||
                              ((WLS == 2'b10) && (iDataCount == 4'd7)) ||
                              ((WLS == 2'b11) && (iDataCount == 4'd8));

    // FSM state register
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) CState <= IDLE;
        else     CState <= NState;
    end

    // RX FSM
    always @(*) begin
        NState          = IDLE;
        iBaudCountClear = 1'b0;
        iDataCountInit  = 1'b0;
        iRXFinished     = 1'b0;
        case (CState)
            IDLE:  begin
                       if (!SIN) NState = START;
                       iBaudCountClear = 1'b1;
                       iDataCountInit  = 1'b1;
                   end
            START: begin
                       iDataCountInit = 1'b1;
                       if (iBaudStep) begin
                           if (!iFSIN) NState = DATA;
                       end else
                           NState = START;
                   end
            DATA:  begin
                       if (iDataCountFinish) NState = PEN ? PAR : STOP;
                       else                  NState = DATA;
                   end
            PAR:   begin
                       if (iBaudStep) NState = STOP;
                       else           NState = PAR;
                   end
            STOP:  begin
                       if (iBaudCount[3]) begin
                           iRXFinished = 1'b1;
                           NState = iFStopBit ? IDLE : MWAIT;
                       end else
                           NState = STOP;
                   end
            MWAIT: begin
                       if (!SIN) NState = MWAIT;
                   end
            default: ;
        endcase
    end

    // Parity check
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            PE              <= 1'b0;
            iParityReceived <= 1'b0;
        end else begin
            if (CState == PAR && iBaudStep)
                iParityReceived <= iFSIN;

            if (PEN) begin
                PE <= 1'b0;
                if (SP) begin
                    if ((EPS ^ iParityReceived) == 1'b0)
                        PE <= 1'b1;
                end else begin
                    if (iParity != iParityReceived)
                        PE <= 1'b1;
                end
            end else begin
                PE              <= 1'b0;
                iParityReceived <= 1'b0;
            end
        end
    end

    assign iNoStopReceived = ~iFStopBit & (CState == STOP);
    assign iBI_int = (iDOUT == 8'h00) & ~iParityReceived & iNoStopReceived;
    assign iFE_int = iNoStopReceived;

    assign DOUT       = iDOUT;
    assign BI         = iBI_int;
    assign FE         = iFE_int;
    assign RXFINISHED = iRXFinished;
endmodule
