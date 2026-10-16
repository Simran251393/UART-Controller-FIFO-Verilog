
module uart_tx #(
    parameter CLKS_PER_BIT = 4
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] data_in,
    output reg tx,
    output reg busy,
    output reg done
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] baud_count;
    reg [2:0] bit_index;
    reg [7:0] data_reg;

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            baud_count <= 0;
            bit_index  <= 0;
            data_reg   <= 0;
            tx         <= 1'b1;
            busy       <= 1'b0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    busy <= 1'b0;
                    baud_count <= 0;
                    bit_index <= 0;

                    if (start) begin
                        data_reg <= data_in;
                        state <= START;
                        busy <= 1'b1;
                        tx <= 1'b0;
                    end
                end

                START: begin
                    tx <= 1'b0;

                    if (baud_count == CLKS_PER_BIT - 1) begin
                        baud_count <= 0;
                        state <= DATA;
                        tx <= data_reg[0];
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                DATA: begin
                    tx <= data_reg[bit_index];

                    if (baud_count == CLKS_PER_BIT - 1) begin
                        baud_count <= 0;

                        if (bit_index == 7) begin
                            state <= STOP;
                            tx <= 1'b1;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                STOP: begin
                    tx <= 1'b1;

                    if (baud_count == CLKS_PER_BIT - 1) begin
                        baud_count <= 0;
                        state <= IDLE;
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    tx <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule

module uart_rx #(
    parameter CLKS_PER_BIT = 4
)(
    input wire clk,
    input wire rst,
    input wire rx,
    output reg [7:0] data_out,
    output reg valid,
    output reg frame_error
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] baud_count;
    reg [2:0] bit_index;
    reg [7:0] data_reg;

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            baud_count <= 0;
            bit_index  <= 0;
            data_reg   <= 0;
            data_out   <= 0;
            valid      <= 0;
            frame_error <= 0;
        end else begin
            valid <= 0;
            frame_error <= 0;

            case (state)
                IDLE: begin
                    baud_count <= 0;
                    bit_index <= 0;

                    if (rx == 1'b0)
                        state <= START;
                end

                START: begin
                    if (baud_count == (CLKS_PER_BIT/2)-1) begin
                        baud_count <= 0;

                        if (rx == 1'b0)
                            state <= DATA;
                        else
                            state <= IDLE;
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                DATA: begin
                    if (baud_count == CLKS_PER_BIT-1) begin
                        baud_count <= 0;
                        data_reg[bit_index] <= rx;

                        if (bit_index == 7) begin
                            bit_index <= 0;
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                STOP: begin
                    if (baud_count == CLKS_PER_BIT-1) begin
                        baud_count <= 0;
                        data_out <= data_reg;

                        if (rx == 1'b1)
                            valid <= 1'b1;
                        else
                            frame_error <= 1'b1;

                        state <= IDLE;
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    baud_count <= 0;
                end
            endcase
        end
    end

endmodule
module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 4
)(
    input wire clk,
    input wire rst,
    input wire wr_en,
    input wire rd_en,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    output wire full,
    output wire empty
);

    reg [DATA_WIDTH-1:0] memory [0:FIFO_DEPTH-1];

    integer write_ptr;
    integer read_ptr;
    integer count;

    assign full  = (count == FIFO_DEPTH);
    assign empty = (count == 0);

    always @(posedge clk) begin
        if (rst) begin
            write_ptr <= 0;
            read_ptr  <= 0;
            count     <= 0;
            data_out  <= 0;
        end else begin
            if (wr_en && !full) begin
                memory[write_ptr] <= data_in;
                write_ptr <= (write_ptr + 1) % FIFO_DEPTH;
            end

            if (rd_en && !empty) begin
                data_out <= memory[read_ptr];
                read_ptr <= (read_ptr + 1) % FIFO_DEPTH;
            end

            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: count <= count;
            endcase
        end
    end

endmodule

module uart_fifo_system #(
    parameter CLKS_PER_BIT = 4,
    parameter FIFO_DEPTH = 4
)(
    input wire clk,
    input wire rst,
    input wire rx,
    input wire rd_en,
    output wire [7:0] data_out,
    output wire fifo_full,
    output wire fifo_empty,
    output wire frame_error
);

    wire [7:0] rx_data;
    wire rx_valid;

    // UART receiver
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) receiver (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data_out(rx_data),
        .valid(rx_valid),
        .frame_error(frame_error)
    );

    // Store each valid received byte in the FIFO
    sync_fifo #(
        .DATA_WIDTH(8),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(rx_valid && !fifo_full),
        .rd_en(rd_en),
        .data_in(rx_data),
        .data_out(data_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );

endmodule


