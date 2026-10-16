# UART Controller with FIFO and Error Detection

A Verilog HDL project implementing UART serial communication with FIFO buffering and framing-error detection.

### Features
- UART transmitter and receiver
- 8-bit serial data
- 4-byte FIFO buffer
- FIFO full/empty flags
- Framing-error detection

### Architecture
`UART RX → FIFO Buffer → Data Output`

### Simulation Results
Verified using Icarus Verilog on EDA Playground:
- UART-to-FIFO integration
- FIFO byte ordering and capacity
- Invalid stop-bit detection

### Tools
Verilog HDL · Icarus Verilog · EDA Playground · EPWave

### Simulation Waveform
![UART Simulation Waveform](screenshots/Screenshot%202026-10-16%20at%208.33.59%20PM.png)
