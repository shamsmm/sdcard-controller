module sd_init_controller (
    output logic [45:40] cmd,
    output logic [39:8]  arg,
    output logic [7:1]   crc,
    output logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] nresponse,
    input sd_done,
    output sd_start,
    output done,
    output success,
    input start,
    input clk,
    input rst_n
);


endmodule