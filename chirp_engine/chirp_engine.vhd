library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


use work.sine_table_pkg.all;

-- frequency calculation:
-- f = f_numerical/2**Phase_width * f_sampling
-- f_numerical is f_start and f_stop

-- other way around: f*2**PW /f_s = f_numerical


-- idea for nonlinear chirp:
-- 1. make lookuptable with freqsteps, 64 entries, addressable by index
-- 2. when start chirp, precalculate every frequency threshold
--      needs 64 additions:
--         a. df = (freqend-freqstart)/2**addr_width
--         b. threshold = freqstart
--         c. loop threshold = threshold + df
-- 3. on freqchange, use SAR approach to figure out the new freqstep


entity chirp_engine is
    generic(
        G_PHASE_WIDTH: integer := PHASE_WIDTH;
        G_AMP_WIDTH  : integer := AMP_WIDTH
    );
    port(
        clk           : in std_logic;
        rst           : in std_logic;
        do_chirp      : in std_logic;
        start_freq    : in unsigned(G_PHASE_WIDTH - 1 downto 0);
        stop_freq     : in unsigned(G_PHASE_WIDTH - 1 downto 0);
        freq_step     : in unsigned(G_PHASE_WIDTH - 1 downto 0);
        freq_step_down: in unsigned(G_PHASE_WIDTH - 1 downto 0);
        repeat        : in std_logic;
        chirp_finished: out std_logic;
        ready         : out std_logic;
        dout          : out signed(G_AMP_WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of chirp_engine is

    signal phase_acc: unsigned(G_PHASE_WIDTH - 1 downto 0) := (others => '0');
    signal freq_acc: unsigned(G_PHASE_WIDTH - 1 downto 0):= (others => '0');

    signal s_rst: std_logic;
    signal lut_addr: integer range 0 to ADDR_RANGE - 1;

    signal start_pulse_ff: std_logic_vector(1 downto 0);
    signal start_pulse: std_logic;


    type state_t is (idle_st, rampup_st, rampdown_st);
    signal fsm_state: state_t;
    signal fsm_next_state: state_t;

    signal tst: integer:=ADDR_RANGE;


    -- 0: low freq --> high freq; 1: high freq --> low freq
    signal direction: std_logic;

begin
    s_rst <= rst;

    p_start_sync: process(clk, s_rst)
    begin
        if s_rst then
            start_pulse_ff <= (others => '0');
        elsif rising_edge(clk) then
            start_pulse_ff <= start_pulse_ff(1) & do_chirp;
        end if;
    end process;

    start_pulse <= '1' when start_pulse_ff = "01" else '0';
    ready <= '1' when fsm_state = idle_st else '0';

    p_fsm_seq: process(clk, s_rst)
    begin
        if s_rst then
            fsm_state <= idle_st;
            direction <= '0';
            phase_acc <= (others => '0');
            freq_acc <= start_freq;



        elsif rising_edge(clk) then
            fsm_state <= fsm_next_state;

            case fsm_state is
                when idle_st =>
                    freq_acc <= start_freq;

                    phase_acc <= phase_acc + freq_acc;
                when rampup_st =>
                    if direction = '0' then
                        freq_acc <= freq_acc + freq_step;
                    else
                        freq_acc <= freq_acc - freq_step;
                    end if;
                    phase_acc <= phase_acc + freq_acc;
                when rampdown_st =>
                    if direction = '0' then
                        freq_acc <= freq_acc - freq_step_down;
                    else
                        freq_acc <= freq_acc + freq_step_down;
                    end if;
                    phase_acc <= phase_acc + freq_acc;
            end case;

            if fsm_state = idle_st and fsm_next_state /= idle_st then
                direction <= '1' when start_freq >= stop_freq else '0';
            end if;
            -- if fsm_state /= fsm_next_state then
            --     case fsm_state is
            --         when idle_st =>
            --         when others =>
            --     end case;
            -- end if;
        end if;
    end process;

    p_fsm_comb_state: process(all)
    begin
        fsm_next_state <= fsm_state;
        case fsm_state is
            when idle_st =>
                if start_pulse = '1' then
                    fsm_next_state <= rampup_st;
                end if;
                chirp_finished <= '0';

            when rampup_st =>
                if (((freq_acc >= stop_freq) and direction = '0') or
                    ((freq_acc <= stop_freq) and direction = '1')) then
                    fsm_next_state <= rampdown_st;
                    chirp_finished <= '1';
                else
                    chirp_finished <= '0';
                end if;

            when rampdown_st =>
                if (((freq_acc >= start_freq) and direction = '1') or
                    ((freq_acc <= start_freq) and direction = '0')) then
                    if repeat = '0' then
                        fsm_next_state <= idle_st;
                    else
                        fsm_next_state <= rampup_st;
                    end if;
                end if;
                chirp_finished <= '1';

            when others =>
                fsm_next_state <= idle_st;
                chirp_finished <= '0';

        end case;
    end process;


    lut_addr <= to_integer(phase_acc(G_PHASE_WIDTH - 1 downto G_PHASE_WIDTH - (ADDR_WIDTH)));

    dout <= SIN_LUT(lut_addr);

end rtl;
