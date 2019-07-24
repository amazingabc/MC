`timescale 1ns / 1ps

module ddr_ctrl(
    input                       clk                     ,
    input                       rst                     ,
    input                       init_calib_complete     ,//ddr3初始化信号,calibration is finished
    input       [63:0]          app_rd_data             ,//This active-High output indicates that app_rd_data[] is valid
    input                       app_rd_data_end         ,//This active-High output indicates that the current clock cycle is the last cycle of output data on app_rd_data
    input                       app_rd_data_valid       , 
    input                       app_rdy                 ,//UI is ready to accept commands
    input                       app_wdf_rdy             ,// FIFO is ready to receive data
     
    output  wire[31:0]          app_addr                ,     
    output  reg [2:0]           app_cmd                 ,//read :001 write:000
    output  reg                 app_en                  ,//操作地址app_addr的使能，只有它拉高的时候，对应的app_addr才是有效的
    output  reg [63:0]          app_wdf_data            , //data for write commands
    output  wire[31:0]          app_wdf_mask            , 
    output  wire                app_wdf_end             ,
    output  wire                app_wdf_wren            ,       
    output  reg                 ddrdata_test_err        
  );


    reg         [3:0]           test_state              ;
    reg         [15:0]          send_cnt                ;
    reg         [31:0]          write_addr              ;
    reg         [31:0]          read_addr               ;
    reg         [63:0]          data_buff               ;
    
    assign  app_wdf_wren        = 	app_en & app_wdf_rdy & app_rdy & (app_cmd == 3'd0);
    assign  app_wdf_end         = 	app_wdf_wren;
    
    assign  app_addr            = 	(app_cmd == 3'd0) ? write_addr : read_addr;

    assign 	app_wdf_mask 		= 	32'd0;



    always@(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            test_state              <= 4'd0;
            send_cnt                <= 16'd0;
            write_addr              <= 32'd0;
            read_addr               <= 32'd0;
            app_cmd                 <= 3'd0;
            app_en                  <= 1'b0;
            app_wdf_data[63:0]      <=0;
//            app_wdf_data[9:0]        <= 10'b1111111111;
        end
        else
        begin
            case (test_state)
            4'd0 :                                          
            begin
                app_cmd             <= 3'd0;
                app_en              <= 1'b0;
                app_wdf_data[63:0]        <=0;
//                app_wdf_data[9:0]        <= 10'b1111111111;
                send_cnt            <= 16'd0;
                write_addr          <= 32'd0;
                read_addr           <= 32'd0;
                if(init_calib_complete)
                    test_state      <= 4'd1;
                else
                    test_state      <= 4'd0;
            end
            
            4'd1 :
            begin
                if(app_rdy & app_wdf_rdy)
                begin
                    app_cmd         <= 3'd0;
                    app_en          <= 1'b1;
                    send_cnt        <= send_cnt + 1'b1;

                    test_state      <= 4'd2;
                end
            end
            
            4'd2 : 
            begin
                if(app_rdy & app_wdf_rdy)
                begin
                    if(send_cnt == 16'd199)                
                    begin
                         app_wdf_data[63:0]        <=0;
//                         app_wdf_data[9:0]        <= 10'b1111111111;
                        write_addr      <=  32'd0;
                        send_cnt        <= 16'd0;
                        test_state      <= 4'd3;
                        app_en          <= 1'b0;
                    end
                    else
                    begin
                        send_cnt        <= send_cnt + 1'b1;
                        app_cmd         <= 3'd0;
                        app_en          <= 1'b1;
                        write_addr      <= write_addr + 29'd8;
                        app_wdf_data    <= app_wdf_data + 64'd1;
                    end
                end
            end
            
            4'd3 : 
            begin
                if(app_rdy & app_wdf_rdy)
                begin
                    app_cmd         <= 3'd1;                      
                    app_en          <= 1'b1;
                    send_cnt        <= send_cnt + 1'b1;
                    test_state      <= 4'd4;
                end
            end
            
            4'd4 :
            begin
                if(app_rdy & app_wdf_rdy)
                begin
                    if(send_cnt == 16'd199)                
                    begin
                        read_addr       <= 32'd0;
                        send_cnt        <= 16'd0;
                        test_state      <= 4'd5;
                        app_en          <= 1'b0;
                    end
                    else 
                    begin
                        send_cnt        <= send_cnt + 1'b1;
                        app_cmd         <= 3'd1;
                        app_en          <= 1'b1;
                        read_addr       <= read_addr + 29'b0000_0000_0000_0000_0000_0010_0000;
                    end
                end
            end
            
            4'd5 :
            begin
                app_cmd             <= 3'd0;
                app_en              <= 1'b0;
                send_cnt            <= send_cnt + 1'b1;
                if(send_cnt == 16'd200)
                begin
                    send_cnt        <= 16'd0;
                    test_state      <= 4'd1;       
                end
            end
            
            default : test_state      <= 4'd0;
            
            endcase
        end
    end
    
    always@(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            data_buff               <= 64'd0;
            ddrdata_test_err        <= 1'b0;
        end
        else if (test_state == 4'd3) 
        begin
            data_buff               <= 64'd0;
        end
        else
        begin
            if(app_rd_data_valid)
            begin
              
                data_buff           <= data_buff + 64'd1;
                if(data_buff != app_rd_data)
                    ddrdata_test_err    <= 1'b1;
                 
            end
        end
    end

endmodule
