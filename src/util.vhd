library ieee;
   use ieee.std_logic_1164.all;
   use ieee.math_real.all;

package util is
    function period_to_cycles(period: time; clk_period: time)
        return integer;
    function clog2(n: integer)
        return integer;

    type sdram_command_t is (
        sdram_nop,
        sdram_active,
        sdram_read,
        sdram_write,
        sdram_burst_terminate,
        sdram_precharge,
        sdram_refresh,
        sdram_load_mode_reg
    );

    type axi4l_initiator_signals_t is record
        awvalid : std_logic;
        awaddr  : std_logic_vector(31 downto 0);
        awprot  : std_logic_vector(2 downto 0);
        wvalid  : std_logic;
        wdata   : std_logic_vector(15 downto 0);
        wstrb   : std_logic_vector(1 downto 0);
        bready  : std_logic;
        arvalid : std_logic;
        araddr  : std_logic_vector(31 downto 0);
        arprot  : std_logic_vector(2 downto 0);
        rready  : std_logic;
    end record axi4l_initiator_signals_t;

    type axi4l_target_signals_t is record
        awready : std_logic;
        wready  : std_logic;
        bvalid  : std_logic;
        bresp   : std_logic_vector(1 downto 0);
        arready : std_logic;
        rvalid  : std_logic;
        rdata   : std_logic_vector(15 downto 0);
        rresp   : std_logic_vector(1 downto 0);
    end record axi4l_target_signals_t;
end package util;

package body util is
    function period_to_cycles(period: time; clk_period: time)
        return integer is
    begin
        return integer(ceil(real(period / 1 ps) / real(clk_period / 1 ps)));
    end function period_to_cycles;

    function clog2(n: integer)
        return integer is
    begin
        return integer(ceil(log2(real(n))));
    end function clog2;
end package body util;
