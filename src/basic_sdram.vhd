library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
    use work.util.all;

-- Simple SDRAM controller with no burst support, opens the row for every
-- request and closes it automatically.
entity basic_sdram is
    generic (
        clk_period             : time;
        required_power_on_wait : time    := 200 us;
        power_on_refresh_count : integer := 8;
        t_rp                   : time    := 20 ns;
        t_mrd                  : time    := 15 ns;
        t_rc                   : time    := 67.5 ns
    );
    port(
        clk  : in std_logic;
        arst : in std_logic;

        -- AXI-4 Lite signals
        -- Write address
        axi_awvalid : in std_logic;
        axi_awready : out std_logic;
        axi_awaddr  : in std_logic_vector(31 downto 0);
        axi_awprot  : in std_logic_vector(2 downto 0);
        -- Write data
        axi_wvalid : in std_logic;
        axi_wready : out std_logic;
        axi_wdata  : in std_logic_vector(15 downto 0);
        axi_wstrb  : in std_logic_vector(1 downto 0);
        -- Write response
        axi_bvalid : out std_logic;
        axi_bready : in std_logic;
        axi_bresp  : out std_logic_vector(1 downto 0);
        -- Read address
        axi_arvalid : in std_logic;
        axi_arready : out std_logic;
        axi_araddr  : in std_logic_vector(31 downto 0);
        axi_arprot  : in std_logic_vector(2 downto 0);
        -- Read data
        axi_rvalid : out std_logic;
        axi_rready : in std_logic;
        axi_rdata  : out std_logic_vector(15 downto 0);
        axi_rresp  : out std_logic_vector(1 downto 0);

        -- Signals to the chip
        cke   : out std_logic;
        cs_l  : out std_logic;
        cas_l : out std_logic;
        ras_l : out std_logic;
        we_l  : out std_logic;
        dqml  : out std_logic;
        dqmh  : out std_logic;
        ba    : out std_logic_vector(1 downto 0);
        a     : out std_logic_vector(12 downto 0);
        dq_o  : out std_logic_vector(15 downto 0);
        dq_i  : in  std_logic_vector(15 downto 0);
        dq_oe : out std_logic
    );
end basic_sdram;

architecture behave of basic_sdram is
    constant powerup_cycles : integer := period_to_cycles(
        required_power_on_wait, clk_period
    );
    constant powerup_cycles_width : integer := clog2(powerup_cycles);
    constant t_rp_cycles : integer := period_to_cycles(t_rp, clk_period);
    constant t_rc_cycles : integer := period_to_cycles(t_rc, clk_period);
    constant t_mrd_cycles : integer := period_to_cycles(t_mrd, clk_period);
    constant refresh_count_width : integer := clog2(power_on_refresh_count);

    type powerup_state_t is (
        state_powerup_wait,
        state_powerup_precharge,
        state_powerup_refresh,
        state_powerup_mode_register,
        state_powerup_ready
    );

    -- power-up cycles will always be the longest, by far. We can re-use this
    -- counter for all states that require waits.
    signal cycles_countdown : unsigned(powerup_cycles_width - 1 downto 0);
    signal powerup_state    : powerup_state_t;
    signal powerup_refresh_count : unsigned(refresh_count_width - 1 downto 0);

    procedure send_command(
        constant command   : in sdram_command_t;
        signal cs_l_inner  : out std_logic;
        signal cas_l_inner : out std_logic;
        signal ras_l_inner : out std_logic;
        signal we_l_inner  : out std_logic
    ) is
    begin
        case(command) is
            when sdram_nop =>
                cs_l_inner  <= '0';
                ras_l_inner <= '1';
                cas_l_inner <= '1';
                we_l_inner  <= '1';
            when sdram_precharge =>
                cs_l_inner  <= '0';
                ras_l_inner <= '0';
                cas_l_inner <= '1';
                we_l_inner  <= '0';
            when sdram_refresh =>
                cs_l_inner  <= '0';
                ras_l_inner <= '0';
                cas_l_inner <= '0';
                we_l_inner  <= '1';
            when sdram_load_mode_reg =>
                cs_l_inner  <= '0';
                ras_l_inner <= '0';
                cas_l_inner <= '0';
                we_l_inner  <= '0';
            when others =>
                assert false report "Unimplemented command" severity failure;
        end case;
    end;
begin

    cke   <= '1';

    commands: process(clk, arst) is
    begin
        if (arst = '0') then
            cycles_countdown <= to_unsigned(powerup_cycles, powerup_cycles_width);
            send_command(sdram_nop, cs_l, cas_l, ras_l, we_l);
            powerup_state <= state_powerup_wait;
        elsif rising_edge(clk) then
            if cycles_countdown /= 0 then
                cycles_countdown <= cycles_countdown - 1;
                send_command(sdram_nop, cs_l, cas_l, ras_l, we_l);
            else
                -- Finished waiting
                case(powerup_state) is
                    when state_powerup_wait =>
                        a(10) <= '1';
                        send_command(sdram_precharge, cs_l, cas_l, ras_l, we_l);
                        powerup_state <= state_powerup_precharge;
                        cycles_countdown <= to_unsigned(t_rp_cycles, powerup_cycles_width);
                    when state_powerup_precharge =>
                        send_command(sdram_refresh, cs_l, cas_l, ras_l, we_l);
                        powerup_state <= state_powerup_refresh;
                        cycles_countdown <= to_unsigned(t_rc_cycles, powerup_cycles_width);
                        powerup_refresh_count <= to_unsigned(power_on_refresh_count-1, refresh_count_width);
                    when state_powerup_refresh =>
                        if powerup_refresh_count = 0 then
                            powerup_state <= state_powerup_mode_register;
                            -- TODO Send mode register command
                        else
                            powerup_refresh_count <= powerup_refresh_count - 1;
                            send_command(sdram_refresh, cs_l, cas_l, ras_l, we_l);
                            cycles_countdown <= to_unsigned(t_rc_cycles, powerup_cycles_width);
                        end if;
                    when state_powerup_mode_register =>
                        -- TODO
                        ba <= "00";
                        a <= "0000000100000";
                        send_command(sdram_load_mode_reg, cs_l, cas_l, ras_l, we_l);
                        cycles_countdown <= to_unsigned(t_mrd_cycles, powerup_cycles_width);
                        powerup_state <= state_powerup_ready;
                    when state_powerup_ready =>
                        -- Do nothing
                end case;
            end if;
        end if;
    end process commands;

end behave;
