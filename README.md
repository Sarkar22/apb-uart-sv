# APB UART 16750 — SystemVerilog

A fully synthesisable SystemVerilog implementation of a UART 16750-compatible core with an APB3 slave interface.

## Features

- APB3 (AMBA 2) slave interface — 32-bit data, 3-bit address
- Programmable baud rate via 16-bit divisor (DLL/DLM)
- Word lengths: 5, 6, 7, or 8 bits
- Parity: none, even, odd, stick-0, stick-1
- 1 or 2 stop bits (1.5 for 5-bit words)
- 16-byte TX and RX FIFOs (16550/16750 compatible)
- Interrupt output: RDA, THRE, RLS, MS
- Modem control: CTS, DSR, DCD, RI inputs; RTS, DTR outputs
- Loopback mode (MCR[4])
- Break control

## Module Hierarchy

```
apb_uart              — top-level APB slave
├── uart_baudgen      — 16-bit baud rate counter
├── slib_clock_div    — 16x → 2x clock divider
├── slib_fifo (×2)   — TX / RX 16-byte FIFOs
├── uart_transmitter  — TX bit-level FSM
├── uart_receiver     — RX bit-level FSM (majority-vote filter)
│   ├── slib_counter  — baud-rate counter
│   ├── slib_mv_filter
│   └── slib_input_filter
├── uart_interrupt    — IIR / IER logic
├── slib_edge_detect  — rising/falling edge pulses
└── slib_input_sync   — 2-stage input synchroniser
```

## Simulation (iverilog)

Requires [Icarus Verilog](https://github.com/steveicarus/iverilog) ≥ 10.3.

```bash
bash sim/run.sh
# log written to sim/sim.log
```

The testbench exercises 8 scenarios in loopback mode (MCR[4]=1):

| # | Test |
|---|------|
| 1 | Reset — LSR = 0x60 (THRE \| TEMT) |
| 2 | SCR scratch register read/write |
| 3 | Baud-rate divisor read-back |
| 4 | 8N1 loopback — 0x55, 0xAA, 0x00, 0xFF |
| 5 | Word lengths 5 / 6 / 7 / 8 bit |
| 6 | Parity — even, odd, stick-0, stick-1 |
| 7 | FIFO mode — 4-byte burst TX → RX |
| 8 | ERBI interrupt — assert / read IIR / clear |

## Register Map

| Addr | DLAB | Name | Description |
|------|------|------|-------------|
| 0 | 0 | RBR / THR | Receive / Transmit holding register |
| 0 | 1 | DLL | Baud divisor LSB |
| 1 | 0 | IER | Interrupt enable |
| 1 | 1 | DLM | Baud divisor MSB |
| 2 | — | IIR / FCR | Interrupt ID / FIFO control |
| 3 | — | LCR | Line control (DLAB, word length, parity, stop bits) |
| 4 | — | MCR | Modem control |
| 5 | — | LSR | Line status |
| 6 | — | MSR | Modem status |
| 7 | — | SCR | Scratch |

## License

MIT
