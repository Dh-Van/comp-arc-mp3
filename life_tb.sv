`timescale 10ns/10ns

// Test bench for life.sv. Loads patterns with known behavior and checks each
// result: block (still life), blinker (period 2), a blinker straddling the
// corner (wrap on both axes), and a glider that must move one cell diagonally
// every 4 generations, wrapping around the edges, and come back to where it
// started after 32.

module life_tb;

    logic clk = 0;
    logic load = 0;
    logic step = 0;
    logic [63:0] seed = 64'd0;
    logic busy;
    logic [63:0] cells;

    integer errors = 0;

    life dut (
        .clk    (clk),
        .load   (load),
        .seed   (seed),
        .step   (step),
        .busy   (busy),
        .cells  (cells)
    );

    always #4 clk = ~clk;

    // Board helpers: cell (r, c) is bit r*8 + c, with wraparound
    function automatic logic [63:0] put(input logic [63:0] b, input int r, input int c);
        b[((r + 8) % 8) * 8 + ((c + 8) % 8)] = 1'b1;
        return b;
    endfunction

    function automatic logic [63:0] shift_board(input logic [63:0] b, input int dr, input int dc);
        logic [63:0] s = 64'd0;
        for (int r = 0; r < 8; r++)
            for (int c = 0; c < 8; c++)
                if (b[r*8 + c]) s = put(s, r + dr, c + dc);
        return s;
    endfunction

    task automatic load_board(input logic [63:0] b);
        @(negedge clk);
        seed = b;
        load = 1'b1;
        @(negedge clk);
        load = 1'b0;
    endtask

    task automatic show(input logic [63:0] b);
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++)
                $write("%s", b[r*8 + c] ? "#" : ".");
            $write("\n");
        end
    endtask

    task automatic generation();
        @(negedge clk);
        step = 1'b1;
        @(negedge clk);
        step = 1'b0;
        wait (!busy);
        @(negedge clk);
    endtask

    task automatic expect_board(input string name, input logic [63:0] want);
        if (cells !== want) begin
            errors++;
            $display("FAIL %s: got %016h, want %016h", name, cells, want);
            $display("got:");  show(cells);
            $display("want:"); show(want);
        end
        else begin
            $display("pass %s", name);
        end
    endtask

    logic [63:0] block, blinker_h, blinker_v, corner_h, corner_v, glider;

    initial begin
        $dumpfile("build/life_tb.vcd");
        $dumpvars(0, life_tb);

        // Block: still life
        block = put(put(put(put(64'd0, 3, 3), 3, 4), 4, 3), 4, 4);
        load_board(block);
        generation();
        expect_board("block unchanged after 1 generation", block);

        // Blinker: horizontal <-> vertical
        blinker_h = put(put(put(64'd0, 4, 3), 4, 4), 4, 5);
        blinker_v = put(put(put(64'd0, 3, 4), 4, 4), 5, 4);
        load_board(blinker_h);
        generation();
        expect_board("blinker flips to vertical", blinker_v);
        generation();
        expect_board("blinker flips back to horizontal", blinker_h);

        // Blinker centered on (0,0): its cells and neighbors wrap on both axes
        corner_h = put(put(put(64'd0, 0, 7), 0, 0), 0, 1);
        corner_v = put(put(put(64'd0, 7, 0), 0, 0), 1, 0);
        load_board(corner_h);
        generation();
        expect_board("corner blinker flips across top/bottom edge", corner_v);
        generation();
        expect_board("corner blinker flips back across left/right edge", corner_h);

        // Glider moving down-right: one cell diagonally every 4 generations
        glider = put(put(put(put(put(64'd0, 0, 1), 1, 2), 2, 0), 2, 1), 2, 2);
        load_board(glider);
        for (int g = 1; g <= 32; g++) begin
            generation();
            if (g % 4 == 0)
                expect_board($sformatf("glider shifted (%0d,%0d) after %0d generations",
                                       g / 4, g / 4, g), shift_board(glider, g / 4, g / 4));
        end

        if (errors == 0)
            $display("ALL CHECKS PASSED");
        else
            $display("%0d CHECKS FAILED", errors);
        $finish;
    end

endmodule
