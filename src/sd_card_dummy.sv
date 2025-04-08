module sd_card_dummy(
    input  logic mosi,
    output  logic miso,
    input  logic sclk,
    input   logic clk,
    input   logic rst_n
);

localparam int MEMORY_SIZE_IN_BYTES = 10;
localparam int COMMAND_SIZE = 6; // SDIO command size is 6 bytes
localparam logic [7:0] RESET_CMD = 8'hFF;  // Define reset command value

// Signals for spi_slave instantiation
logic [7:0] data_in;
logic [7:0] data_out;
logic wr;
logic [7:0] cmd [COMMAND_SIZE];
logic op;
logic start;
logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] address;
logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] size;
logic transfer;
logic done;

// Instantiate spi_slave
spi_slave #(
    .COMMAND_SIZE(COMMAND_SIZE),
    .MEMORY_SIZE_IN_BYTES(MEMORY_SIZE_IN_BYTES)
) spi_slave_inst (
    .mosi(mosi),
    .miso(miso),
    .sclk(sclk),
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_in),
    .data_out(data_out),
    .wr(wr),
    .cmd(cmd),
    .op(op),
    .start(start),
    .address(address),
    .size(size),
    .transfer(transfer),
    .done(done)
);

logic [7:0] command_buffer [6];
logic [7:0] response_buffer;

always_comb begin
    start = transfer;
    size = 0;
    op = 1;
    data_in = {cmd[5], cmd[4], cmd[3], cmd[2], cmd[1], cmd[0]} == 'h400000000095 ? 8'h01 : 8'hFF;
end

endmodule