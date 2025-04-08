module sd_controller #(
    parameter int MEMORY_SIZE_IN_BYTES = 64
)  (
    output logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] spi_size,
    output logic spi_op,
    output logic [7:0] spi_data_in,
    input logic [$clog2(6)-1:0] spi_address,
    input logic [7:0] spi_data_out,
    output logic spi_start,
    output logic spi_ss,
    input logic spi_done,
    output logic done,
    input logic [45:40] cmd,
    input logic [39:8]  arg,
    input logic [7:1]   crc,
    input logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] nresponse,
    input start,
    input clk,
    input rst_n
);

localparam int CMD_SIZE = 6;

logic [7:0] command_buffer [6];

// FSM States
typedef enum logic [2:0] {
    IDLE  = 3'd0,
    SPIWRITE = 3'd1,
    SPISTART = 3'd2,
    WAIT = 3'd3,
    WRITEDONE = 3'd4,
    SPIREAD = 3'd5,
    READDONE = 3'd6
} state_t;

state_t cs, ns, rs, next_rs;

logic next_spi_op, next_spi_start, next_spi_ss, next_done;
logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] next_spi_size;

logic [7:0] response, next_response;

assign spi_data_in = command_buffer[spi_address];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cs           <= IDLE;
        rs          <= IDLE;
        spi_size    <= 0;
        spi_op <= 0;
        spi_start <= 0;
        spi_ss <= 1;
        done <= 0;
    end else begin
        cs           <= ns;
        rs           <= next_rs;
        spi_size    <= next_spi_size;
        spi_op <= next_spi_op;
        spi_start <= next_spi_start;
        spi_ss <= next_spi_ss;
        done         <= next_done;
        response <= next_response;
    end
end

always_comb begin
    ns = cs;
    next_rs = rs;
    next_spi_size = spi_size;
    next_spi_op = spi_op;
    next_spi_start = spi_start;
    next_spi_ss = spi_ss;
    next_done = 0;
    next_response = response;

    command_buffer[0] = {2'b01, cmd};
    command_buffer[1] = arg[39:32];
    command_buffer[2] = arg[31:24];
    command_buffer[3] = arg[23:16];
    command_buffer[4] = arg[15:8];
    command_buffer[5] = {crc, 1'b1};

    case(cs)
        IDLE: begin
            next_spi_ss = 1;

            if (start) begin
                ns = SPIWRITE;
            end
        end

        SPIWRITE: begin
            next_spi_size = {CMD_SIZE - 1}[$clog2(MEMORY_SIZE_IN_BYTES)-1:0]; // 0 corresponds to minimal a 1-byte transfer
            next_spi_op = 1;
            next_spi_ss = 0;
            ns = SPISTART;
            next_rs = WRITEDONE;
        end

        SPISTART: begin
            next_spi_start = 1'b1;
            ns = WAIT;
        end

        WAIT: begin
            next_spi_start = 0;
            if (spi_done) begin
                ns = rs;
            end
        end

        WRITEDONE: begin
            next_response = spi_data_out;
            ns = SPIREAD;
        end

        SPIREAD: begin
            next_spi_size = nresponse;
            next_spi_op = 0;
            ns = SPISTART;
            next_rs = READDONE;
        end

        READDONE: begin
            next_done = 1'b1;
            ns = IDLE;
        end

        default: ns = IDLE;
    endcase
end

endmodule