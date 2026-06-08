module uart_transmitter (
    input  logic        CLK,
    input  logic        RST,
    input  logic        TXCLK,
    input  logic        TXSTART,
    input  logic        CLEAR,
    input  logic [1:0]  WLS,
    input  logic        STB,
    input  logic        PEN,
    input  logic        EPS,
    input  logic        SP,
    input  logic        BC,
    input  logic [7:0]  DIN,
    output logic        TXFINISHED,
    output logic        SOUT
);
    localparam [3:0] IDLE=0,  START=1, BIT0=2,  BIT1=3,
                     BIT2=4,  BIT3=5,  BIT4=6,  BIT5=7,
                     BIT6=8,  BIT7=9,  PAR=10,  STOP=11, STOP2=12;

    logic [3:0] CState, NState;
    logic       iTx2;
    logic       iSout;
    logic       iParity;
    logic       iFinished;
    logic       iLast;

    // State register + 2-tick counter
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            CState <= IDLE;
            iTx2   <= 1'b0;
        end else if (TXCLK) begin
            if (!iTx2) begin
                CState <= NState;
                iTx2   <= 1'b1;
            end else begin
                if ((WLS == 2'b00) && STB && (CState == STOP2)) begin
                    CState <= NState;   // 1.5 stop bits for 5-bit word
                    iTx2   <= 1'b1;
                end else begin
                    iTx2   <= 1'b0;
                end
            end
        end
    end

    // Combinational next-state and serial output
    always @(*) begin
        NState = IDLE;
        iSout  = 1'b1;
        case (CState)
            IDLE:   if (TXSTART) NState = START;
            START:  begin iSout = 1'b0; NState = BIT0; end
            BIT0:   begin iSout = DIN[0]; NState = BIT1; end
            BIT1:   begin iSout = DIN[1]; NState = BIT2; end
            BIT2:   begin iSout = DIN[2]; NState = BIT3; end
            BIT3:   begin iSout = DIN[3]; NState = BIT4; end
            BIT4:   begin
                        iSout = DIN[4];
                        if (WLS == 2'b00) NState = PEN ? PAR : STOP;
                        else              NState = BIT5;
                    end
            BIT5:   begin
                        iSout = DIN[5];
                        if (WLS == 2'b01) NState = PEN ? PAR : STOP;
                        else              NState = BIT6;
                    end
            BIT6:   begin
                        iSout = DIN[6];
                        if (WLS == 2'b10) NState = PEN ? PAR : STOP;
                        else              NState = BIT7;
                    end
            BIT7:   begin iSout = DIN[7]; NState = PEN ? PAR : STOP; end
            PAR:    begin
                        if (SP)  iSout = EPS ? 1'b0 : 1'b1;
                        else     iSout = EPS ? iParity : ~iParity;
                        NState = STOP;
                    end
            STOP:   begin
                        if (STB)          NState = STOP2;
                        else if (TXSTART) NState = START;
                    end
            STOP2:  if (TXSTART) NState = START;
            default: ;
        endcase
    end

    // Parity over the word (widened combinationally)
    logic iP40, iP50, iP60, iP70;
    assign iP40 = DIN[4] ^ DIN[3] ^ DIN[2] ^ DIN[1] ^ DIN[0];
    assign iP50 = DIN[5] ^ iP40;
    assign iP60 = DIN[6] ^ iP50;
    assign iP70 = DIN[7] ^ iP60;

    always @(*) begin
        case (WLS)
            2'b00:   iParity = iP40;
            2'b01:   iParity = iP50;
            2'b10:   iParity = iP60;
            default: iParity = iP70;
        endcase
    end

    // Pulse TXFINISHED on the first clock that CState enters STOP
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            iFinished <= 1'b0;
            iLast     <= 1'b0;
        end else begin
            iFinished <= 1'b0;
            if (!iLast && CState == STOP)
                iFinished <= 1'b1;
            iLast <= (CState == STOP);
        end
    end

    assign SOUT       = BC ? 1'b0 : iSout;
    assign TXFINISHED = iFinished;
endmodule
