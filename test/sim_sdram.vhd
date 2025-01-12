library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.axi.all;
use work.math.all;
use work.sdram.all;

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
        clk  : in    std_logic;
        cke  : in    std_logic;
        csn  : in    std_logic;
        casn : in    std_logic;
        rasn : in    std_logic;
        wen  : in    std_logic;
        dqm  : in    std_logic_vector(1 downto 0);
        ba   : in    std_logic_vector(1 downto 0);
        a    : in    std_logic_vector(12 downto 0);
        dq_i : in    std_logic_vector(15 downto 0);
        dq_o : out   std_logic_vector(15 downto 0);

        -- The real chip doesn't have a reset, but it can be useful to reset
        -- the model to simulate power-up
        arst_model : in std_logic
    );
end sim_sdram;

architecture behav of sim_sdram is
    -- Real chip has 32 MiB, 16-bit words. But if we do that, the simulator will crash
    constant word_count : integer := 128;

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
        state_row_active,
        -- state_active_powerdown,
        -- state_read,
        -- state_read_suspend,
        -- state_write,
        -- state_write_suspend,
        state_reada
        -- state_reada_suspend,
        -- state_writea,
        -- state_writea_suspend
    );

    signal memory      : memory_array;
    signal cas_latency : std_logic_vector(2 downto 0);
    signal active_row  : std_logic_vector(12 downto 0);
    -- Technically you can activate rows in multiple banks at once. But we
    -- don't support that in the simulation yet.
    signal active_bank : std_logic_vector(1 downto 0);
    signal active_column : std_logic_vector(8 downto 0);

    signal power_on_time           : time            := 0 ns;
    signal powerup_state           : powerup_state_t := powerup_want_wait;
    signal state                   : state_t         := state_poweron;
    signal last_transition_time    : time            := 0 ns;
    signal seen_startup_refreshes  : integer         := 0;
    signal seen_periodic_refreshes : integer         := 0;
    signal last_full_refresh_time  : time            := 0 ns;
    signal cas_waits               : integer         := 0;
    signal command                 : sdram_command_t;
begin
    powerup: process(clk, arst_model)
    begin
        if (arst_model = '0') then
            power_on_time <= now;
            powerup_state <= powerup_want_wait;
            seen_startup_refreshes <= 0;
        elsif (rising_edge(clk) and cke = '1') then

            -- Walk through and assert the powerup process
            case (powerup_state) is
                when powerup_want_wait =>
                    assert command = sdram_nop report "in wait period for power up, no cmds allowed yet" severity error;
                    if (now - power_on_time >= required_power_on_wait) then
                        powerup_state <= powerup_want_precharge;
                    end if;
                when powerup_want_precharge =>
                    if(command /= sdram_nop) then
                        assert command = sdram_precharge report "expecting precharge" severity error;
                        -- TODO: verify it's precharge-all specifically
                        powerup_state <= powerup_want_refresh;
                    end if;
                when powerup_want_refresh =>
                    if(command /= sdram_nop) then
                        assert command = sdram_refresh report "expecting refresh" severity error;
                        if (seen_startup_refreshes < power_on_refresh_count - 1) then
                            seen_startup_refreshes <= seen_startup_refreshes + 1;
                        else
                            powerup_state <= powerup_want_lmr;
                        end if;
                    end if;
                when powerup_want_lmr =>
                    if(command /= sdram_nop) then
                        assert command = sdram_load_mode_reg report "expecting lmr" severity error;
                        powerup_state <= powerup_ready;
                    end if;
                when powerup_ready =>
                    -- Don't care
            end case;
        end if;
    end process powerup;

    state_machine: process(clk, arst_model)
        variable new_state : state_t;
        variable full_address : std_logic_vector(23 downto 0);
    begin
        if (arst_model = '0') then
            state <= state_poweron;
            last_transition_time <= now;
            cas_latency <= "UUU";
            seen_periodic_refreshes <= 0;
            last_full_refresh_time <= now;
            active_row <= "UUUUUUUUUUUUU";
            active_bank <= "UU";
            for word in 0 to word_count loop
                memory(word) <= (others => 'U');
            end loop;
        elsif (rising_edge(clk) and cke = '1') then
            new_state := state;
            dq_o <= (others => 'U');

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
                        when sdram_nop =>
                            -- Don't care
                        when sdram_precharge =>
                            new_state := state_precharge;
                            last_transition_time <= now;
                        when others =>
                            assert false 
                                report "invalid command while in poweron state " & sdram_command_t'image(command)
                                severity error;
                    end case;
                when state_precharge =>
                    case (command) is
                        when sdram_nop =>
                        when others =>
                            assert false 
                                report "invalid command while in precharge state"
                                severity error;
                    end case;
                when state_auto_refresh =>
                    case (command) is
                        when sdram_nop =>
                        when others =>
                            assert false
                                report "invalid command while in auto-refresh state"
                                severity error;
                    end case;
                when state_mode_reg =>
                    case (command) is
                        when sdram_nop =>
                        when others =>
                            assert false
                                report "invalid command while in LMR state"
                                severity error;
                    end case;
                when state_row_active_wait =>
                    case (command) is
                        when sdram_nop =>
                        when others =>
                            assert false
                                report "invalid command while in row_active_wait state"
                                severity error;
                    end case;
                when state_idle =>
                    case (command) is
                        when sdram_load_mode_reg =>
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
                        when sdram_refresh =>
                            new_state := state_auto_refresh;
                            last_transition_time <= now;
                        when sdram_active =>
                            new_state := state_row_active_wait;
                            last_transition_time <= now;
                            active_row <= a;
                            active_bank <= ba;
                        when sdram_nop =>
                            -- Don't care
                        when others =>
                            assert false report "invalid command while in idle state" severity error;
                    end case;
                when state_row_active =>
                    case (command) is
                        when sdram_read =>
                            assert a(10) = '1' report "only auto-precharge is currently supported" severity error;
                            active_column <= a(8 downto 0);
                            new_state := state_reada;
                            last_transition_time <= now;
                            cas_waits <= to_integer(unsigned(cas_latency)) - 2;
                        when sdram_write =>
                            full_address := active_bank & active_row & a(8 downto 0);
                            assert a(10) = '1' report "only auto-precharge is currently supported" severity error;
                            -- TODO: dqm
                            memory(to_integer(unsigned(full_address))) <= dq_i;
                            -- TODO: we need to validate t_dpl first
                            new_state := state_precharge;
                            last_transition_time <= now;
                        when sdram_precharge =>
                            -- TODO: do we need to validate some timing here?
                            new_state := state_precharge;
                            last_transition_time <= now;
                        when sdram_nop =>
                            -- Don't care
                        when others =>
                            assert false report "invalid command while in row_active state" severity error;
                    end case;
                when state_reada =>
                    if (cas_waits = 0 ) then
                        full_address := active_bank & active_row & active_column;
                        dq_o <= memory(to_integer(unsigned(full_address)));
                        -- TODO: we won't always go to idle, depends on CAS vs t_rp durations
                        new_state := state_idle;
                        last_transition_time <= now;
                    else
                        -- Technically other commands can be interleaved, but we don't support it
                        assert command = sdram_nop report "waiting for CAS latency" severity error;
                        cas_waits <= cas_waits - 1;
                    end if;
            end case;

            state <= new_state;
        end if;
    end process state_machine;

    command_parser: process(csn, casn, rasn, wen, arst_model)
        variable concat : std_logic_vector(2 downto 0);
    begin
        concat := rasn & casn & wen;
        command <= sdram_nop;
        if (csn = '0' and arst_model = '1') then
            case (concat) is
                when "111" =>
                    command <= sdram_nop;
                when "011" =>
                    command <= sdram_active;
                when "101" =>
                    command <= sdram_read;
                when "100" =>
                    command <= sdram_write;
                when "110" =>
                    command <= sdram_burst_terminate;
                when "010" =>
                    command <= sdram_precharge;
                when "001" =>
                    command <= sdram_refresh;
                when "000" =>
                    command <= sdram_load_mode_reg;
                when others =>
                    assert false
                        report "Unknown command " & to_string(concat)
                        severity error;
            end case;
        end if;
    end process command_parser;

end behav;
