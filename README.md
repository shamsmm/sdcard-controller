# SD Card Controller written from scratch in SystemVerilog

## SD Card `CMD0` in action (first step in init process)

![cmd0-fpga.gif](docs/cmd0-fpga.gif)

LEDs on the FPGA show the response from SD card
- 0xFF is empty response
- 0x01 is idle card response (means card responded and ready for initialization)

## Repo Structure
- [SystemVerilog source files *(src)*](src)
- [Reference and scratch files in Python, Markdown *(ref)*](ref)
- [Test benches *(test/tb)*](test/tb)
- [Top module for a Gowin 9K FPGA *(fpga/gowin)*](fpga/gowin)

## Architecture

- A low level half-duplex byte-oriented master SPI controller
- An SDIO controller that drives an SDIO device in SPI mode, uses SPI controller
- *For future:* A full SD card initialization SystemVerilog module or task

## Testing

Currently only simple test benches, uses

- Low level half-duplex byte-oriented, command-oriented SPI slave controller
- A simple *dummy* SD card using slave controller to use inside test benches