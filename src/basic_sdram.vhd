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
        t_rc                    : time    := 67.5 ns
    );
    port(
        clk  : in std_logic;
        arst : in std_logic;

        axi_initiator : in axi4l_initiator_signals_t;
        axi_target    : out axi4l_target_signals_t;

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
    constant t_rp_cycles          : integer := period_to_cycles(t_rp, clk_period);
    constant t_rc_cycles          : integer := period_to_cycles(t_rc, clk_period);
    constant t_mrd_cycles         : integer := period_to_cycles(t_mrd, clk_period);
    constant refresh_count_width  : integer := clog2(total_powerup_refreshes);

    type state_t is (
        state_powerup_wait,
        state_powerup_precharge,
        state_powerup_refresh,
        state_powerup_mode_register,
        state_idle,
        state_refresh,
        state_activate,
        state_execute,
        state_precharge
    );

    type command_bits_t is record
        cs_l  : std_logic;
        cas_l : std_logic;
        ras_l : std_logic;
        we_l  : std_logic;
    end record;

    -- power-up cycles will always be the longest, by far. We can re-use this
    -- counter for all states that require waits.
    signal cycles_countdown            : unsigned(powerup_cycles_width - 1 downto 0);
    signal state                       : state_t;
    signal remaining_powerup_refreshes : unsigned(refresh_count_width - 1 downto 0);
    signal command_bits_hookup         : command_bits_t;

    procedure send_command(
        constant command    : in sdram_command_t;
        signal command_bits : out command_bits_t
    ) is
    begin
        case(command) is
            when sdram_nop =>
                command_bits.cs_l  <= '0';
                command_bits.ras_l <= '1';
                command_bits.cas_l <= '1';
                command_bits.we_l  <= '1';
            when sdram_precharge =>
                command_bits.cs_l  <= '0';
                command_bits.ras_l <= '0';
                command_bits.cas_l <= '1';
                command_bits.we_l  <= '0';
            when sdram_refresh =>
                command_bits.cs_l  <= '0';
                command_bits.ras_l <= '0';
                command_bits.cas_l <= '0';
                command_bits.we_l  <= '1';
            when sdram_load_mode_reg =>
                command_bits.cs_l  <= '0';
                command_bits.ras_l <= '0';
                command_bits.cas_l <= '0';
                command_bits.we_l  <= '0';
            when others =>
                assert false report "Unimplemented command" severity failure;
        end case;
    end;

    procedure transition_to_state(
        constant next_state : in state_t;
        constant total_powerup_refreshes_n : in integer;

        signal state_n                 : out state_t;
        signal command_bits            : out command_bits_t;
        signal ba_n                    : out std_logic_vector(1 downto 0);
        signal a_n                     : out std_logic_vector(12 downto 0);
        signal cycles_countdown_n      : out unsigned(powerup_cycles_width - 1 downto 0);
        signal remaining_powerup_refreshes_n : out unsigned(refresh_count_width - 1 downto 0)
    ) is
    begin
        case(next_state) is
            when state_powerup_precharge =>
                a_n(10) <= '1';
                send_command(sdram_precharge, command_bits);
                cycles_countdown_n <= to_unsigned(t_rp_cycles, powerup_cycles_width);
            when state_powerup_refresh =>
                send_command(sdram_refresh, command_bits);
                cycles_countdown_n <= to_unsigned(t_rc_cycles, powerup_cycles_width);
                remaining_powerup_refreshes_n <= to_unsigned(total_powerup_refreshes_n-1, refresh_count_width);
            when state_powerup_mode_register =>
                ba_n <= "00";
                a_n <= "0000000100000";
                send_command(sdram_load_mode_reg, command_bits);
                cycles_countdown_n <= to_unsigned(t_mrd_cycles, powerup_cycles_width);
            when others =>
                assert false report "Unimplemented state transition" severity failure;
        end case;
        state_n <= next_state;
    end procedure transition_to_state;
begin

    cke   <= '1';
    cs_l  <= command_bits_hookup.cs_l;
    cas_l <= command_bits_hookup.cas_l;
    ras_l <= command_bits_hookup.ras_l;
    we_l  <= command_bits_hookup.we_l;

    commands: process(clk, arst) is
    begin
        if (arst = '0') then
            cycles_countdown <= to_unsigned(powerup_cycles, powerup_cycles_width);
            send_command(sdram_nop, command_bits_hookup);
            state <= state_powerup_wait;
        elsif rising_edge(clk) then
            if cycles_countdown /= 0 then
                cycles_countdown <= cycles_countdown - 1;
                send_command(sdram_nop, command_bits_hookup);
            else
                -- Finished waiting
                case(state) is
                    when state_powerup_wait =>
                        transition_to_state(
                            state_powerup_precharge,
                            total_powerup_refreshes,
                            state,
                            command_bits_hookup,
                            ba,
                            a,
                            cycles_countdown,
                            remaining_powerup_refreshes
                        );
                    when state_powerup_precharge =>
                        transition_to_state(
                            state_powerup_refresh,
                            total_powerup_refreshes,
                            state,
                            command_bits_hookup,
                            ba,
                            a,
                            cycles_countdown,
                            remaining_powerup_refreshes
                        );
                    when state_powerup_refresh =>
                        if remaining_powerup_refreshes = 0 then
                            transition_to_state(
                                state_powerup_mode_register,
                                total_powerup_refreshes,
                                state,
                                command_bits_hookup,
                                ba,
                                a,
                                cycles_countdown,
                                remaining_powerup_refreshes
                            );
                        else
                            remaining_powerup_refreshes <= remaining_powerup_refreshes - 1;
                            send_command(sdram_refresh, command_bits_hookup);
                            cycles_countdown <= to_unsigned(t_rc_cycles, powerup_cycles_width);
                        end if;
                    when state_powerup_mode_register =>
                        state <= state_idle;
                        send_command(sdram_nop, command_bits_hookup);
                    when state_idle =>
                        send_command(sdram_nop, command_bits_hookup);
                    when others =>
                        assert false report "Unimplemented state" severity failure;
                end case;
            end if;
        end if;
    end process commands;

end behave;
