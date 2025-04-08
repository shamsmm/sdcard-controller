module spi_controller_tb;

    // TB states
    typedef enum logic [1:0] {
        WRITE = 2'd1,
        READ  = 2'd2
    } state_t;

    state_t state;

    // Parameters
    localparam int MEM_SIZE = 10;

    // Expected

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
    logic mosi_exp;

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
    always #1 clk = ~clk;


    // Simple SPI slave model to echo back data (for test purposes)
    logic [23:0] slave_data;  // preload data for read
    int ptr = 24;

    always_comb begin
        miso = slave_data[ptr];
    end

    always_ff @(negedge sclk) begin
        if (dut.cs == 2'd2) begin
            ptr <= ptr - 1;
        end
    end

    // Test sequence
    initial begin
        $dumpfile("test.fst");
        $dumpvars(0, tb);

        clk = 0;
        rst_n = 0;
        start = 0;
        op = 0;
        slave_data = 24'b111100001100101000110000;

        #10
        rst_n = 1;

        // Write Test
        state = WRITE;

        size = 9;
        op = 1;

        #2 start = 1;
        #2 start = 0;

        wait(done);

        // Read Test
        state = READ;

        size = 2;
        op = 0;

        #2 start = 1;
        #2 start = 0;

        #1000;

        $finish;
    end

endmodule
