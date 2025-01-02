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
    constant refresh_count_width  : integer := clog2(total_powerup_refreshes);

    type state_t is (
        state_powerup_wait,
        state_powerup_precharge,
        state_powerup_refresh,
        state_powerup_mode_register,
        state_idle,
        state_refresh,
        state_activate,
        state_execute_write
    );

    type command_bits_t is record
        csn  : std_logic;
        casn : std_logic;
        rasn : std_logic;
        wen  : std_logic;
    end record;

    type internal_state_t is record
        -- power-up cycles will always be the longest, by far. We can re-use this
        -- counter for all states that require waits.
        cycles_countdown            : unsigned(powerup_cycles_width - 1 downto 0);
        state                       : state_t;
        remaining_powerup_refreshes : unsigned(refresh_count_width - 1 downto 0);
    end record;
    signal internal_state       : internal_state_t;
    signal command_bits_hookup  : command_bits_t;
    signal read_address         : std_logic_vector(23 downto 0);
    signal write_address        : std_logic_vector(23 downto 0);
    signal write_data           : std_logic_vector(15 downto 0);
    signal write_strobe         : std_logic_vector(1 downto 0);
    signal read_address_stored  : std_logic;
    signal write_address_stored : std_logic;
    signal write_data_stored    : std_logic;
    signal write_complete       : std_logic;
    signal bvalid               : std_logic;

    procedure send_command(
        constant command    : in sdram_command_t;
        signal command_bits : out command_bits_t
    ) is
    begin
        case(command) is
            when sdram_nop =>
                command_bits.csn  <= '0';
                command_bits.rasn <= '1';
                command_bits.casn <= '1';
                command_bits.wen  <= '1';
            when sdram_precharge =>
                command_bits.csn  <= '0';
                command_bits.rasn <= '0';
                command_bits.casn <= '1';
                command_bits.wen  <= '0';
            when sdram_refresh =>
                command_bits.csn  <= '0';
                command_bits.rasn <= '0';
                command_bits.casn <= '0';
                command_bits.wen  <= '1';
            when sdram_load_mode_reg =>
                command_bits.csn  <= '0';
                command_bits.rasn <= '0';
                command_bits.casn <= '0';
                command_bits.wen  <= '0';
            when sdram_active =>
                command_bits.csn  <= '0';
                command_bits.rasn <= '0';
                command_bits.casn <= '1';
                command_bits.wen  <= '1';
            when sdram_write =>
                command_bits.csn  <= '0';
                command_bits.rasn <= '1';
                command_bits.casn <= '0';
                command_bits.wen  <= '0';
            when others =>
                assert false report "Unimplemented command" severity failure;
        end case;
    end;

    procedure transition_to_state(
        constant next_state                : in state_t;
        constant total_powerup_refreshes_n : in integer;

        signal internal_state_n : out internal_state_t;
        signal command_bits     : out command_bits_t;
        signal ba_n             : out std_logic_vector(1 downto 0);
        signal a_n              : out std_logic_vector(12 downto 0)
    ) is
    begin
        case(next_state) is
            when state_powerup_precharge =>
                a_n(10) <= '1';
                send_command(sdram_precharge, command_bits);
                internal_state_n.cycles_countdown <= to_unsigned(t_rp_cycles, powerup_cycles_width);
            when state_powerup_refresh =>
                send_command(sdram_refresh, command_bits);
                internal_state_n.cycles_countdown <= to_unsigned(t_rc_cycles, powerup_cycles_width);
                internal_state_n.remaining_powerup_refreshes <=
                    to_unsigned(total_powerup_refreshes_n-1, refresh_count_width);
            when state_powerup_mode_register =>
                ba_n <= "00";
                a_n <= "0000000100000";
                send_command(sdram_load_mode_reg, command_bits);
                internal_state_n.cycles_countdown <= to_unsigned(t_mrd_cycles, powerup_cycles_width);
            when state_idle =>
                send_command(sdram_nop, command_bits);
                internal_state_n.cycles_countdown <= to_unsigned(0, powerup_cycles_width);
            when others =>
                assert false report "Unimplemented state transition" severity failure;
        end case;
        internal_state_n.state <= next_state;
    end procedure transition_to_state;
begin

    cke  <= '1';
    csn  <= command_bits_hookup.csn;
    casn <= command_bits_hookup.casn;
    rasn <= command_bits_hookup.rasn;
    wen  <= command_bits_hookup.wen;

    commands: process(clk, arst) is
    begin
        if (arst = '0') then
            internal_state.cycles_countdown <= to_unsigned(powerup_cycles, powerup_cycles_width);
            send_command(sdram_nop, command_bits_hookup);
            internal_state.state <= state_powerup_wait;
            write_complete <= '0';
        elsif rising_edge(clk) then
            write_complete <= '0';
            if internal_state.cycles_countdown /= 0 then
                internal_state.cycles_countdown <= internal_state.cycles_countdown - 1;
                a     <= (others => 'U');
                ba    <= (others => 'U');
                dq_oe <= '0';
                dq_o  <= (others => 'Z');
                dqm   <= (others => 'U');

                send_command(sdram_nop, command_bits_hookup);
            else
                -- Finished waiting
                case(internal_state.state) is
                    when state_powerup_wait =>
                        transition_to_state(
                            state_powerup_precharge,
                            total_powerup_refreshes,
                            internal_state,
                            command_bits_hookup,
                            ba,
                            a
                        );
                    when state_powerup_precharge =>
                        transition_to_state(
                            state_powerup_refresh,
                            total_powerup_refreshes,
                            internal_state,
                            command_bits_hookup,
                            ba,
                            a
                        );
                    when state_powerup_refresh =>
                        if internal_state.remaining_powerup_refreshes = 0 then
                            transition_to_state(
                                state_powerup_mode_register,
                                total_powerup_refreshes,
                                internal_state,
                                command_bits_hookup,
                                ba,
                                a
                            );
                        else
                            internal_state.remaining_powerup_refreshes <=
                                internal_state.remaining_powerup_refreshes - 1;
                            send_command(sdram_refresh, command_bits_hookup);
                            internal_state.cycles_countdown <= to_unsigned(t_rc_cycles, powerup_cycles_width);
                        end if;
                    when state_powerup_mode_register =>
                        transition_to_state(
                            state_idle,
                            total_powerup_refreshes,
                            internal_state,
                            command_bits_hookup,
                            ba,
                            a
                        );
                    when state_idle =>
                        -- Technically we could wait for just the address, but
                        -- then we risk getting stuck in ACTIVATE until the
                        -- initiator gives us the data. Which could cause us to
                        -- miss refreshes.
                        if (write_address_stored = '1' and write_data_stored = '1') then
                            ba <= write_address(23 downto 22);
                            a <= write_address(21 downto 9);
                            send_command(sdram_active, command_bits_hookup);
                            internal_state.state <= state_activate;
                            internal_state.cycles_countdown <= to_unsigned(t_rcd_cycles, powerup_cycles_width);
                        else
                            send_command(sdram_nop, command_bits_hookup);
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
                            send_command(sdram_write, command_bits_hookup);
                            -- TODO: need to remember that we were waiting, to send response
                            internal_state.state <= state_idle;
                            internal_state.cycles_countdown <= to_unsigned(t_dpl_cycles + t_rp_cycles, powerup_cycles_width);
                            write_complete <= '1';
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
            end if;

            -- Complete AXI write transaction
            if (axi_initiator.bready = '1' and bvalid = '1') then
                bvalid <= '0';
                axi_target.bresp <= (others => 'U');
            end if;
        end if;
    end process axi_handler;

end behave;
