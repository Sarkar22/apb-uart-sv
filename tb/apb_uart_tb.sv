`timescale 1ns/1ps

module apb_uart_tb;

    logic        CLK    = 1'b0;
    logic        RSTN   = 1'b0;
    logic        PSEL   = 1'b0;
    logic        PENABLE= 1'b0;
    logic        PWRITE = 1'b0;
    logic [2:0]  PADDR  = 3'b000;
    logic [31:0] PWDATA = 32'h0;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;
    logic        INT;
    logic        OUT1N, OUT2N, RTSN, DTRN;
    logic        CTSN = 1'b1;
    logic        DSRN = 1'b1;
    logic        DCDN = 1'b1;
    logic        RIN  = 1'b1;
    logic        SIN  = 1'b1;
    logic        SOUT;

    localparam real CLK_P = 20.0;  // 50 MHz

    always #(CLK_P/2) CLK = ~CLK;

    apb_uart DUT (
        .CLK    (CLK),    .RSTN   (RSTN),
        .PSEL   (PSEL),   .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR  (PADDR),  .PWDATA (PWDATA),
        .PRDATA (PRDATA), .PREADY (PREADY),  .PSLVERR(PSLVERR),
        .INT    (INT),
        .OUT1N  (OUT1N),  .OUT2N  (OUT2N),
        .RTSN   (RTSN),   .DTRN   (DTRN),
        .CTSN   (CTSN),   .DSRN   (DSRN),
        .DCDN   (DCDN),   .RIN    (RIN),
        .SIN    (SIN),    .SOUT   (SOUT)
    );

    // Log file
    integer logf;
    initial logf = $fopen("sim.log", "w");

    task log_ev(input string ev, input int a, d, input string ex);
        $fdisplay(logf, "%0t ns,%s,%0d,%0d,%s", $time, ev, a, d, ex);
    endtask

    // Wait N rising edges of CLK
    task wait_n(input int n);
        repeat (n) @(posedge CLK);
    endtask

    // APB write
    task do_wr(input int addr, input int data, input string label);
        @(posedge CLK);
        PSEL   <= 1'b1; PWRITE <= 1'b1;
        PADDR  <= addr[2:0]; PWDATA <= data;
        PENABLE<= 1'b0;
        @(posedge CLK);
        PENABLE <= 1'b1;
        @(posedge CLK);
        PSEL    <= 1'b0; PENABLE <= 1'b0; PWRITE <= 1'b0;
        log_ev("APB_WR", addr, data, label);
    endtask

    // APB read
    task do_rd(input int addr, input string label);
        @(posedge CLK);
        PSEL   <= 1'b1; PWRITE <= 1'b0;
        PADDR  <= addr[2:0];
        PENABLE<= 1'b0;
        @(posedge CLK);
        PENABLE <= 1'b1;
        @(posedge CLK);
        PSEL    <= 1'b0; PENABLE <= 1'b0;
        log_ev("APB_RD", addr, $unsigned(PRDATA[7:0]), label);
    endtask

    // Poll LSR[0] (DR) until set, up to 1000 iterations
    task poll_dr(input string label);
        int tout;
        logic [7:0] rdata;
        int done;
        tout = 0; done = 0;
        while (!done) begin
            @(posedge CLK);
            PSEL   <= 1'b1; PWRITE <= 1'b0; PADDR <= 3'b101; PENABLE <= 1'b0;
            @(posedge CLK);
            PENABLE <= 1'b1;
            @(posedge CLK);
            rdata = PRDATA[7:0];
            PSEL    <= 1'b0; PENABLE <= 1'b0;
            tout = tout + 1;
            if (rdata[0]) begin
                log_ev("LSR_DR", 5, $unsigned(rdata), label);
                done = 1;
            end else if (tout >= 1000) begin
                log_ev("LSR_TIMEOUT", 5, $unsigned(rdata), label);
                done = 1;
            end
        end
    endtask

    // Setup UART (DLL=2, DLM=0, LCR=lcr_val, MCR=mcr_val)
    task uart_setup(input int lcr_val, mcr_val);
        do_wr(3, 8'h80, "LCR_DLAB_EN");
        do_wr(0, 2,     "DLL_2");
        do_wr(1, 0,     "DLM_0");
        do_wr(3, lcr_val, "LCR_SET");
        do_wr(4, mcr_val, "MCR_SET");
    endtask

    initial begin
        $fdisplay(logf, "TIME_NS,EVENT,A,D,EXTRA");

        // Reset
        RSTN = 1'b0;
        wait_n(10);
        RSTN = 1'b1;
        wait_n(2);
        log_ev("RST_DONE", 0, 0, "RSTN_HIGH");

        // TEST 1: Reset check - LSR should be 0x60 (THRE|TEMT)
        $fdisplay(logf, "# TEST1: reset check");
        do_rd(5, "LSR_RESET");

        // TEST 2: SCR scratch register
        $fdisplay(logf, "# TEST2: SCR scratch");
        do_wr(7, 8'hA5, "SCR_WR_A5");
        do_rd(7, "SCR_RD_A5");
        do_wr(7, 8'h5A, "SCR_WR_5A");
        do_rd(7, "SCR_RD_5A");

        // TEST 3: Baud rate divisor readback (use DLL=2 to avoid baudgen overshoot)
        $fdisplay(logf, "# TEST3: baud divisor");
        do_wr(3, 8'h80, "LCR_DLAB_EN");
        do_wr(0, 8'h02, "DLL_WR_02");
        do_wr(1, 8'h00, "DLM_WR_00");
        do_rd(0, "DLL_RD");
        do_rd(1, "DLM_RD");
        do_wr(3, 8'h00, "LCR_DLAB_DIS");

        // TEST 4: 8N1 loopback - 4 bytes
        $fdisplay(logf, "# TEST4: 8N1 loopback");
        uart_setup(8'h03, 8'h10);
        do_wr(0, 8'h55, "THR_WR_55");
        poll_dr("DR_55"); do_rd(0, "RBR_RD_55");
        do_wr(0, 8'hAA, "THR_WR_AA");
        poll_dr("DR_AA"); do_rd(0, "RBR_RD_AA");
        do_wr(0, 8'h00, "THR_WR_00");
        poll_dr("DR_00"); do_rd(0, "RBR_RD_00");
        do_wr(0, 8'hFF, "THR_WR_FF");
        poll_dr("DR_FF"); do_rd(0, "RBR_RD_FF");

        // TEST 5: Word lengths (5/6/7/8 bit)
        $fdisplay(logf, "# TEST5: word lengths");
        do_wr(3, 8'h80, "LCR_DLAB_EN");
        do_wr(0, 2, "DLL_2"); do_wr(1, 0, "DLM_0");
        do_wr(3, 8'h00, "LCR_5N1"); do_wr(4, 8'h10, "MCR_LOOP");
        do_wr(0, 8'h1F, "THR_5BIT");
        poll_dr("DR_5BIT"); do_rd(0, "RBR_5BIT");
        do_wr(3, 8'h01, "LCR_6N1");
        do_wr(0, 8'h3F, "THR_6BIT");
        poll_dr("DR_6BIT"); do_rd(0, "RBR_6BIT");
        do_wr(3, 8'h02, "LCR_7N1");
        do_wr(0, 8'h7F, "THR_7BIT");
        poll_dr("DR_7BIT"); do_rd(0, "RBR_7BIT");
        do_wr(3, 8'h03, "LCR_8N1");
        do_wr(0, 8'hFF, "THR_8BIT");
        poll_dr("DR_8BIT"); do_rd(0, "RBR_8BIT");

        // TEST 6: Parity modes
        $fdisplay(logf, "# TEST6: parity modes");
        do_wr(3, 8'h80, "LCR_DLAB_EN");
        do_wr(0, 2, "DLL_2"); do_wr(1, 0, "DLM_0");
        do_wr(3, 8'h1B, "LCR_8E1"); do_wr(4, 8'h10, "MCR_LOOP");
        do_wr(0, 8'h55, "THR_55_EVEN");
        poll_dr("DR_EVEN"); do_rd(5, "LSR_EVEN"); do_rd(0, "RBR_55_EVEN");
        do_wr(3, 8'h0B, "LCR_8O1");
        do_wr(0, 8'h55, "THR_55_ODD");
        poll_dr("DR_ODD"); do_rd(5, "LSR_ODD"); do_rd(0, "RBR_55_ODD");
        do_wr(3, 8'h2B, "LCR_8STICK1");
        do_wr(0, 8'h55, "THR_55_STICK1");
        poll_dr("DR_STICK1"); do_rd(5, "LSR_STICK1"); do_rd(0, "RBR_55_STICK1");
        do_wr(3, 8'h3B, "LCR_8STICK0");
        do_wr(0, 8'h55, "THR_55_STICK0");
        poll_dr("DR_STICK0"); do_rd(5, "LSR_STICK0"); do_rd(0, "RBR_55_STICK0");

        // TEST 7: FIFO mode - burst write then read
        $fdisplay(logf, "# TEST7: FIFO mode");
        do_wr(3, 8'h80, "LCR_DLAB_EN");
        do_wr(0, 2, "DLL_2"); do_wr(1, 0, "DLM_0");
        do_wr(3, 8'h03, "LCR_8N1"); do_wr(4, 8'h10, "MCR_LOOP");
        do_wr(2, 8'h01, "FCR_FIFO_EN");
        do_wr(0, 8'h11, "THR_WR_11");
        do_wr(0, 8'h22, "THR_WR_22");
        do_wr(0, 8'h33, "THR_WR_33");
        do_wr(0, 8'h44, "THR_WR_44");
        // Wait for all 4 chars to loop back (~2400 cycles), then burst-read
        wait_n(2500);
        do_rd(0, "RBR_11");
        do_rd(0, "RBR_22");
        do_rd(0, "RBR_33");
        do_rd(0, "RBR_44");
        do_wr(2, 8'h00, "FCR_FIFO_DIS");

        // TEST 8: Interrupt (ERBI)
        $fdisplay(logf, "# TEST8: interrupt");
        do_wr(3, 8'h80, "LCR_DLAB_EN");
        do_wr(0, 2, "DLL_2"); do_wr(1, 0, "DLM_0");
        do_wr(3, 8'h03, "LCR_8N1"); do_wr(4, 8'h10, "MCR_LOOP");
        do_wr(1, 8'h01, "IER_ERBI_EN");
        do_wr(0, 8'hA5, "THR_WR_A5");
        // Wait for INT to go high
        wait_n(700);
        if (INT) log_ev("INT_STATE", 0, 1, "INT_HIGH");
        else     log_ev("INT_STATE", 0, 0, "INT_LOW");
        do_rd(2, "IIR_RD");
        do_rd(0, "RBR_A5");
        // Wait for INT to clear
        wait_n(4);
        if (!INT) log_ev("INT_CLEAR", 0, 0, "INT_CLEARED");
        else      log_ev("INT_CLEAR", 0, 1, "INT_STILL_HIGH");
        do_wr(1, 8'h00, "IER_DIS");

        log_ev("SIM_DONE", 0, 0, "ALL_TESTS_COMPLETE");
        $fclose(logf);
        $finish;
    end

endmodule
