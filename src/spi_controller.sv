// CPOL = 0, CPHA = 0
module spi_controller #(
    parameter int MEMORY_SIZE_IN_BYTES = 64
) (
    output  logic mosi,
    input   logic miso,
    output  logic sclk,
    input   logic clk,
    input   logic rst_n,
    input   logic [7:0] data_in,
    output  logic [7:0] data_out,
    output  logic wr,
    input   logic op,
    input   logic start,
    output  logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] address,
    input   logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] size,
    output  logic done
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
logic next_sclk_en, sclk_en;
logic next_done, next_wr;

logic miso_registered;

assign sclk = clk & sclk_en;
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
        sclk_en <= 1'b0;
        shift_reg <= 0;
    end else begin
        cs           <= ns;

        byte_counter <= next_byte_counter;
        bit_counter  <= next_bit_counter;
        sclk_en      <= next_sclk_en;
        wr           <= next_wr;
        done         <= next_done;
        shift_reg <= next_shift_reg;
    end
end

always_ff @(posedge sclk or negedge rst_n) begin
    if (!rst_n) begin
        miso_registered    <= 1'b0;
    end else begin
        miso_registered    <= miso;
    end
end

// mosi update (on negedge for SPI standard timing)
always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n)
        mosi <= 1'b0;
    else if (cs == WRITE)
        mosi <= data_in[bit_counter];
    else if (cs == READ)
        mosi <= 1'b1;
    else
        mosi <= 1'b0;
end

// FSM Combinational logic
always_comb begin
    ns                = cs;

    next_sclk_en      = sclk_en;
    next_byte_counter = byte_counter;
    next_bit_counter  = bit_counter;
    next_wr           = 1'b0;
    next_done         = 1'b0;
    next_shift_reg = shift_reg;

    address = byte_counter;

    case (cs)
        IDLE: begin
            next_sclk_en = 1'b0;

            if (start) begin
                next_byte_counter = 0;
                next_bit_counter  = 3'd7;

                if (op == OP_READ) begin
                    ns = READ;
                end else begin
                    ns = WRITE;
                end
            end
        end

        READ: begin
            next_sclk_en = 1'b1;
            address = byte_counter - 1; // because write occurs after byte read

            if (sclk_en) begin
                next_shift_reg = {shift_reg[6:0], miso_registered};

                if (bit_counter == 0) begin
                    next_wr = 1'b1;
                    next_bit_counter = 3'd7;
                    next_byte_counter = byte_counter + 1;

                    if (byte_counter == size) begin
                        ns = IDLE;
                        next_done = 1'b1;
                        next_sclk_en = 1'b0;
                    end
                end else begin
                    next_bit_counter = bit_counter - 1;
                end
            end
        end

        WRITE: begin
            next_sclk_en = 1'b1;

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

        default: ns = IDLE;
    endcase
end

endmodule
