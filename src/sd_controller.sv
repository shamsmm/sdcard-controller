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
    SPISTART = 3'd1,
    WAITWRITE = 3'd2,
    SPIREAD = 3'd3,
    WAITREAD = 3'd4,
    WAIT1 = 3'd5
} state_t;

state_t cs, ns, wait_rs, next_wait_rs, transfer_rs, next_transfer_rs;

logic next_spi_op, next_spi_start, next_spi_ss, next_done;
logic [$clog2(MEMORY_SIZE_IN_BYTES)-1:0] next_spi_size;

logic [7:0] response, next_response;

assign spi_data_in = command_buffer[spi_address];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cs           <= IDLE;
        wait_rs           <= IDLE;
        transfer_rs           <= IDLE;
        spi_size    <= 0;
        spi_op <= 0;
        spi_start <= 0;
        spi_ss <= 1;
        done <= 0;
    end else begin
        cs           <= ns;
        wait_rs           <= next_wait_rs;
        transfer_rs           <= next_transfer_rs;
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
    next_wait_rs = wait_rs;
    next_transfer_rs = transfer_rs;
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
                next_spi_size = 5; // 0 corresponds to minimal a 1-byte transfer
                next_spi_op = 1;
                next_spi_ss = 0;
                ns = SPISTART;
                next_transfer_rs = WAITWRITE;
            end
        end

        SPISTART: begin
            next_spi_start = 1'b1;
            ns = WAIT1;
            next_wait_rs = transfer_rs;
        end

        WAIT1: begin
            ns = wait_rs;
        end

        WAITWRITE: begin
            next_spi_start = 0;
            if (spi_done) begin
                ns = SPIREAD;
                next_response = spi_data_out;
            end
        end

        SPIREAD: begin
            next_spi_size = nresponse;
            next_spi_op = 0;
            ns = SPISTART;
            next_transfer_rs = WAITREAD;
        end

        WAITREAD: begin
            next_spi_start = 0;
            if (spi_done) begin
                ns = IDLE;
                next_done = 1'b1;
            end
        end

        default: ns = IDLE;
    endcase
end

endmodule