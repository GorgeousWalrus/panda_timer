// ------------------------ Disclaimer -----------------------
// No warranty of correctness, synthesizability or 
// functionality of this code is given.
// Use this code under your own risk.
// When using this code, copy this disclaimer at the top of 
// your file
//
// (c) Panda Cores 2020
//
// ------------------------------------------------------------
//
// Module name: timer
//
// Authors: Luca Hanel
// 
// Functionality: A timer
//
// TODO: 
//
// ------------------------------------------------------------

`include "timer_incl.sv"
`include "wb_intf.sv"

module timer(
    input logic             clk,
    input logic             rstn_i,
    output logic [1:0]      irq_o,
    wb_bus_t.slave          wb_bus
);

logic [31:0]    timer_regs_q[3];
logic [31:0]    timer_regs_n[3];

logic [31:0]    timer_incr;

always_comb
begin
    wb_bus.wb_ack = 1'b0;
    wb_bus.wb_err = 1'b0;
    timer_regs_n = timer_regs_q;
    // Timer
    timer_incr = 32'b0;
    irq_o = 'b0;

    // only operate if enabled
    if(timer_regs_q[`CFG][`ENABLE_BIT]) begin
        // timer increment
        timer_incr = 32'b1 << timer_regs_q[`CFG][`PRSC_START:`PRSC_END];
        timer_regs_n[`TIMER] = timer_regs_q[`TIMER] + timer_incr;

        // compare interrupt
        if(timer_regs_q[`TIMER] >= timer_regs_q[`CMP]) begin
            irq_o[0] = 1'b1;
            timer_regs_n[`TIMER] = 'b0;
        end

        // overflow interrupt
        if(timer_regs_q[`TIMER] > (timer_regs_q[`TIMER] + timer_incr))
            irq_o[1] = 1'b1;
    end
    
    // WB slave
    if(wb_bus.wb_cyc && wb_bus.wb_stb) begin
        wb_bus.wb_ack = 1'b1;
        if(wb_bus.wb_adr > 32'hc)
            // If the address is out of bounds, return error
            wb_bus.wb_err = 1'b1;
        else begin
            if(wb_bus.wb_we) begin
                // Writing
                if(wb_bus.wb_sel[0])
                    timer_regs_n[wb_bus.wb_adr[3:2]][7:0] = wb_bus.wb_dat_ms[7:0];
                if(wb_bus.wb_sel[1])
                    timer_regs_n[wb_bus.wb_adr[3:2]][15:8] = wb_bus.wb_dat_ms[15:8];
                if(wb_bus.wb_sel[2])
                    timer_regs_n[wb_bus.wb_adr[3:2]][23:16] = wb_bus.wb_dat_ms[23:16];
                if(wb_bus.wb_sel[3])
                    timer_regs_n[wb_bus.wb_adr[3:2]][31:24] = wb_bus.wb_dat_ms[31:24];
            end else begin
                // Reading (only supports full 32 bit reading)
                wb_bus.wb_dat_sm = timer_regs_q[wb_bus.wb_adr[3:2]];
            end
        end
    end
end

always_ff @(posedge clk, negedge rstn_i)
begin
    if(!rstn_i) begin
        timer_regs_q[`TIMER] <= 'b0;
        timer_regs_q[`CFG] <= 'b0;
        timer_regs_q[`CMP] <= 'b0;
    end else begin
        timer_regs_q[`TIMER] <= timer_regs_n[`TIMER];
        timer_regs_q[`CFG] <= timer_regs_n[`CFG];
        timer_regs_q[`CMP] <= timer_regs_n[`CMP];
        // timer_regs_q[`TIMER] <= timer_regs_q[`TIMER] + timer_incr;
    end
end

endmodule