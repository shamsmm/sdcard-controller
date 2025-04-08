// byte oriented slave
module spi_slave #(
    parameter int COMMAND_SIZE = 6,
    parameter int MEMORY_SIZE_IN_BYTES = 64
) (
    input  logic mosi,
    output  logic miso,
    input  logic sclk,
    input   logic clk,
    input   logic rst_n,
    input   logic [7:0] data_in,
    output  logic [7:0] data_out,
    output  logic wr,
    output  logic [7:0] cmd [COMMAND_SIZE],
    input logic op,
    input   logic start,
    output  logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] address,
    input   logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] size,
    output  logic transfer,
    output  logic done
);

// FSM States
typedef enum logic [2:0] {
    IDLE  = 3'd0,
    COMMAND = 3'd1,
    WAIT = 3'd2,
    WRITE = 3'd3,
    READ  = 3'd4
} state_t;

state_t cs, ns;

localparam bit OP_READ  = 1'b0;
localparam bit OP_WRITE = 1'b1;

// Counters and internal registers
logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] byte_counter, next_byte_counter;
logic [2:0] bit_counter, next_bit_counter;

logic [7:0] next_cmd [COMMAND_SIZE];

logic [7:0] shift_reg, next_shift_reg;
logic next_done, next_transfer, next_wr;

logic mosi_registered;
assign data_out = shift_reg;

// FSM Sequential logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cs           <= IDLE;
        byte_counter <= 0;
        bit_counter  <= 3'd7;
        shift_reg    <= 8'b0;
        done    <= 1'b0;
        wr    <= 1'b0;
        cmd <= {0, 0, 0, 0, 0, 0};
        transfer <= 0;
    end else begin
        cs           <= ns;
        byte_counter <= next_byte_counter;
        bit_counter  <= next_bit_counter;
        wr           <= next_wr;
        done         <= next_done;
        shift_reg <= next_shift_reg;
        cmd <= next_cmd;
        transfer <= next_transfer;
    end
end

always_ff @(posedge sclk or negedge rst_n) begin
    if (!rst_n) begin
        mosi_registered    <= 1'b0;
    end else begin
        mosi_registered    <= mosi;
    end
end

// miso update (on negedge for SPI standard timing)
always_ff @(negedge sclk or negedge rst_n) begin
    if (!rst_n)
        miso <= 1'b0;
    else if (cs == WRITE | (cs == WAIT && op == OP_WRITE && start))
        miso <= data_in[bit_counter];
    else
        miso <= 1'b0;
end

// FSM Combinational logic
always_comb begin
    ns                = cs;

    next_byte_counter = byte_counter;
    next_bit_counter  = bit_counter;
    next_wr           = 1'b0;
    next_done         = 1'b0;
    next_transfer = 1'b0;
    next_shift_reg = shift_reg;
    next_cmd = cmd;

    if (wr)
            address = byte_counter - 1; // writing for previous byte
        else
            address  = byte_counter;

    case (cs)
        IDLE: begin
            if (sclk) begin
                next_byte_counter = 0;
                next_bit_counter  = 3'd6; // first bit is sampled rightnow

                next_shift_reg = {shift_reg[6:0], mosi_registered};
                ns = COMMAND;
            end
        end

        COMMAND: begin
            if (sclk) begin
                next_shift_reg = {shift_reg[6:0], mosi_registered};

                if (bit_counter == 0) begin
                    next_cmd[byte_counter[2:0]] = next_shift_reg;

                    next_bit_counter = 3'd7;
                    next_byte_counter = byte_counter + 1;

                    if (byte_counter == {COMMAND_SIZE - 1}[$clog2(MEMORY_SIZE_IN_BYTES)-1:0]) begin
                        ns = WAIT;
                        next_transfer = 1'b1;
                    end
                end else begin
                    next_bit_counter = bit_counter - 1;
                end
            end
        end

        WAIT: begin
            if (start) begin
                next_byte_counter = 0;
                next_bit_counter  = 3'd7;

                if (op == OP_READ) begin
                    ns = READ;
                end else begin
                    next_bit_counter  = 3'd6; // already shifting now
                    ns = WRITE;
                end
            end
        end

        READ: begin
            if (sclk) begin
                address = byte_counter - 1; // because write occurs after byte read
                next_shift_reg = {shift_reg[6:0], mosi_registered};

                if (bit_counter == 0) begin
                    next_wr = 1'b1;
                    next_bit_counter = 3'd7;
                    next_byte_counter = byte_counter + 1;

                    if (byte_counter == size) begin
                        ns = IDLE;
                        next_done = 1'b1;
                    end
                end else begin
                    next_bit_counter = bit_counter - 1;
                end
            end
        end

        WRITE: begin
            if (sclk) begin
                if (bit_counter == 0) begin
                    next_bit_counter = 3'd7;
                    next_byte_counter = byte_counter + 1;

                    if (byte_counter == size) begin
                        ns = IDLE;
                        next_done = 1'b1;
                    end
                end else begin
                    next_bit_counter = bit_counter - 1;
                end
            end
        end

        default: ns = IDLE;
    endcase
end


endmodule