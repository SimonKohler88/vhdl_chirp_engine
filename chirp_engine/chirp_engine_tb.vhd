library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sine_table_pkg.all;


entity chirp_engine_tb is
end entity;

architecture sim of chirp_engine_tb is

    constant CLK_PERIOD: time := 8 ns; -- 125 MHz

    -- constant PHASE_WIDTH : integer := 16;
    -- constant AMP_WIDTH : integer := 14;

    signal clk: std_logic := '0';
    signal rst: std_logic := '1';

    signal start_freq: unsigned(PHASE_WIDTH - 1 downto 0);
    signal stop_freq: unsigned(PHASE_WIDTH - 1 downto 0);
    signal freq_step: unsigned(PHASE_WIDTH - 1 downto 0);
    signal freq_step_down: unsigned(PHASE_WIDTH - 1 downto 0);

    signal dout: signed(AMP_WIDTH - 1 downto 0);
    signal do_chirp: std_logic;
    signal ready: std_logic;
    signal repeat: std_logic;
    signal chirp_finished: std_logic;
begin

    ------------------------------------------------------------------
    -- DUT
    ------------------------------------------------------------------
    DUT: entity work.chirp_engine
        generic map(
            G_PHASE_WIDTH => PHASE_WIDTH,
            G_AMP_WIDTH   => AMP_WIDTH
        )
        port map(
            clk            => clk,
            rst            => rst,
            do_chirp       => do_chirp,
            start_freq     => start_freq,
            stop_freq      => stop_freq,
            freq_step      => freq_step,
            freq_step_down => freq_step_down,
            chirp_finished => chirp_finished,
            repeat         => repeat,
            ready          => ready,
            dout           => dout
        );

    ------------------------------------------------------------------
    -- Clock
    ------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    ------------------------------------------------------------------
    -- Stimulus
    ------------------------------------------------------------------
    stim_proc: process
    begin

        ----------------------------------------------------------------
        -- Example:
        -- Start at FCW = 1000
        -- Increase by 10 every clock
        ----------------------------------------------------------------
        start_freq <= to_unsigned(1000, PHASE_WIDTH);
        stop_freq  <= to_unsigned(6000, PHASE_WIDTH);

        freq_step <= to_unsigned(10, PHASE_WIDTH);
        freq_step_down <= to_unsigned(100, PHASE_WIDTH);
        do_chirp <= '0';

        repeat <= '0';

        wait for 100 ns;

        rst <= '0';
        wait for 2 us;

        do_chirp <= '1';
        wait for 20 ns;
        do_chirp <= '0';

        wait for 200 ns;
        wait until ready = '1';
        wait for 100 ns;

        do_chirp <= '1';
        wait for 20 ns;
        do_chirp <= '0';

        wait for 200 ns;
        wait until ready = '1';
        wait for 100 ns;
        freq_step <= to_unsigned(1, PHASE_WIDTH);

        do_chirp <= '1';
        wait for 20 ns;
        do_chirp <= '0';
        wait for 200 ns;
        wait until ready = '1';
        wait for 100 ns;

        start_freq <= to_unsigned(2000, PHASE_WIDTH);
        freq_step <= to_unsigned(100, PHASE_WIDTH);
        stop_freq  <= to_unsigned(10000, PHASE_WIDTH);


        do_chirp <= '1';
        wait for 20 ns;
        do_chirp <= '0';
        report "Simulation finished";

        wait;

    end process;

end architecture;
