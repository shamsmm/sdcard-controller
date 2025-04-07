# SPI Controller

## Description
- Byte-Oriented half-duplex master SPI controller
- Slave select is left for higher layers
- Reading and writing to external memory (wrap in a register pseudo-memory if needed)

## Ports
- `output mosi` SPI
- `input miso` SPI
- `output clk_out` SPI clock
- `input clk` module clock
- `inout data` 8-bit data bus
- `input op`
  - 0: read
  - 1: write
- `input start` initiate transfer
- `output address` n-bit address bus 0-indexed (read or write)
- `input size` number of bytes in next transfer (read or write)
- `output done` = 1 when in `Idle` sate, 0 otherwise

## FSM
```plantuml
@startuml

hide empty description

[*] --> Idle
Idle --> Transmitting : start and op = write
Idle --> Receiving: start and op = read
Transmitting --> Idle : done
Receiving --> Idle : done

note right of Transmitting
size = number of bytes to read and transmit
address = what address to read from
data = data bus
mosi = serialized data latched on negedge clk
endnote

note right of Receiving
size = number of bytes to recive and write
address = what address to write to
data = data bus
mosi = 1
miso = serialized data sampled on posedge clk
endnote



@enduml
```

# SDIO Controller

## Description

- SDIO controller using SPI bus
- Uses SPI controller
- Reading and writing to external memory
  - If you need reading SD card use at least 512 byte external memory
  - Need at least 1 byte more for internal use
- `sd_transfer(cmd, arg, crc, nresponse)`
  - `cmd` = a valid SD command
  - `arg` = argument
  - `crc` = CRC of the SD frame
  - `nresponse` = number of bytes to receive

## Ports

- `input cmd`
- `ipnut arg`
- `input crc`
- `input nresponse`
- `inout data` 8-bit data bus
- `output ss` SPI slave select
- `output response` 8-bit SD R1 response
- `output fail` = 1 if `response` contained a failure
- `output address` n-bit address bus 0-indexed (read or write)
- `input start` start SD transfer
- `output done` = 1 when in `Idle` sate, 0 otherwise

## FSM

```plantuml
@startuml

hide empty description

[*] -> Idle
Idle --> Transfer : start
Transfer --> Idle : done

note left of Transfer
Check fail to see if successfully finished
endnote



@enduml
```

# Task: Initialize SDIO

- Initialize SDIO device in SPI mode

## FSM

```plantuml
@startuml

1: slave deselect
2: spi_transfer(b'\xFF') for 16 times
3: sd_transfer(GO_IDLE_STATE, 0x0, 0x4A, 0) for 10 times
4: sd_transfer(SEND_IF_COND, 0x01AA, 0x43, 4)
5: sd_transfer(APP_CMD, 0, 0, 0) and sd_transfer(SD_SEND_OP_COND, 0x40000000, 0, 0) for 100 times

[*] --> 1
1 --> 2: next clk
2 --> 3: when finished
3 --> 4: when finished
4 --> 5: when finished
5 --> [*]: when finished

@enduml
```

# Example

- Simple example top module to initialize sdio and read 512-byte into memory

## FSM

```plantuml
@startuml

InitializeSDIO: Initialize SD card 
ExampleTransfer: Example reading SD card at block 0


[*] --> InitializeSDIO

InitializeSDIO --> ExampleTransfer : init_done
ExampleTransfer --> [*] : transfer_done


@enduml
```

