module top (
    input logic hclk,
    input logic rst_n,
    output logic mosi,
    input logic miso,
    output logic sclk,
    output logic ss,
    output logic [5:0] led
);
    // Clock driver to bring 27MHz to 100KHz-400KHz
    logic clk8, clk64;

    Gowin_CLKDIV8 div1 (
        .clkout(clk8), //output clkout
        .hclkin(hclk), //input hclkin
        .resetn(rst_n) //input resetn
    );

    Gowin_CLKDIV8 div2 (
        .clkout(clk64), //output clkout
        .hclkin(clk8), //input hclkin
        .resetn(rst_n) //input resetn
    );

    Gowin_CLKDIV4 div3 (
        .clkout(clk), //output clkout
        .hclkin(clk64), //input hclkin
        .resetn(rst_n) //input resetn
    );

    localparam int MEM_SIZE = 16;

    logic sd_start;

    // SPI signals
    logic [7:0] data_in;
    logic [7:0] data_out;
    logic wr;
    logic op;
    logic start;
    logic [$clog2(MEM_SIZE)-1:0] address;
    logic [$clog2(MEM_SIZE)-1:0] size;
    logic done;

    // SD controller to SPI interface
    logic [$clog2(MEM_SIZE)-1:0] spi_size;
    logic spi_op;
    logic [7:0] spi_data_in;
    logic [$clog2(MEM_SIZE)-1:0] spi_address;
    logic [7:0] spi_data_out;
    logic spi_start;
    logic spi_ss;
    logic spi_done;
    logic sd_done;

    // Instantiate SPI controller
    spi_controller #(
        .MEMORY_SIZE_IN_BYTES(MEM_SIZE)
    ) spi_inst (
        .mosi(mosi),
        .miso(miso),
        .sclk(sclk),
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out),
        .wr(wr),
        .op(op),
        .start(start),
        .address(address),
        .size(size),
        .done(done)
    );

    // Connect SPI controller interface
    assign op     = spi_op;
    assign start  = spi_start;
    assign size   = spi_size;
    assign spi_data_out = data_out;
    assign spi_done = done;
    assign data_in = spi_data_in;
    assign ss = spi_ss;

    // Instantiate SD Controller
    sd_controller #(
        .MEMORY_SIZE_IN_BYTES(MEM_SIZE)
    ) sd_inst (
        .spi_size(spi_size),
        .spi_op(spi_op),
        .spi_data_in(spi_data_in),
        .spi_address(address),
        .spi_data_out(spi_data_out),
        .spi_start(spi_start),
        .spi_ss(spi_ss),
        .spi_done(spi_done),
        .done(sd_done),
        .cmd(6'h0),
        .arg(32'h0),
        .crc(7'h44),
        .nresponse(0),
        .start(sd_start),
        .clk(clk),
        .rst_n(rst_n)
    );

    logic [7:0] mem [MEM_SIZE];
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            mem <= '{MEM_SIZE {'b0}};
            led <= 255;
        end else begin
            if (wr) begin
                mem[address] <= data_out;
                led <= ~data_out; // leds are active low
            end
        end
    end

    logic [6:0] counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            sd_start <= 0;
        end else begin             
            counter <= counter + 1;

            case(counter)
                'd10: sd_start <= 1;
                'd15: sd_start <= 0;
            endcase
        end
    end

endmodule