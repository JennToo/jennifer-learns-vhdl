library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi.all;
use work.sdram.all;
use work.math.all;

-- Simple SDRAM controller with no burst support, opens the row for every
-- request and closes it automatically.
--
-- TODO: One way to make this generic across word widths may be to separate the
-- command generation logic from the data handling into separate components.
-- The AXI handler is already mostly separated. The biggest change would be
-- that the AXI handler (or maybe just a new split-out component) would handle
-- driving the DQ/DQM lines instead of the command state machine like it is
-- now.
entity basic_sdram is
    generic (
        clk_period              : time;
        required_power_on_wait  : time    := 200 us;
        total_powerup_refreshes : integer := 8;
        t_rp                    : time    := 20 ns;
        t_mrd                   : time    := 15 ns;
        t_rc                    : time    := 67.5 ns;
        t_rcd                   : time    := 20 ns;
        t_dpl                   : time    := 14 ns;
        t_ref                   : time    := 64 ms;
        periodic_refresh_count  : integer := 8192
    );
    port(
        clk  : in std_logic;
        arst : in std_logic;

        axi_initiator : in axi4l_initiator_signals_t;
        axi_target    : out axi4l_target_signals_t;

        -- Signals to the chip
        cke   : out std_logic;
        csn   : out std_logic;
        casn  : out std_logic;
        rasn  : out std_logic;
        wen   : out std_logic;
        dqm   : out std_logic_vector(1 downto 0);
        ba    : out std_logic_vector(1 downto 0);
        a     : out std_logic_vector(12 downto 0);
        dq_o  : out std_logic_vector(15 downto 0);
        dq_i  : in  std_logic_vector(15 downto 0);
        dq_oe : out std_logic
    );
end basic_sdram;

architecture behave of basic_sdram is
    constant powerup_cycles : integer := period_to_cycles(
        required_power_on_wait, clk_period, true
    );
    constant timer_width          : integer := clog2(powerup_cycles);
    constant t_rp_cycles          : integer := period_to_cycles(t_rp, clk_period, true);
    constant t_rc_cycles          : integer := period_to_cycles(t_rc, clk_period, true);
    constant t_mrd_cycles         : integer := period_to_cycles(t_mrd, clk_period, true);
    constant t_rcd_cycles         : integer := period_to_cycles(t_rcd, clk_period, true);
    constant t_dpl_cycles         : integer := period_to_cycles(t_dpl, clk_period, true);
    constant cas_latency          : integer := 2;
    constant refresh_count_width  : integer := clog2(total_powerup_refreshes);
    constant refresh_timer_cycles : integer := period_to_cycles(t_ref, clk_period, false) / periodic_refresh_count - t_rc_cycles;
    constant refresh_timer_width  : integer := clog2(refresh_timer_cycles);

    type state_t is (
        state_powerup_wait,
        state_powerup_precharge,
        state_powerup_refresh,
        state_powerup_mode_register,
        state_idle,
        state_activate,
        state_execute_read
    );

    -- power-up cycles will always be the longest, by far. We can re-use this
    -- counter for all states that require waits.
    signal transition_timer            : unsigned(timer_width - 1 downto 0);
    signal state                       : state_t;
    signal required_refreshes          : unsigned(refresh_count_width - 1 downto 0);
    signal refresh_timer               : unsigned(refresh_timer_width - 1 downto 0);
    signal command                     : sdram_command_t;
    signal read_address                : std_logic_vector(23 downto 0);
    signal write_address               : std_logic_vector(23 downto 0);
    signal write_data                  : std_logic_vector(15 downto 0);
    signal read_data                   : std_logic_vector(15 downto 0);
    signal write_strobe                : std_logic_vector(1 downto 0);
    signal read_address_stored         : std_logic;
    signal write_address_stored        : std_logic;
    signal write_data_stored           : std_logic;
    signal write_complete              : std_logic;
    signal read_complete               : std_logic;
    signal bvalid                      : std_logic;
    signal rvalid                      : std_logic;
begin

    cke  <= '1';

    commands: process(clk, arst) is
    begin
        if (arst = '0') then
            transition_timer <= to_unsigned(powerup_cycles, timer_width);
            command <= sdram_nop;
            state <= state_powerup_wait;
            write_complete <= '0';
            read_complete <= '0';
            required_refreshes <= to_unsigned(0, refresh_count_width);
            refresh_timer <= to_unsigned(refresh_timer_cycles, refresh_timer_width);
        elsif rising_edge(clk) then
            write_complete <= '0';
            read_complete <= '0';
            command <= sdram_nop;
            a     <= (others => 'U');
            ba    <= (others => 'U');
            dq_oe <= '0';
            dq_o  <= (others => 'U');
            dqm   <= (others => 'U');

            if refresh_timer /= 0 then
                refresh_timer <= refresh_timer - 1;
            else
                required_refreshes <= required_refreshes + 1;
                refresh_timer <= to_unsigned(refresh_timer_cycles, refresh_timer_width);
            end if;

            if transition_timer /= 0 then
                transition_timer <= transition_timer - 1;
            else
                -- Finished waiting
                case(state) is
                    when state_powerup_wait =>
                        a(10) <= '1';
                        command <= sdram_precharge;
                        transition_timer <= to_unsigned(t_rp_cycles, timer_width);
                        state <= state_powerup_precharge;
                    when state_powerup_precharge =>
                        command <= sdram_refresh;
                        transition_timer <= to_unsigned(t_rc_cycles, timer_width);
                        required_refreshes <=
                            to_unsigned(total_powerup_refreshes-1, refresh_count_width);
                        state <= state_powerup_refresh;
                    when state_powerup_refresh =>
                        if required_refreshes = 0 then
                            ba <= "00";
                            a <= "0000000100000";
                            command <= sdram_load_mode_reg;
                            transition_timer <= to_unsigned(t_mrd_cycles, timer_width);
                            state <= state_powerup_mode_register;
                        else
                            required_refreshes <=
                                required_refreshes - 1;
                            command <= sdram_refresh;
                            transition_timer <= to_unsigned(t_rc_cycles, timer_width);
                        end if;
                    when state_powerup_mode_register =>
                        transition_timer <= to_unsigned(0, timer_width);
                        state <= state_idle;
                    when state_idle =>
                        if (required_refreshes /= 0) then
                            command <= sdram_refresh;
                            transition_timer <= to_unsigned(t_rc_cycles, timer_width);
                            required_refreshes <= required_refreshes - 1;
                        -- Technically we could wait for just the address, but
                        -- then we risk getting stuck in ACTIVATE until the
                        -- initiator gives us the data. Which could cause us to
                        -- miss refreshes.
                        elsif (write_address_stored = '1' and write_data_stored = '1' and write_complete = '0') then
                            ba <= write_address(23 downto 22);
                            a <= write_address(21 downto 9);
                            command <= sdram_active;
                            state <= state_activate;
                            transition_timer <= to_unsigned(t_rcd_cycles, timer_width);
                        elsif (read_address_stored = '1' and read_complete = '0') then
                            ba <= read_address(23 downto 22);
                            a <= read_address(21 downto 9);
                            command <= sdram_active;
                            state <= state_activate;
                            transition_timer <= to_unsigned(t_rcd_cycles, timer_width);
                        else
                            command <= sdram_nop;
                        end if;
                    when state_activate =>
                        if (write_address_stored = '1' and write_data_stored = '1') then
                            ba <= write_address(23 downto 22);
                            a(9 downto 0) <= write_address(9 downto 0);
                            a(10) <= '1'; -- auto-precharge
                            a(12 downto 11) <= "UU";
                            dqm <= write_strobe;
                            dq_o <= write_data;
                            dq_oe <= '1';
                            command <= sdram_write;
                            state <= state_idle;
                            transition_timer <= to_unsigned(t_dpl_cycles + t_rp_cycles, timer_width);
                            write_complete <= '1';
                        elsif (read_address_stored = '1') then
                            ba <= read_address(23 downto 22);
                            a(9 downto 0) <= read_address(9 downto 0);
                            a(10) <= '1'; -- auto-precharge
                            a(12 downto 11) <= "UU";
                            command <= sdram_read;
                            state <= state_execute_read;
                            transition_timer <= to_unsigned(cas_latency, timer_width);
                        else
                            command <= sdram_nop;
                        end if;
                    when state_execute_read =>
                        command <= sdram_nop;
                        state <= state_idle;
                        read_data <= dq_i;
                        read_complete <= '1';
                        -- TODO: Verify, is that timing right? Seems to be
                        if (t_rp_cycles > cas_latency) then
                            command <= sdram_nop;
                            transition_timer <= to_unsigned(t_rp_cycles - cas_latency, timer_width);
                        else
                            -- TODO: We could handle some commands right now
                            command <= sdram_nop;
                        end if;
                end case;
            end if;
        end if;
    end process commands;

    axi_target.awready <= not write_address_stored;
    axi_target.wready  <= not write_data_stored;
    axi_target.arready <= not read_address_stored;
    axi_target.bvalid  <= bvalid;
    axi_target.rvalid  <= rvalid;

    axi_handler: process(clk, arst) is
    begin
        if (arst = '0') then
            write_address_stored <= '0';
            write_data_stored    <= '0';
            read_address_stored  <= '0';
        elsif rising_edge(clk) then
            if (axi_initiator.awvalid = '1' and write_address_stored = '0') then
                -- We ignore the last bit of the address, but otherwise assume
                -- that any address mapping has already happened
                write_address <= axi_initiator.awaddr(24 downto 1);
                write_address_stored <= '1';
            end if;
            if (axi_initiator.wvalid = '1' and write_data_stored = '0') then
                write_data <= axi_initiator.wdata;
                write_strobe <= axi_initiator.wstrb;
                write_data_stored <= '1';
            end if;
            if (axi_initiator.arvalid = '1' and read_address_stored = '0') then
                read_address <= axi_initiator.araddr(24 downto 1);
                read_address_stored <= '1';
            end if;
            if (write_complete = '1') then
                bvalid <= '1';
                axi_target.bresp <= "00";
                write_address_stored <= '0';
                write_data_stored <= '0';
                write_address <= (others => 'U');
                write_data <= (others => 'U');
            end if;
            if (read_complete = '1') then
                rvalid <= '1';
                axi_target.rdata <= read_data;
                axi_target.rresp <= "00";
                read_address_stored <= '0';
                read_address <= (others => 'U');
            end if;

            -- Complete AXI write transaction
            if (axi_initiator.bready = '1' and bvalid = '1') then
                -- TODO: Should we send this earlier? Once the write is in the
                -- pipeline we could just let the initiator move on early, there is no
                -- failure condition for our writes
                bvalid <= '0';
                axi_target.bresp <= (others => 'U');
            end if;

            if (axi_initiator.rready = '1' and rvalid = '1') then
                rvalid <= '0';
                axi_target.rdata <= (others => 'U');
                axi_target.rresp <= (others => 'U');
            end if;
        end if;
    end process axi_handler;

    command_translator: process(command) is
    begin
        case(command) is
            when sdram_nop =>
                csn  <= '0';
                rasn <= '1';
                casn <= '1';
                wen  <= '1';
            when sdram_precharge =>
                csn  <= '0';
                rasn <= '0';
                casn <= '1';
                wen  <= '0';
            when sdram_refresh =>
                csn  <= '0';
                rasn <= '0';
                casn <= '0';
                wen  <= '1';
            when sdram_load_mode_reg =>
                csn  <= '0';
                rasn <= '0';
                casn <= '0';
                wen  <= '0';
            when sdram_active =>
                csn  <= '0';
                rasn <= '0';
                casn <= '1';
                wen  <= '1';
            when sdram_write =>
                csn  <= '0';
                rasn <= '1';
                casn <= '0';
                wen  <= '0';
            when sdram_read =>
                csn  <= '0';
                rasn <= '1';
                casn <= '0';
                wen  <= '1';
            when others =>
                assert false report "Unimplemented command" severity failure;
                csn  <= 'U';
                rasn <= 'U';
                casn <= 'U';
                wen  <= 'U';
        end case;
    end process command_translator;
end behave;
