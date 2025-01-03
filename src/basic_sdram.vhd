library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
    use work.util.all;

-- Simple SDRAM controller with no burst support, opens the row for every
-- request and closes it automatically.
entity basic_sdram is
    generic (
        clk_period              : time;
        required_power_on_wait  : time    := 200 us;
        total_powerup_refreshes : integer := 8;
        t_rp                    : time    := 20 ns;
        t_mrd                   : time    := 15 ns;
        t_rc                    : time    := 67.5 ns;
        t_rcd                   : time    := 20 ns;
        t_dpl                   : time    := 14 ns
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
        required_power_on_wait, clk_period
    );
    constant powerup_cycles_width : integer := clog2(powerup_cycles);
    constant t_rp_cycles          : integer := period_to_cycles(t_rp, clk_period);
    constant t_rc_cycles          : integer := period_to_cycles(t_rc, clk_period);
    constant t_mrd_cycles         : integer := period_to_cycles(t_mrd, clk_period);
    constant t_rcd_cycles         : integer := period_to_cycles(t_rcd, clk_period);
    constant t_dpl_cycles         : integer := period_to_cycles(t_dpl, clk_period);
    constant cas_latency          : integer := 2;
    constant refresh_count_width  : integer := clog2(total_powerup_refreshes);

    type state_t is (
        state_powerup_wait,
        state_powerup_precharge,
        state_powerup_refresh,
        state_powerup_mode_register,
        state_idle,
        state_refresh,
        state_activate,
        state_execute_read
    );

    -- power-up cycles will always be the longest, by far. We can re-use this
    -- counter for all states that require waits.
    signal cycles_countdown            : unsigned(powerup_cycles_width - 1 downto 0);
    signal state                       : state_t;
    signal remaining_powerup_refreshes : unsigned(refresh_count_width - 1 downto 0);
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
            cycles_countdown <= to_unsigned(powerup_cycles, powerup_cycles_width);
            command <= sdram_nop;
            state <= state_powerup_wait;
            write_complete <= '0';
            read_complete <= '0';
        elsif rising_edge(clk) then
            write_complete <= '0';
            read_complete <= '0';
            command <= sdram_nop;

            if cycles_countdown /= 0 then
                cycles_countdown <= cycles_countdown - 1;
                a     <= (others => 'U');
                ba    <= (others => 'U');
                dq_oe <= '0';
                dq_o  <= (others => 'U');
                dqm   <= (others => 'U');
            else
                -- Finished waiting
                case(state) is
                    when state_powerup_wait =>
                        a(10) <= '1';
                        command <= sdram_precharge;
                        cycles_countdown <= to_unsigned(t_rp_cycles, powerup_cycles_width);
                        state <= state_powerup_precharge;
                    when state_powerup_precharge =>
                        command <= sdram_refresh;
                        cycles_countdown <= to_unsigned(t_rc_cycles, powerup_cycles_width);
                        remaining_powerup_refreshes <=
                            to_unsigned(total_powerup_refreshes-1, refresh_count_width);
                        state <= state_powerup_refresh;
                    when state_powerup_refresh =>
                        if remaining_powerup_refreshes = 0 then
                            ba <= "00";
                            a <= "0000000100000";
                            command <= sdram_load_mode_reg;
                            cycles_countdown <= to_unsigned(t_mrd_cycles, powerup_cycles_width);
                            state <= state_powerup_mode_register;
                        else
                            remaining_powerup_refreshes <=
                                remaining_powerup_refreshes - 1;
                            command <= sdram_refresh;
                            cycles_countdown <= to_unsigned(t_rc_cycles, powerup_cycles_width);
                        end if;
                    when state_powerup_mode_register =>
                        cycles_countdown <= to_unsigned(0, powerup_cycles_width);
                        state <= state_idle;
                    when state_idle =>
                        -- Technically we could wait for just the address, but
                        -- then we risk getting stuck in ACTIVATE until the
                        -- initiator gives us the data. Which could cause us to
                        -- miss refreshes.
                        if (write_address_stored = '1' and write_data_stored = '1' and write_complete = '0') then
                            ba <= write_address(23 downto 22);
                            a <= write_address(21 downto 9);
                            command <= sdram_active;
                            state <= state_activate;
                            cycles_countdown <= to_unsigned(t_rcd_cycles, powerup_cycles_width);
                        elsif (read_address_stored = '1' and read_complete = '0') then
                            ba <= read_address(23 downto 22);
                            a <= read_address(21 downto 9);
                            command <= sdram_active;
                            state <= state_activate;
                            cycles_countdown <= to_unsigned(t_rcd_cycles, powerup_cycles_width);
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
                            cycles_countdown <= to_unsigned(t_dpl_cycles + t_rp_cycles, powerup_cycles_width);
                            write_complete <= '1';
                        elsif (read_address_stored = '1') then
                            ba <= read_address(23 downto 22);
                            a(9 downto 0) <= read_address(9 downto 0);
                            a(10) <= '1'; -- auto-precharge
                            a(12 downto 11) <= "UU";
                            command <= sdram_read;
                            state <= state_execute_read;
                            cycles_countdown <= to_unsigned(cas_latency, powerup_cycles_width);
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
                            cycles_countdown <= to_unsigned(t_rp_cycles - cas_latency, powerup_cycles_width);
                        else
                            -- TODO: We could handle some commands right now
                            command <= sdram_nop;
                        end if;
                    when others =>
                        assert false report "Unimplemented state" severity failure;
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
