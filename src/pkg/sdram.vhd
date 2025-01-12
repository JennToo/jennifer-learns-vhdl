package sdram is
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
end package sdram;
