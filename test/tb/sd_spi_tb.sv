/* verilator lint_off WIDTHTRUNC */

module sd_spi_tb;

    // Parameters
    localparam int MEM_SIZE = 10;
    localparam int CLK_PERIOD = 2;

    // SPI signals
    logic mosi, miso, sclk;
    logic clk, rst_n;
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

    // Memories
    logic [7:0] mem_ro [MEM_SIZE];
    logic [7:0] mem_wo [MEM_SIZE];

    // Connect memory interface
    //    assign data_in = mem_ro[address];

    always_ff @(posedge clk) begin
        if (wr)
            mem_wo[address] <= data_out;
    end

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
        .cmd(6'h0A),
        .arg(32'hDEADBEEF),
        .crc(7'h4A),
        .nresponse(2),
        .start(sd_start),
        .clk(clk),
        .rst_n(rst_n)
    );

    logic sd_start;

    // Simple SPI slave model to echo back data (for test purposes)
    logic [23:0] slave_data;

    always_ff @(negedge clk) begin
        if (spi_op == 1'b0 && sd_inst.cs == 4) begin  // read
            miso <= slave_data[23];
            slave_data <= slave_data << 1;
        end
    end

    // Clock generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Test sequence
    initial begin
        $dumpfile("test.fst");
        $dumpvars(0, sd_spi_tb);

        clk = 0;
        rst_n = 0;
        spi_start = 0;
        sd_start = 0;
        miso = 1'b0;
        slave_data = 24'hAABBCC;

        #10 rst_n = 1;

        #20 sd_start = 1;
        #2  sd_start = 0;

        wait (sd_done);
        #50;

        $display("Data received in memory:");
        for (int i = 0; i < MEM_SIZE; i++) begin
            $display("mem_wo[%0d] = 0x%02X", i, mem_wo[i]);
        end

        #100;
        $finish;
    end

endmodule
