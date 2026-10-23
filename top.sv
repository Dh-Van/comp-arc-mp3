// MP3: three independent Games of Life on the red, green, and blue planes of
// the 8x8 WS2812B matrix. Where games overlap the colors mix. SW reloads seeds.

module top #(
    parameter FRAMES_PER_GEN = 8,           // ~32 fps / 8 = ~4 generations per second
    parameter [7:0] BRIGHTNESS = 8'h20      // channel value for a living cell
)(
    input logic     clk,
    input logic     SW,                     // active low: reload the seeds
    input logic     BOOT,
    output logic    _48b,
    output logic    _45a
);

    logic [63:0] red_seed, green_seed, blue_seed;
    logic [63:0] red_cells, green_cells, blue_cells;
    logic red_busy, green_busy, blue_busy;

    logic [5:0] pixel;
    logic [4:0] frame;
    logic idle;

    logic [23:0] shift_reg = 24'd0;
    logic load_sreg;
    logic transmit_pixel;
    logic shift;
    logic ws2812b_out;

    // Seed load on power-up and while SW is held (synchronized, active low)
    logic started = 1'b0;
    logic [1:0] sw_sync = 2'b11;
    logic load;

    always_ff @(posedge clk) begin
        started <= 1'b1;
        sw_sync <= { sw_sync[0], SW };
    end

    assign load = !started || !sw_sync[1];

    // Advance all three games once every FRAMES_PER_GEN frames, at the start
    // of the idle gap so a frame never shows a mix of two generations
    logic idle_q = 1'b0;
    logic [7:0] frame_count = 8'd0;
    logic step;

    always_ff @(posedge clk) begin
        idle_q <= idle;
        step <= 1'b0;
        if (idle && !idle_q) begin
            if (frame_count == FRAMES_PER_GEN - 1) begin
                frame_count <= 8'd0;
                step <= 1'b1;
            end
            else begin
                frame_count <= frame_count + 1;
            end
        end
    end

    seed_rom #(.INIT_FILE ("seeds/red.txt"))   u_red_seed   (.cells (red_seed));
    seed_rom #(.INIT_FILE ("seeds/green.txt")) u_green_seed (.cells (green_seed));
    seed_rom #(.INIT_FILE ("seeds/blue.txt"))  u_blue_seed  (.cells (blue_seed));

    life u_red (
        .clk    (clk),
        .load   (load),
        .seed   (red_seed),
        .step   (step),
        .busy   (red_busy),
        .cells  (red_cells)
    );

    life u_green (
        .clk    (clk),
        .load   (load),
        .seed   (green_seed),
        .step   (step),
        .busy   (green_busy),
        .cells  (green_cells)
    );

    life u_blue (
        .clk    (clk),
        .load   (load),
        .seed   (blue_seed),
        .step   (step),
        .busy   (blue_busy),
        .cells  (blue_cells)
    );

    // Instance the WS2812B output driver
    ws2812b u_ws2812b (
        .clk            (clk),
        .serial_in      (shift_reg[23]),
        .transmit       (transmit_pixel),
        .ws2812b_out    (ws2812b_out),
        .shift          (shift)
    );

    // Instance the controller (pixel is row*8 + col, row-major on the matrix)
    controller u_controller (
        .clk            (clk),
        .load_sreg      (load_sreg),
        .transmit_pixel (transmit_pixel),
        .pixel          (pixel),
        .frame          (frame),
        .idle           (idle)
    );

    // WS2812B takes green, red, blue, MSB first
    always_ff @(posedge clk) begin
        if (load_sreg) begin
            shift_reg <= {
                green_cells[pixel] ? BRIGHTNESS : 8'd0,
                red_cells[pixel]   ? BRIGHTNESS : 8'd0,
                blue_cells[pixel]  ? BRIGHTNESS : 8'd0
            };
        end
        else if (shift) begin
            shift_reg <= { shift_reg[22:0], 1'b0 };
        end
    end

    assign _48b = ws2812b_out;
    assign _45a = ~ws2812b_out;

endmodule
