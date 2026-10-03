library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sine_table_pkg.all;

entity chirp_engine_top_tb is
end entity;

architecture sim of chirp_engine_top_tb is

    -- AXI clock: 100 MHz, DAC clock: 125 MHz (asynchronous)
    constant AXI_CLK_PERIOD: time := 10 ns;
    constant DAC_CLK_PERIOD: time := 8 ns;

    constant ADDR_WIDTH: integer := 5;
    constant DATA_WIDTH: integer := 32;

    -- AXI clk/reset
    signal axi_clk: std_logic := '0';
    signal axi_resetn: std_logic := '0';

    -- DAC clk/reset
    signal dac_clk: std_logic := '0';
    signal dac_rst: std_logic := '1';

    -- AXI Write Address
    signal awaddr: std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal awvalid: std_logic := '0';
    signal awready: std_logic;
    -- AXI Write Data
    signal wdata: std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal wstrb: std_logic_vector(3 downto 0) := "1111";
    signal wvalid: std_logic := '0';
    signal wready: std_logic;
    -- AXI Write Response
    signal bresp: std_logic_vector(1 downto 0);
    signal bvalid: std_logic;
    signal bready: std_logic := '1';
    -- AXI Read Address
    signal araddr: std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal arvalid: std_logic := '0';
    signal arready: std_logic;
    -- AXI Read Data
    signal rdata: std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal rresp: std_logic_vector(1 downto 0);
    signal rvalid: std_logic;
    signal rready: std_logic := '1';

    signal chirp_start: std_logic;
    signal chirp_started: std_logic;
    signal chirp_finished: std_logic;
    signal ready: std_logic;
    signal repeat :std_logic:='0';
    -- DAC output
    signal dout: signed(AMP_WIDTH - 1 downto 0);

begin

    --------------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------------
    axi_clk <= not axi_clk after AXI_CLK_PERIOD / 2;
    dac_clk <= not dac_clk after DAC_CLK_PERIOD / 2;

    --------------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------------
    DUT: entity work.chirp_engine_top
        generic map (
            C_S_AXI_ADDR_WIDTH => ADDR_WIDTH,
            C_S_AXI_DATA_WIDTH => DATA_WIDTH
        )
        port map (
            S_AXI_ACLK     => axi_clk,
            S_AXI_ARESETN  => axi_resetn,
            S_AXI_AWADDR   => awaddr,
            S_AXI_AWVALID  => awvalid,
            S_AXI_AWREADY  => awready,
            S_AXI_WDATA    => wdata,
            S_AXI_WSTRB    => wstrb,
            S_AXI_WVALID   => wvalid,
            S_AXI_WREADY   => wready,
            S_AXI_BRESP    => bresp,
            S_AXI_BVALID   => bvalid,
            S_AXI_BREADY   => bready,
            S_AXI_ARADDR   => araddr,
            S_AXI_ARVALID  => arvalid,
            S_AXI_ARREADY  => arready,
            S_AXI_RDATA    => rdata,
            S_AXI_RRESP    => rresp,
            S_AXI_RVALID   => rvalid,
            S_AXI_RREADY   => rready,
            dac_clk        => dac_clk,
            dac_rst        => dac_rst,
            dout           => dout,
            chirp_start    => chirp_start,
            chirp_started  => chirp_started,
            chirp_finished => chirp_finished,
            ready          => ready
        );

    --------------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------------
    stim: process

        procedure axi_write (
            addr: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data: in std_logic_vector(DATA_WIDTH - 1 downto 0)
            ) is
        begin
            awaddr  <= addr;
            awvalid <= '1';
            wdata   <= data;
            wvalid  <= '1';
            wait until rising_edge(axi_clk) and awready = '1' and wready = '1';
            awvalid <= '0';
            wvalid  <= '0';
            wait until rising_edge(axi_clk) and bvalid = '1';
        end procedure;

        procedure axi_read (
            addr: in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data_out: out std_logic_vector(DATA_WIDTH - 1 downto 0)
            ) is
        begin
            araddr  <= addr;
            arvalid <= '1';
            wait until rising_edge(axi_clk) and arready = '1';
            arvalid <= '0';
            wait until rising_edge(axi_clk) and rvalid = '1';
            data_out := rdata;
        end procedure;

        variable read_result: std_logic_vector(DATA_WIDTH - 1 downto 0);

    begin
        ----------------------------------------------------------------
        -- Release resets (AXI and DAC independently)
        ----------------------------------------------------------------
        chirp_start <= '0';
        axi_resetn <= '0';
        dac_rst    <= '1';
        wait for 5 * AXI_CLK_PERIOD;

        axi_resetn <= '1';
        wait for 3 * AXI_CLK_PERIOD;

        dac_rst <= '0';
        wait for 3 * DAC_CLK_PERIOD;

        ----------------------------------------------------------------
        -- Write chirp parameters via AXI
        ----------------------------------------------------------------
        axi_write(std_logic_vector(to_unsigned(16#00#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(1000, DATA_WIDTH)));  -- start_freq

        axi_write(std_logic_vector(to_unsigned(16#04#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(6000, DATA_WIDTH)));  -- stop_freq

        axi_write(std_logic_vector(to_unsigned(16#08#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(10, DATA_WIDTH)));    -- freq_step

        axi_write(std_logic_vector(to_unsigned(16#0C#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(100, DATA_WIDTH)));   -- freq_step_down

        ----------------------------------------------------------------
        -- Read back and verify parameters
        ----------------------------------------------------------------
        axi_read(std_logic_vector(to_unsigned(16#00#, ADDR_WIDTH)), read_result);
        assert read_result = std_logic_vector(to_unsigned(1000, DATA_WIDTH))
            report "FAIL: start_freq readback" severity error;
        report "PASS: start_freq = " & integer'image(to_integer(unsigned(read_result)));

        axi_read(std_logic_vector(to_unsigned(16#04#, ADDR_WIDTH)), read_result);
        assert read_result = std_logic_vector(to_unsigned(6000, DATA_WIDTH))
            report "FAIL: stop_freq readback" severity error;
        report "PASS: stop_freq = " & integer'image(to_integer(unsigned(read_result)));

        ----------------------------------------------------------------
        -- Check status: should be ready=1 (idle) before trigger
        ----------------------------------------------------------------
        -- Allow a few dac_clk cycles for ready to propagate back
        wait for 10 * DAC_CLK_PERIOD;

        axi_read(std_logic_vector(to_unsigned(16#14#, ADDR_WIDTH)), read_result);
        assert read_result(0) = '1'
            report "FAIL: should be ready before chirp trigger" severity error;
        report "PASS: ready=1 before trigger";

        ----------------------------------------------------------------
        -- Trigger chirp via AXI (write 1 to do_chirp register)
        ----------------------------------------------------------------
        report "Triggering chirp...";
        axi_write(std_logic_vector(to_unsigned(16#10#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(1, DATA_WIDTH)));

        ----------------------------------------------------------------
        -- Wait for chirp to finish (poll status register)
        -- chirp_finished is bit 1 of status register at 0x14
        ----------------------------------------------------------------
        report "Waiting for chirp_finished...";
        loop
            wait for 20 * AXI_CLK_PERIOD;
            -- axi_read(std_logic_vector(to_unsigned(16#14#, ADDR_WIDTH)), read_result);
            axi_read(std_logic_vector(to_unsigned(16#1C#, ADDR_WIDTH)), read_result);
            exit when read_result(1) = '1';
        end loop;
        report "PASS: chirp_finished detected";

        ----------------------------------------------------------------
        -- Wait for engine to return to idle (ready=1)
        ----------------------------------------------------------------
        report "Waiting for ready after chirp...";
        loop
            wait for 20 * AXI_CLK_PERIOD;
            axi_read(std_logic_vector(to_unsigned(16#1C#, ADDR_WIDTH)), read_result);
            exit when read_result(0) = '1';
        end loop;
        report "PASS: ready=1 after chirp completed";

        ----------------------------------------------------------------
        -- Trigger a second chirp with different parameters
        ----------------------------------------------------------------
        axi_write(std_logic_vector(to_unsigned(16#00#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(2000, DATA_WIDTH)));  -- new start_freq

        axi_write(std_logic_vector(to_unsigned(16#08#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(50, DATA_WIDTH)));    -- new freq_step

        axi_write(std_logic_vector(to_unsigned(16#10#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(1, DATA_WIDTH)));     -- trigger

        report "Second chirp triggered, letting simulation run...";

        wait until ready = '1';
        wait for 1 us;


        -----------------------------------------------------------------
        -- Trigger a chirp from outside (not over axi)
        -----------------------------------------------------------------
        report "Trigger chirp from extern, 1 DAC CLK";
        chirp_start <= '1';
        wait for 1 * DAC_CLK_PERIOD;
        chirp_start <= '0';

        wait until ready = '1';
        wait for 1 us;

        report "Trigger chirp from extern, 1 AXI CLK";
        chirp_start <= '1';
        wait for 1 * AXI_CLK_PERIOD;
        chirp_start <= '0';
        wait for 1 us;


        -----------------------------------------------------------------
        -- Change Parameters while Chirp --> shall not change
        -----------------------------------------------------------------
        axi_write(std_logic_vector(to_unsigned(16#00#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(1000, DATA_WIDTH)));  -- start_freq

        axi_write(std_logic_vector(to_unsigned(16#04#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(6000, DATA_WIDTH)));  -- stop_freq

        axi_write(std_logic_vector(to_unsigned(16#08#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(10, DATA_WIDTH)));    -- freq_step

        axi_write(std_logic_vector(to_unsigned(16#0C#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(100, DATA_WIDTH)));   -- freq_step_down

        -- Trigger
        axi_write(std_logic_vector(to_unsigned(16#10#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(1, DATA_WIDTH)));     -- trigger

        wait for 1 us;

        axi_write(std_logic_vector(to_unsigned(16#08#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(50, DATA_WIDTH)));    -- freq_step

        axi_write(std_logic_vector(to_unsigned(16#00#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(3000, DATA_WIDTH)));  -- start_freq

        axi_write(std_logic_vector(to_unsigned(16#04#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(8000, DATA_WIDTH)));  -- stop_freq
        wait until ready = '1';
        wait for 1 us;
        -----------------------------------------------------------------
        -- Trigger a negative chirp
        -----------------------------------------------------------------
        axi_write(std_logic_vector(to_unsigned(16#00#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(6000, DATA_WIDTH)));  -- new start_freq

        axi_write(std_logic_vector(to_unsigned(16#04#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(2000, DATA_WIDTH)));  -- new stop_freq

        axi_write(std_logic_vector(to_unsigned(16#08#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(50, DATA_WIDTH)));    -- new freq_step

        wait for 200 ns;
        axi_write(std_logic_vector(to_unsigned(16#10#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(1, DATA_WIDTH)));     -- trigger

        wait for 1 us;
        axi_write(std_logic_vector(to_unsigned(16#10#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(1, DATA_WIDTH)));     -- trigger
        wait for 200 us;

        report "Simulation complete.";
        wait;
    end process;

end architecture;