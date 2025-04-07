module spi_controller_tb;

    // Parameters
    localparam int MEM_SIZE = 10;
    localparam int CLK_PERIOD = 2;

    // DUT signals
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

    // Memories
    logic [7:0] mem_ro [MEM_SIZE] = '{'hAA, 1, 2, 3, 4, 5, 6, 7, 8, 9};
    logic [7:0] mem_wo [MEM_SIZE];

    always_ff @(posedge clk) begin
        if (wr)
            mem_wo[address] <= data_out;
    end

    assign data_in = mem_ro[address];

    // Instantiate DUT
    spi_controller #(
        .MEMORY_SIZE_IN_BYTES(MEM_SIZE)
    ) dut (
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

    // Clock generation
    always #(CLK_PERIOD / 2) clk = ~clk;


    // Test sequence
    initial begin
        $dumpfile("test.fst");
        $dumpvars(0, tb);

        clk = 0;
        rst_n = 0;
        start = 0;
        op = 0;
        miso = 1'b0;

        #10
        rst_n = 1;

        size = 3;
        op = 1;
        // Data in memory is present
        start = 1;

//        size = 0;
//        op = 0;
//        start = 1;
//
//        miso = 1;

        @(posedge clk);
        #(CLK_PERIOD);
        start = 0;

        #100;
        $finish;
    end

endmodule
