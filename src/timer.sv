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
`ifndef APB_BUS_SV
`include "apb_intf.sv"
`endif

module timer(
    output logic [1:0]      irq_o,
    apb_bus_t.slave         apb_bus
);

logic [31:0]    timer_regs_q[3];
logic [31:0]    timer_regs_n[3];

logic [31:0]    timer_incr;

logic [31:0]    PRDATA;
logic           PREADY;

assign apb_bus.PRDATA = PRDATA;
assign apb_bus.PREADY = PREADY;

always_comb
begin
    PREADY = 1'b0;
    PRDATA = 'b0;

    timer_regs_n = timer_regs_q;
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
    
    // APB slave
    if(apb_bus.PSEL && apb_bus.PENABLE) begin
        PREADY = 1'b1;
        if(apb_bus.PWRITE) // Write
            timer_regs_n[apb_bus.PADDR[3:2]] = apb_bus.PWDATA;
        else // Read
            PRDATA = timer_regs_q[apb_bus.PADDR[3:2]];
    end

end

always_ff @(posedge apb_bus.PCLK, negedge apb_bus.PRESETn)
begin
    if(!apb_bus.PRESETn) begin
        timer_regs_q[`TIMER] <= 'b0;
        timer_regs_q[`CFG] <= 'b0;
        timer_regs_q[`CMP] <= 'b0;
    end else begin
        timer_regs_q[`TIMER] <= timer_regs_n[`TIMER];
        timer_regs_q[`CFG] <= timer_regs_n[`CFG];
        timer_regs_q[`CMP] <= timer_regs_n[`CMP];
    end
end

endmodule