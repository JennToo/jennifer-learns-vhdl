library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- A simulated SDRAM chip. Based on the IS42S16160G-7TL datasheet since that's what
-- the ULX3S uses.
entity sim_sdram is
    generic (
        required_power_on_wait  : time := 200 us;
        power_on_refresh_count  : integer := 8;
        -- Defaults are based on -7 variant
        -- Clock cycle time (CAS 3 or CAS 2)
        t_ck3                   : time := 7 ns;
        t_ck2                   : time := 10 ns;
        -- REF to REF / ACT to ACT
        t_rc                    : time := 67.5 ns;
        -- ACT to PRE
        t_ras                   : time := 45 ns;
        -- PRE to ACT
        t_rp                    : time := 20 ns;
        -- Active command to read/write command delay
        t_rcd                   : time := 20 ns;
        -- ACT [0] to ACT [1]
        t_rrd                   : time := 14 ns;
        -- Input data to precharge command delay
        t_dpl                   : time := 14 ns;
        -- Input data to active / refresh command during auto-precharge
        t_dal                   : time := 35 ns;
        -- Mode register set time
        t_mrd                   : time := 15 ns;
        -- Refresh cycle time
        t_ref                   : time := 64 ms;
        periodic_refresh_count  : integer := 8192
    );

    port(
        clk   : in    std_logic;
        cke   : in    std_logic;
        cs_l  : in    std_logic;
        cas_l : in    std_logic;
        ras_l : in    std_logic;
        we_l  : in    std_logic;
        dqml  : in    std_logic;
        dqmh  : in    std_logic;
        ba    : in    std_logic_vector(1 downto 0);
        a     : in    std_logic_vector(12 downto 0);
        dq    : inout std_logic_vector(15 downto 0);

        -- The real chip doesn't have a reset, but it can be useful to reset
        -- the model to simulate power-up
        arst_model : in std_logic
    );
end sim_sdram;

architecture behav of sim_sdram is
    -- Real chip has 32 MiB, 16-bit words. But if we do that, the simulator will crash
    constant word_count : integer := 65536;

    type memory_array is array (0 to word_count) of std_logic_vector(15 downto 0);
    type powerup_state_t is (
        powerup_want_wait,
        powerup_want_precharge,
        powerup_want_refresh,
        powerup_want_lmr,
        powerup_ready
    );
    type state_t is (
        state_poweron,
        state_precharge,
        state_idle,
        state_mode_reg,
        -- state_self_refresh,
        state_auto_refresh,
        -- state_powerdown,
        state_row_active_wait,
        state_row_active
        -- state_active_powerdown,
        -- state_read,
        -- state_read_suspend,
        -- state_write,
        -- state_write_suspend,
        -- state_reada,
        -- state_reada_suspend,
        -- state_writea,
        -- state_writea_suspend
    );
    type command_t is (
        command_nop,
        command_active,
        command_read,
        command_write,
        command_burst_terminate,
        command_precharge,
        command_refresh,
        command_load_mode_reg
    );

    signal memory                  : memory_array;
    signal cas_latency             : std_logic_vector(2 downto 0);
    signal active_row              : std_logic_vector(12 downto 0);
    -- Technically you can activate rows in multiple banks at once. But we
    -- don't support that in the simulation yet.
    signal active_bank             : std_logic_vector(1 downto 0);

    signal power_on_time           : time            := 0 ns;
    signal powerup_state           : powerup_state_t := powerup_want_wait;
    signal state                   : state_t         := state_poweron;
    signal last_transition_time    : time            := 0 ns;
    signal seen_startup_refreshes  : integer         := 0;
    signal seen_periodic_refreshes : integer         := 0;
    signal last_full_refresh_time  : time            := 0 ns;

    function get_command(
        f_cs_l  : in std_logic;
        f_cas_l : in std_logic;
        f_ras_l : in std_logic;
        f_we_l  : in std_logic
    ) return command_t is
        variable concat : std_logic_vector(2 downto 0) := f_cas_l & f_ras_l & f_we_l;
    begin
        if (f_cs_l = '1') then
            return command_nop;
        else
            case concat is
                when "111" =>
                    return command_nop;
                when "011" =>
                    return command_active;
                when "101" =>
                    return command_read;
                when "100" =>
                    return command_write;
                when "110" =>
                    return command_burst_terminate;
                when "010" =>
                    return command_precharge;
                when "001" =>
                    return command_refresh;
                when "000" =>
                    return command_load_mode_reg;
                when others =>
                    assert false report "unsupported command" severity error;
            end case;
        end if;
    end function get_command;
begin
    powerup: process(clk, arst_model)
        variable command : command_t;
    begin
        if (arst_model = '0') then
            power_on_time <= now;
            powerup_state <= powerup_want_wait;
            seen_startup_refreshes <= 0;
            for word in 0 to word_count loop
                memory(word) <= "UUUUUUUUUUUUUUUU";
            end loop;
        elsif (rising_edge(clk) and cke = '1') then
            command := get_command(cs_l, ras_l, cas_l, we_l);

            -- Walk through and assert the powerup process
            case (powerup_state) is
                when powerup_want_wait =>
                    assert command = command_nop report "in wait period for power up, no cmds allowed yet" severity error;
                    if (now - power_on_time >= required_power_on_wait) then
                        powerup_state <= powerup_want_precharge;
                    end if;
                when powerup_want_precharge =>
                    if(command /= command_nop) then
                        assert command = command_precharge report "expecting precharge" severity error;
                        -- TODO: verify it's precharge-all specifically
                        powerup_state <= powerup_want_refresh;
                    end if;
                when powerup_want_refresh =>
                    if(command /= command_nop) then
                        assert command = command_refresh report "expecting refresh" severity error;
                        if (seen_startup_refreshes < power_on_refresh_count - 1) then
                            seen_startup_refreshes <= seen_startup_refreshes + 1;
                        else
                            powerup_state <= powerup_want_lmr;
                        end if;
                    end if;
                when powerup_want_lmr =>
                    if(command /= command_nop) then
                        assert command = command_load_mode_reg report "expecting lmr" severity error;
                        powerup_state <= powerup_ready;
                    end if;
                when powerup_ready =>
                    -- Don't care
            end case;
        end if;
    end process powerup;

    state_machine: process(clk, arst_model)
        variable command : command_t;
        variable new_state : state_t;
        variable full_write_address : std_logic_vector(23 downto 0);
    begin
        if (arst_model = '0') then
            state <= state_poweron;
            last_transition_time <= now;
            cas_latency <= "UUU";
            seen_periodic_refreshes <= 0;
            last_full_refresh_time <= now;
            active_row <= "UUUUUUUUUUUUU";
            active_bank <= "UU";
        elsif (rising_edge(clk) and cke = '1') then
            command := get_command(cs_l, ras_l, cas_l, we_l);
            new_state := state;

            assert (now - last_full_refresh_time < t_ref)
                report "missed periodic refresh; last was at " & time'image(last_full_refresh_time)
                severity error;

            -- Process automatic state transitions
            case (state) is
                when state_precharge =>
                    if (now - last_transition_time >= t_rp) then
                        new_state := state_idle;
                        last_transition_time <= now;
                    end if;
                when state_auto_refresh =>
                    if (now - last_transition_time >= t_rc) then
                        -- Technically in the datasheet we go into precharge,
                        -- but t_rc is easier to use
                        new_state := state_idle;
                        last_transition_time <= now;
                        if (seen_periodic_refreshes < periodic_refresh_count - 1) then
                            seen_periodic_refreshes <= seen_periodic_refreshes + 1;
                        else
                            seen_periodic_refreshes <= 0;
                            last_full_refresh_time <= now;
                        end if;
                    end if;
                when state_mode_reg =>
                    if (now - last_transition_time >= t_mrd) then
                        new_state := state_idle;
                        last_transition_time <= now;
                    end if;
                when state_row_active_wait =>
                    if (now - last_transition_time >= t_rcd) then
                        new_state := state_row_active;
                        last_transition_time <= now;
                    end if;
                when others =>
                    -- Don't care
            end case;

            -- Process commands
            case (new_state) is
                when state_poweron =>
                    case (command) is
                        when command_nop =>
                            -- Don't care
                        when command_precharge =>
                            new_state := state_precharge;
                            last_transition_time <= now;
                        when others =>
                            assert false 
                                report "invalid command while in poweron state"
                                severity error;
                    end case;
                when state_precharge =>
                    case (command) is
                        when command_nop =>
                        when others =>
                            assert false 
                                report "invalid command while in precharge state"
                                severity error;
                    end case;
                when state_auto_refresh =>
                    case (command) is
                        when command_nop =>
                        when others =>
                            assert false
                                report "invalid command while in auto-refresh state"
                                severity error;
                    end case;
                when state_mode_reg =>
                    case (command) is
                        when command_nop =>
                        when others =>
                            assert false
                                report "invalid command while in LMR state"
                                severity error;
                    end case;
                when state_row_active_wait =>
                    case (command) is
                        when command_nop =>
                        when others =>
                            assert false
                                report "invalid command while in row_active_wait state"
                                severity error;
                    end case;
                when state_idle =>
                    case (command) is
                        when command_load_mode_reg =>
                            new_state := state_mode_reg;
                            last_transition_time <= now;
                            assert (ba = "00")
                                report "invalid bank address in LMR"
                                severity error;
                            assert (a(12 downto 7) = "000000")
                                report "invalid address in LMR " & to_string(a(12 downto 7))
                                severity error;
                            assert (a(6 downto 4) = "010" or a(6 downto 4) = "011")
                                report "invalid CAS latency in LMR" & to_string(a(6 downto 4))
                                severity error;
                            -- Other modes are legal, but not supported by the simulation yet
                            assert (a(3 downto 0) = "0000")
                                report "unsupported burst length in LMR" & to_string(a(3 downto 0))
                                severity error;
                            cas_latency <= a(6 downto 4);
                        when command_refresh =>
                            new_state := state_auto_refresh;
                            last_transition_time <= now;
                        when command_active =>
                            new_state := state_row_active_wait;
                            last_transition_time <= now;
                            active_row <= a;
                            active_bank <= ba;
                        when command_nop =>
                            -- Don't care
                        when others =>
                            assert false report "invalid command while in idle state" severity error;
                    end case;
                when state_row_active =>
                    case (command) is
                        when command_read =>
                            assert false report "unimplemented command" severity error;
                        when command_write =>
                            full_write_address := active_bank & active_row & a(8 downto 0);
                        when command_precharge =>
                            -- TODO: do we need to validate some timing here?
                            new_state := state_precharge;
                            last_transition_time <= now;
                        when command_nop =>
                            -- Don't care
                        when others =>
                            assert false report "invalid command while in row_active state" severity error;
                    end case;
                when others =>
                    assert false report "state not implemented" severity error;
            end case;

            state <= new_state;
        end if;
    end process state_machine;
end behav;
