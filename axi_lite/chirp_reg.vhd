library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chirp_reg is
    generic (
        C_DATA_WIDTH: integer := 32
    );
    port (
        clk                : in  std_logic;
        resetn             : in  std_logic;

        -- Write interface (from AXI layer)
        wr_en              : in  std_logic;
        wr_addr            : in  integer;
        wr_data            : in  std_logic_vector(C_DATA_WIDTH - 1 downto 0);

        -- Read interface (from AXI layer)
        rd_addr            : in  integer;
        rd_data            : out std_logic_vector(C_DATA_WIDTH - 1 downto 0);

        -- Status inputs (read-only registers)
        ready              : in  std_logic;
        chirp_finished     : in  std_logic;

        -- Register outputs
        start_freq         : out std_logic_vector(15 downto 0);
        stop_freq          : out std_logic_vector(15 downto 0);
        freq_step          : out std_logic_vector(15 downto 0);
        freq_step_down     : out std_logic_vector(15 downto 0);
        do_chirp           : out std_logic;
        repeat_chirp       : out std_logic;
        enable_chirp_module: out std_logic
    );
end entity;

architecture rtl of chirp_reg is

    signal reg_start_freq: std_logic_vector(15 downto 0) := (others => '0');
    signal reg_stop_freq: std_logic_vector(15 downto 0) := (others => '0');
    signal reg_freq_step: std_logic_vector(15 downto 0) := (others => '0');
    signal reg_freq_step_down: std_logic_vector(15 downto 0) := (others => '0');
    signal reg_do_chirp: std_logic := '0';
    signal reg_repeat_chirp: std_logic := '0';
    signal reg_enable_chirp_module: std_logic := '0';


begin

    start_freq            <= reg_start_freq;
    stop_freq             <= reg_stop_freq;
    freq_step             <= reg_freq_step;
    freq_step_down        <= reg_freq_step_down;
    do_chirp              <= reg_do_chirp;
    repeat_chirp          <= reg_repeat_chirp;
    enable_chirp_module   <= reg_enable_chirp_module;
    --------------------------------------------------------------------------
    -- Register Write
    --------------------------------------------------------------------------
    p_write: process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                reg_start_freq     <= (others => '0');
                reg_stop_freq      <= (others => '0');
                reg_freq_step      <= (others => '0');
                reg_freq_step_down <= (others => '0');
                reg_do_chirp       <= '0';
            else
                reg_do_chirp <= '0'; -- auto-clear

                if wr_en = '1' then
                    case wr_addr is
                        when 16#00# => reg_start_freq            <= wr_data(15 downto 0);
                        when 16#04# => reg_stop_freq             <= wr_data(15 downto 0);
                        when 16#08# => reg_freq_step             <= wr_data(15 downto 0);
                        when 16#0C# => reg_freq_step_down        <= wr_data(15 downto 0);
                        when 16#10# => reg_do_chirp              <= wr_data(0);
                        when 16#14# => reg_repeat_chirp          <= wr_data(0);
                        when 16#18# => reg_enable_chirp_module   <= wr_data(0);
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Register Read (combinational)
    --------------------------------------------------------------------------
    p_read: process(all)
    begin
        case rd_addr is
            when 16#00#      => rd_data <= std_logic_vector(
                resize(unsigned(reg_start_freq), C_DATA_WIDTH));
            when 16#04#      => rd_data <= std_logic_vector(
                resize(unsigned(reg_stop_freq), C_DATA_WIDTH));
            when 16#08#      => rd_data <= std_logic_vector(
                resize(unsigned(reg_freq_step), C_DATA_WIDTH));
            when 16#0C#      => rd_data <= std_logic_vector(
                resize(unsigned(reg_freq_step_down), C_DATA_WIDTH));
            when 16#10#  => rd_data <= (others => '0');
            when 16#14#  => rd_data <= (others => '0');
            when 16#18#  => rd_data <= (others => '0');
            when 16#1C#  => rd_data <= (
                0      => ready,
                1      => chirp_finished,
                2      => reg_do_chirp,
                3      => reg_repeat_chirp,
                4      => reg_enable_chirp_module,
                others => '0');

            when others => rd_data <= (others => '0');
        end case;
    end process;

end architecture;