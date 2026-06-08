#!/usr/bin/env bash
# Compile and simulate apb_uart with iverilog.
# Run from anywhere: bash sim/run.sh
# Output: sim/sim.log, sim/sim.vvp
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
SIM="$ROOT/sim"

echo "=== Compiling ==="
iverilog -g2012 -Wall \
    "$RTL/slib_edge_detect.sv" \
    "$RTL/slib_input_sync.sv" \
    "$RTL/slib_clock_div.sv" \
    "$RTL/slib_counter.sv" \
    "$RTL/slib_input_filter.sv" \
    "$RTL/slib_mv_filter.sv" \
    "$RTL/slib_fifo.sv" \
    "$RTL/uart_baudgen.sv" \
    "$RTL/uart_interrupt.sv" \
    "$RTL/uart_transmitter.sv" \
    "$RTL/uart_receiver.sv" \
    "$RTL/apb_uart.sv" \
    "$TB/apb_uart_tb.sv" \
    -o "$SIM/sim.vvp"

echo "=== Running simulation ==="
cd "$SIM"
vvp sim.vvp

echo "=== Done — log: sim/sim.log ==="
