// One Game of Life on an 8x8 torus.
//
// Cells are flattened as cells[row*8 + col]. Internally each row is a byte with
// bit c = column c. A generation is computed one row per clock: row r's next
// state depends only on rows r-1, r, r+1, and the 3-bit row index wraps on its
// own, so the vertical wrap is free. Columns wrap by rotating each row byte.
// New rows go into a second buffer, and the board is replaced all at once after
// the 8th row, so every row is computed from the same generation.

module life (
    input logic         clk,
    input logic         load,       // copy seed into the board (has priority)
    input logic [63:0]  seed,
    input logic         step,       // start computing the next generation
    output logic        busy,       // high for the 8 clocks of a generation
    output logic [63:0] cells
);

    logic [7:0] cur [0:7];
    logic [7:0] nxt [0:7];
    logic [2:0] row = 3'd0;
    logic [7:0] next_row;

    initial busy = 1'b0;

    // Next state of one row from the rows above, at, and below it
    function automatic logic [7:0] life_row(
        input logic [7:0] up,
        input logic [7:0] mid,
        input logic [7:0] dn
    );
        logic [7:0] up_l, up_r, mid_l, mid_r, dn_l, dn_r;
        logic [3:0] n;
        // *_l holds each cell's left neighbor (column c-1), *_r its right (c+1)
        up_l  = { up[6:0],  up[7] };    up_r  = { up[0],  up[7:1] };
        mid_l = { mid[6:0], mid[7] };   mid_r = { mid[0], mid[7:1] };
        dn_l  = { dn[6:0],  dn[7] };    dn_r  = { dn[0],  dn[7:1] };
        for (int c = 0; c < 8; c++) begin
            n = 4'(up_l[c]) + 4'(up[c]) + 4'(up_r[c])
              + 4'(mid_l[c])            + 4'(mid_r[c])
              + 4'(dn_l[c]) + 4'(dn[c]) + 4'(dn_r[c]);
            // Born with exactly 3 neighbors, survives with 2 or 3, else dies
            life_row[c] = (n == 4'd3) || (mid[c] && (n == 4'd2));
        end
    endfunction

    assign next_row = life_row(cur[row - 3'd1], cur[row], cur[row + 3'd1]);

    always_ff @(posedge clk) begin
        if (load) begin
            for (int r = 0; r < 8; r++)
                cur[r] <= seed[r*8 +: 8];
            busy <= 1'b0;
            row <= 3'd0;
        end
        else if (busy) begin
            nxt[row] <= next_row;
            row <= row + 3'd1;
            if (row == 3'd7) begin
                // Commit the generation; row 7 goes straight from next_row
                for (int r = 0; r < 7; r++)
                    cur[r] <= nxt[r];
                cur[7] <= next_row;
                busy <= 1'b0;
            end
        end
        else if (step) begin
            busy <= 1'b1;
            row <= 3'd0;
        end
    end

    generate
        for (genvar r = 0; r < 8; r++) begin : g_cells
            assign cells[r*8 +: 8] = cur[r];
        end
    endgenerate

endmodule
