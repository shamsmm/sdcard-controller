/* verilator lint_off TIMESCALEMOD */

// CPOL = 0, CPHA = 0
module spi_controller #(
    parameter int MEMORY_SIZE_IN_BYTES = 64
) (
    output logic mosi,
    input logic miso,
    output logic sclk,
    input logic clk,
    input logic rst_n,
    input logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic wr,
    input logic op,
    input logic start,
    output logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] address,
    input logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] size,
    output logic done
);

// FSM States
typedef enum logic [1:0] {
    IDLE  = 2'd0,
    WRITE = 2'd1,
    READ  = 2'd2
} state_t;

state_t cs, ns;

localparam bit OP_READ  = 1'b0;
localparam bit OP_WRITE = 1'b1;

// Counters and internal registers
logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] byte_counter, next_byte_counter;
logic [2:0] bit_counter, next_bit_counter;

logic [7:0] shift_reg, next_shift_reg;
logic next_mosi;
logic next_sclk_en, sclk_en;

assign sclk = clk & sclk_en;
assign mosi = next_mosi;
assign address = byte_counter;
assign data_out = shift_reg;

// FSM Sequential logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cs           <= IDLE;
        byte_counter <= 0;
        bit_counter  <= 3'd7;
        shift_reg    <= 8'b0;
    end else begin
        cs           <= ns;
        byte_counter <= next_byte_counter;
        bit_counter  <= next_bit_counter;
        shift_reg    <= next_shift_reg;
        sclk_en         <= next_sclk_en;
    end
end

// mosi update (on negedge for SPI standard timing)
always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n)
        next_mosi <= 1'b0;
    else if (cs == WRITE)
        next_mosi <= data_in[bit_counter];
    else if (cs == READ)
        next_mosi <= 1'b1;
    else
        next_mosi <= 1'b0;
end

// FSM Combinational logic
always_comb begin
    ns                = cs;
    next_sclk_en      = sclk_en;
    next_byte_counter = byte_counter;
    next_bit_counter  = bit_counter;
    next_shift_reg    = shift_reg;
    wr                = 1'b0;
    done              = 1'b0;

    case (cs)
        IDLE: begin
            next_sclk_en = 1'b0;

            if (start) begin
                next_byte_counter = 0;
                next_bit_counter  = 3'd7;
                next_shift_reg    = 8'b0;

                ns = (op == OP_READ) ? READ :
                     (op == OP_WRITE) ? WRITE : IDLE;
            end
        end

        READ: begin
            // Sample miso bit
            next_shift_reg = {shift_reg[6:0], miso};

            if (bit_counter == 0) begin
                wr = 1'b1;
                next_bit_counter = 3'd7;
                next_byte_counter = byte_counter + 1;

                if (byte_counter == size) begin
                    ns = IDLE;
                    done = 1'b1;
                end
            end else begin
                next_bit_counter = bit_counter - 1;
            end
        end

        WRITE: begin
            next_sclk_en = 1'b1;

            if (bit_counter == 0) begin
                next_bit_counter = 3'd7;
                next_byte_counter = byte_counter + 1;

                if (byte_counter == size) begin
                    ns = IDLE;
                    done = 1'b1;
                end
            end else begin
                next_bit_counter = bit_counter - 1;
            end
        end

        default: ns = IDLE;
    endcase
end

endmodule
