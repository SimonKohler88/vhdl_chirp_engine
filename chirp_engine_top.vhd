library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sine_table_pkg.all;

entity chirp_engine_top is
    generic (
        C_S_AXI_ADDR_WIDTH: integer := 5;
        C_S_AXI_DATA_WIDTH: integer := 32
    );
    port (
        -- Clock and reset (AXI convention: active-low reset)
        S_AXI_ACLK         : in  std_logic;
        S_AXI_ARESETN      : in  std_logic;

        -- AXI4-Lite Slave
        S_AXI_AWADDR       : in  std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
        S_AXI_AWVALID      : in  std_logic;
        S_AXI_AWREADY      : out std_logic;
        S_AXI_WDATA        : in  std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
        S_AXI_WSTRB        : in  std_logic_vector((C_S_AXI_DATA_WIDTH / 8) - 1 downto 0);
        S_AXI_WVALID       : in  std_logic;
        S_AXI_WREADY       : out std_logic;
        S_AXI_BRESP        : out std_logic_vector(1 downto 0);
        S_AXI_BVALID       : out std_logic;
        S_AXI_BREADY       : in  std_logic;
        S_AXI_ARADDR       : in  std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
        S_AXI_ARVALID      : in  std_logic;
        S_AXI_ARREADY      : out std_logic;
        S_AXI_RDATA        : out std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
        S_AXI_RRESP        : out std_logic_vector(1 downto 0);
        S_AXI_RVALID       : out std_logic;
        S_AXI_RREADY       : in  std_logic;

        -- DAC sample clock (independent from AXI clock)
        dac_clk            : in  std_logic;
        dac_rst            : in  std_logic; -- active-high, synchronous to dac_clk

        -- Sine wave output (in dac_clk domain)
        dout               : out signed(AMP_WIDTH - 1 downto 0);
        chirp_start        : in std_logic;
        chirp_started      : out std_logic;
        chirp_finished     : out std_logic;
        ready              : out std_logic;
        enable_chirp_module: out std_logic
    );
end entity;

architecture rtl of chirp_engine_top is

    -- Internal wires between AXI regs and chirp engine
    signal w_start_freq: std_logic_vector(15 downto 0);
    signal w_stop_freq: std_logic_vector(15 downto 0);
    signal w_freq_step: std_logic_vector(15 downto 0);
    signal w_freq_step_down: std_logic_vector(15 downto 0);
    signal w_do_chirp: std_logic; -- AXI clock domain
    signal do_chirp_sync: std_logic_vector(1 downto 0) := "00";

    -- Active-high reset for AXI domain
    signal axi_rst: std_logic;
    signal w_ready: std_logic;
    signal w_chirp_finished: std_logic;
    signal repeat_chirp: std_logic:='0';

    -- Active-high reset for chirp_engine
    signal rst: std_logic;

begin

    axi_rst <= not S_AXI_ARESETN;

    --------------------------------------------------------------------------
    -- AXI4-Lite register interface
    --------------------------------------------------------------------------
    i_axi_regs: entity work.axi_lite_chirp_regs
        generic map (
            C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
            C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH
        )
        port map (
            S_AXI_ACLK          => S_AXI_ACLK,
            S_AXI_ARESETN       => S_AXI_ARESETN,
            S_AXI_AWADDR        => S_AXI_AWADDR,
            S_AXI_AWVALID       => S_AXI_AWVALID,
            S_AXI_AWREADY       => S_AXI_AWREADY,
            S_AXI_WDATA         => S_AXI_WDATA,
            S_AXI_WSTRB         => S_AXI_WSTRB,
            S_AXI_WVALID        => S_AXI_WVALID,
            S_AXI_WREADY        => S_AXI_WREADY,
            S_AXI_BRESP         => S_AXI_BRESP,
            S_AXI_BVALID        => S_AXI_BVALID,
            S_AXI_BREADY        => S_AXI_BREADY,
            S_AXI_ARADDR        => S_AXI_ARADDR,
            S_AXI_ARVALID       => S_AXI_ARVALID,
            S_AXI_ARREADY       => S_AXI_ARREADY,
            S_AXI_RDATA         => S_AXI_RDATA,
            S_AXI_RRESP         => S_AXI_RRESP,
            S_AXI_RVALID        => S_AXI_RVALID,
            S_AXI_RREADY        => S_AXI_RREADY,
            start_freq          => w_start_freq,
            stop_freq           => w_stop_freq,
            freq_step           => w_freq_step,
            freq_step_down      => w_freq_step_down,
            do_chirp            => w_do_chirp,
            ready               => w_ready,
            chirp_finished      => w_chirp_finished,
            repeat_chirp        => repeat_chirp,
            enable_chirp_module => enable_chirp_module
        );

    -------------------------------------------------------------------------- AI
    -- CDC: synchronize do_chirp pulse into dac_clk domain
    -- do_chirp is a single-cycle pulse from the AXI register auto-clear,
    -- so a 2-FF synchronizer is sufficient.
    --------------------------------------------------------------------------
    p_cdc_sync: process(dac_clk)
    begin
        if rising_edge(dac_clk) then
            if dac_rst = '1' then
                do_chirp_sync <= "00";
            else
                do_chirp_sync <= do_chirp_sync(0) & (w_do_chirp or chirp_start);
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Chirp engine (dac_clk domain)
    -- Parameter registers (start_freq etc.) are quasi-static:
    -- they are written by the user before triggering, so no CDC needed.
    --------------------------------------------------------------------------

    chirp_started <= do_chirp_sync(1);
    chirp_finished <= w_chirp_finished;
    ready <= w_ready;

    i_chirp_engine: entity work.chirp_engine
        generic map (
            G_PHASE_WIDTH => PHASE_WIDTH,
            G_AMP_WIDTH   => AMP_WIDTH
        )
        port map (
            clk            => dac_clk,
            rst            => dac_rst,
            do_chirp       => do_chirp_sync(1),
            start_freq     => unsigned(w_start_freq),
            stop_freq      => unsigned(w_stop_freq),
            freq_step      => unsigned(w_freq_step),
            freq_step_down => unsigned(w_freq_step_down),
            repeat         => repeat_chirp,
            chirp_finished => w_chirp_finished,
            ready          => w_ready,
            dout           => dout
        );

end architecture;
