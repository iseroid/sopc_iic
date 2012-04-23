module iic_core(
    input          clk,
    input          rst,

    input  [  3:0] address,
    input          chipselect,
    input          write,
    input  [ 31:0] writedata,
    input          read,
    output [ 31:0] readdata,

    output scl_out,
    input  scl_in,
    output sda_out,
    input  sda_in
);

    reg          scl_in_r;
    reg          sda_in_r;

    reg          a_wr_r;
    reg  [  9:0] a_wr_data_r;
    reg  [ 31:0] a_rd_data_r;
    reg  [  7:0] scl_period_r;

    reg  [  9:0] scl_cnt_r;
    reg          scl_edge_r;

    reg  [  2:0] state_r;
    reg          running_r;
    reg  [  3:0] step_cnt_r;
    reg  [  2:0] bit_cnt_r;
    reg  [  7:0] iic_rdwr_data;
    reg          scl_r;
    reg          sda_r;
    reg          ack_r;

    wire         iic_write_w;
    wire         iic_start_w;
    wire         iic_stop_w;
    wire         iic_read_w;
    wire [  7:0] iic_wr_data_w;

    wire [  3:0] step_cnt_inc_w;

    parameter [  2:0]
        S_IDLE   = 3'b000,
        S_START  = 3'b001,
        S_WRITE  = 3'b010,
        S_READ   = 3'b011,
        S_STOP   = 3'b100;

    always @( posedge clk ) begin
        scl_in_r <= scl_in;
        sda_in_r <= sda_in;
    end


    always @( posedge clk or posedge rst ) begin
        if( rst ) begin
            a_rd_data_r <= 32'd0;
        end else if( chipselect && read ) begin
            if( address[0] == 1'b0 ) begin
                a_rd_data_r[31:11] <= 21'b000000000000000000000;
                a_rd_data_r[   10] <= ack_r;
                a_rd_data_r[    9] <= running_r;
                a_rd_data_r[    8] <= (state_r != S_IDLE);
                a_rd_data_r[ 7: 0] <= iic_rdwr_data;
            end else begin
                a_rd_data_r <= { 24'b000000000000000000000000, scl_period_r };
            end
        end
    end

    always @( posedge clk or posedge rst ) begin
        if( rst ) begin
            a_wr_r <= 1'b0;
            a_wr_data_r <= 10'b0000000000;
        end else if( a_wr_r ) begin
            a_wr_r <= 1'b0;
        end else begin
            a_wr_r <= (chipselect & write);
            a_wr_data_r <= writedata[9:0];
        end
    end

    always @( posedge clk or posedge rst ) begin
        if( rst ) begin
            scl_period_r <= 8'b11111111;
        end else if( a_wr_r && address[0] == 1'b1 ) begin
            scl_period_r <= a_wr_data_r[7:0];
        end
    end

    assign iic_write_w = (a_wr_r && address[0] == 1'b0 && a_wr_data_r[9:8] == 2'b00);
    assign iic_start_w = (a_wr_r && address[0] == 1'b0 && a_wr_data_r[9:8] == 2'b01);
    assign iic_stop_w  = (a_wr_r && address[0] == 1'b0 && a_wr_data_r[9:8] == 2'b10);
    assign iic_read_w  = (a_wr_r && address[0] == 1'b0 && a_wr_data_r[9:8] == 2'b11);

    assign iic_wr_data_w = a_wr_data_r[7:0];


    always @( posedge clk or posedge rst ) begin
        if( rst ) begin
            scl_cnt_r <= 10'b0000000000;
            scl_edge_r <= 1'b0;
        end else if( state_r == S_IDLE ) begin
            scl_cnt_r[9:2] <= scl_period_r;
            scl_edge_r <= 1'b0;
        end else if( scl_cnt_r[9:2] == scl_period_r ) begin
            scl_cnt_r <= 10'b0000000000;
            scl_edge_r <= 1'b1;
        end else begin
            scl_cnt_r <= scl_cnt_r + 10'b0000000001;
            scl_edge_r <= 1'b0;
        end
    end

    always @( posedge clk or posedge rst ) begin
        if( rst ) begin
            state_r <= S_IDLE;
            running_r = 1'b0;
        end
        else if( state_r == S_START ) begin
            if( scl_edge_r && step_cnt_r == 4'b0100 ) begin
                state_r <= S_IDLE;
            end
        end
        else if( state_r == S_WRITE ) begin
            if( scl_edge_r && step_cnt_r == 4'b0111 ) begin
                state_r <= S_IDLE;
            end
        end
        else if( state_r == S_READ ) begin
            if( scl_edge_r && step_cnt_r == 4'b0110 ) begin
                state_r <= S_IDLE;
            end
        end
        else if( state_r == S_STOP ) begin
            if( scl_edge_r && step_cnt_r == 4'b0100 ) begin
                state_r <= S_IDLE;
                running_r <= 1'b0;
            end
        end
        else begin // S_IDLE
            if( iic_start_w ) begin
                state_r <= S_START;
                running_r <= 1'b1;
            end else if( iic_write_w ) begin
                state_r <= S_WRITE;
            end else if( iic_read_w ) begin
                state_r <= S_READ;
            end else if( iic_stop_w ) begin
                state_r <= S_STOP;
            end
        end
    end

    assign step_cnt_inc_w = step_cnt_r + 4'b0001;

    always @( posedge clk or posedge rst ) begin
        if( rst ) begin
            step_cnt_r <= 4'b0000;
            bit_cnt_r  <= 3'b000;
            iic_rdwr_data <= 8'b00000000;
            scl_r <= 1'b1;
            sda_r <= 1'b1;
        end
        else if( state_r == S_IDLE ) begin
            step_cnt_r <= 4'b0000;
            bit_cnt_r  <= 3'b000;
        end
        else if( scl_edge_r ) begin
            if( state_r == S_START ) begin
                if( step_cnt_r == 4'b0000 ) begin
                    sda_r <= 1'b1;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0001 ) begin
                    if( sda_in_r ) begin
                        scl_r <= 1'b1;
                        step_cnt_r <= step_cnt_inc_w;
                    end
                end else if( step_cnt_r == 4'b0010 ) begin
                    if( scl_in_r ) begin
                        sda_r <= 1'b0;
                        step_cnt_r <= step_cnt_inc_w;
                    end
                end else if( step_cnt_r == 4'b0011 ) begin
                    scl_r <= 1'b0;
                    step_cnt_r <= step_cnt_inc_w;
                end
            end
            else if( state_r == S_WRITE ) begin
                if( step_cnt_r == 4'b0000 ) begin
                    scl_r <= 1'b0;
                    step_cnt_r <= step_cnt_inc_w;
                    iic_rdwr_data <= a_wr_data_r[7:0];
                end else if( step_cnt_r == 4'b0001 ) begin
                    sda_r <= iic_rdwr_data[7];
                    step_cnt_r <= step_cnt_inc_w;
                    iic_rdwr_data <= { iic_rdwr_data[6:0], 1'b0 };
                end else if( step_cnt_r == 4'b0010 ) begin
                    scl_r <= 1'b1;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0011 ) begin
                    if( scl_in_r ) begin
                        scl_r <= 1'b0;
                        if( bit_cnt_r == 3'b111 ) begin
                            step_cnt_r <= step_cnt_inc_w;
                        end else begin
                            step_cnt_r <= 4'b0001;
                        end
                        bit_cnt_r <= bit_cnt_r + 3'b001;
                    end
                end else if( step_cnt_r == 4'b0100 ) begin
                    sda_r <= 1'b1;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0101 ) begin
                    scl_r <= 1'b1;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0110 ) begin
                    if( scl_in_r ) begin
                        step_cnt_r <= step_cnt_inc_w;
                        scl_r <= 1'b0;
                    end
                end
            end
            else if( state_r == S_READ ) begin
                if( step_cnt_r == 4'b0000 ) begin
                    scl_r <= 1'b0;
                    sda_r <= 1'b1;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0001 ) begin
                    scl_r <= 1'b1;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0010 ) begin
                    if( scl_in_r ) begin
                        scl_r <= 1'b0;
                        step_cnt_r <= step_cnt_inc_w;
                        iic_rdwr_data <= { iic_rdwr_data[6:0], sda_in_r };
                        if( bit_cnt_r == 3'b111 ) begin
                            step_cnt_r <= step_cnt_inc_w;
                        end else begin
                            step_cnt_r <= 4'b0001;
                        end
                        bit_cnt_r <= bit_cnt_r + 3'b001;
                    end
                end else if( step_cnt_r == 4'b0011 ) begin
                    sda_r <= ack_r;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0100 ) begin
                    scl_r <= 1'b1;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0101 ) begin
                    if( scl_in_r ) begin
                        scl_r <= 1'b0;
                        sda_r <= 1'b1;
                        step_cnt_r <= step_cnt_inc_w;
                    end
                end
            end
            else if( state_r == S_STOP ) begin
                if( step_cnt_r == 4'b0000 ) begin
                    scl_r <= 1'b0;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0001 ) begin
                    sda_r <= 1'b0;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0010 ) begin
                    scl_r <= 1'b1;
                    step_cnt_r <= step_cnt_inc_w;
                end else if( step_cnt_r == 4'b0011 ) begin
                    if( scl_in_r ) begin
                        sda_r <= 1'b1;
                        step_cnt_r <= step_cnt_inc_w;
                    end
                end
            end
        end
    end

    always @( posedge clk or posedge rst ) begin
        if( rst ) begin
            ack_r <= 1'b0;
        end else if( state_r == S_WRITE && scl_edge_r && step_cnt_r == 4'b0110 ) begin
            ack_r <= sda_in_r;
        end else if( state_r == S_IDLE && iic_read_w ) begin
            ack_r <= a_wr_data_r[0];
        end
    end


    assign readdata = a_rd_data_r;

    assign scl_out = scl_r;
    assign sda_out = sda_r;

endmodule

