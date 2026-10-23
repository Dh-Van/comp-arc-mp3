// Reads an 8x8 seed from a $readmemh file: 8 lines of 2-digit hex, one per row
// (row 0 first). The MSB is column 0, so the binary reads left to right just
// like the board, e.g. 40 = .X...... is a cell in column 1.

module seed_rom #(
    parameter INIT_FILE = ""
)(
    output logic [63:0] cells       // cells[row*8 + col]
);

    logic [7:0] mem [0:7];

    initial if (INIT_FILE) begin
        $readmemh(INIT_FILE, mem);
    end

    generate
        for (genvar r = 0; r < 8; r++) begin : g_row
            for (genvar c = 0; c < 8; c++) begin : g_col
                assign cells[r*8 + c] = mem[r][7 - c];
            end
        end
    endgenerate

endmodule
