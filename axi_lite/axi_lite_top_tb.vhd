library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_lite_top_tb is
end entity;

architecture sim of axi_lite_top_tb is

    constant CLK_PERIOD: time    := 8 ns; -- 125 MHz
    constant ADDR_WIDTH: integer := 5;
    constant DATA_WIDTH: integer := 32;

    signal clk: std_logic := '0';
    signal resetn: std_logic := '0';

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

    -- Chirp engine side
    signal start_freq: std_logic_vector(15 downto 0);
    signal stop_freq: std_logic_vector(15 downto 0);
    signal freq_step: std_logic_vector(15 downto 0);
    signal freq_step_down: std_logic_vector(15 downto 0);
    signal do_chirp: std_logic;
    signal repeat_chirp: std_logic;
    signal ready: std_logic := '1';
    signal chirp_finished: std_logic := '0';
    signal enable_chirp_module: std_logic;

begin

    clk <= not clk after CLK_PERIOD / 2;

    --------------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------------
    DUT: entity work.axi_lite_chirp_regs
        port map (
            S_AXI_ACLK          => clk,
            S_AXI_ARESETN       => resetn,
            S_AXI_AWADDR        => awaddr,
            S_AXI_AWVALID       => awvalid,
            S_AXI_AWREADY       => awready,
            S_AXI_WDATA         => wdata,
            S_AXI_WSTRB         => wstrb,
            S_AXI_WVALID        => wvalid,
            S_AXI_WREADY        => wready,
            S_AXI_BRESP         => bresp,
            S_AXI_BVALID        => bvalid,
            S_AXI_BREADY        => bready,
            S_AXI_ARADDR        => araddr,
            S_AXI_ARVALID       => arvalid,
            S_AXI_ARREADY       => arready,
            S_AXI_RDATA         => rdata,
            S_AXI_RRESP         => rresp,
            S_AXI_RVALID        => rvalid,
            S_AXI_RREADY        => rready,
            start_freq          => start_freq,
            stop_freq           => stop_freq,
            freq_step           => freq_step,
            freq_step_down      => freq_step_down,
            do_chirp            => do_chirp,
            ready               => ready,
            chirp_finished      => chirp_finished,
            repeat_chirp        => repeat_chirp,
            enable_chirp_module => enable_chirp_module
        );

    --------------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------------
    stim: process

        -- AXI4-Lite write procedure
        procedure axi_write (
            addr: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data: in std_logic_vector(DATA_WIDTH - 1 downto 0)
            ) is
        begin
            awaddr  <= addr;
            awvalid <= '1';
            wdata   <= data;
            wvalid  <= '1';
            wait until rising_edge(clk) and awready = '1' and wready = '1';
            awvalid <= '0';
            wvalid  <= '0';
            -- wait for write response
            wait until rising_edge(clk) and bvalid = '1';
        end procedure;

        -- AXI4-Lite read procedure
        procedure axi_read (
            addr: in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data_out: out std_logic_vector(DATA_WIDTH - 1 downto 0)
            ) is
        begin
            araddr  <= addr;
            arvalid <= '1';
            wait until rising_edge(clk) and arready = '1';
            arvalid <= '0';
            wait until rising_edge(clk) and rvalid = '1';
            data_out := rdata;
        end procedure;

        variable read_result: std_logic_vector(DATA_WIDTH - 1 downto 0);

    begin
        -- Release reset
        resetn <= '0';
        wait for 5 * CLK_PERIOD;
        resetn <= '1';
        wait for 2 * CLK_PERIOD;

        ----------------------------------------------------------------
        -- Test 1: Write and read back start_freq (offset 0x00)
        ----------------------------------------------------------------
        axi_write(std_logic_vector(to_unsigned(16#00#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(1000, DATA_WIDTH)));

        axi_read(std_logic_vector(to_unsigned(16#00#, ADDR_WIDTH)), read_result);
        assert read_result = std_logic_vector(to_unsigned(1000, DATA_WIDTH))
            report "FAIL: start_freq readback mismatch" severity error;
        report "PASS: start_freq = " & integer'image(to_integer(unsigned(read_result)));

        ----------------------------------------------------------------
        -- Test 2: Write and read back stop_freq (offset 0x04)
        ----------------------------------------------------------------
        axi_write(std_logic_vector(to_unsigned(16#04#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(6000, DATA_WIDTH)));

        axi_read(std_logic_vector(to_unsigned(16#04#, ADDR_WIDTH)), read_result);
        assert read_result = std_logic_vector(to_unsigned(6000, DATA_WIDTH))
            report "FAIL: stop_freq readback mismatch" severity error;
        report "PASS: stop_freq = " & integer'image(to_integer(unsigned(read_result)));

        ----------------------------------------------------------------
        -- Test 3: Write and read back freq_step (offset 0x08)
        ----------------------------------------------------------------
        axi_write(std_logic_vector(to_unsigned(16#08#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(10, DATA_WIDTH)));

        axi_read(std_logic_vector(to_unsigned(16#08#, ADDR_WIDTH)), read_result);
        assert read_result = std_logic_vector(to_unsigned(10, DATA_WIDTH))
            report "FAIL: freq_step readback mismatch" severity error;
        report "PASS: freq_step = " & integer'image(to_integer(unsigned(read_result)));

        ----------------------------------------------------------------
        -- Test 4: Write and read back freq_step_down (offset 0x0C)
        ----------------------------------------------------------------
        axi_write(std_logic_vector(to_unsigned(16#0C#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(100, DATA_WIDTH)));

        axi_read(std_logic_vector(to_unsigned(16#0C#, ADDR_WIDTH)), read_result);
        assert read_result = std_logic_vector(to_unsigned(100, DATA_WIDTH))
            report "FAIL: freq_step_down readback mismatch" severity error;
        report "PASS: freq_step_down = " & integer'image(to_integer(unsigned(read_result)));

        ----------------------------------------------------------------
        -- Test 5: Check that do_chirp output pulses for one cycle
        ----------------------------------------------------------------
        axi_write(std_logic_vector(to_unsigned(16#10#, ADDR_WIDTH)),
            std_logic_vector(to_unsigned(1, DATA_WIDTH)));

        wait until rising_edge(clk);
        assert do_chirp = '1'
            report "FAIL: do_chirp not asserted" severity error;
        report "PASS: do_chirp asserted";

        wait until rising_edge(clk);
        assert do_chirp = '0'
            report "FAIL: do_chirp did not auto-clear" severity error;
        report "PASS: do_chirp auto-cleared";

        ----------------------------------------------------------------
        -- Test 6: Read status register (offset 0x14)
        --         ready=1, chirp_finished=0 -> expect 0x00000001
        ----------------------------------------------------------------
        ready          <= '1';
        chirp_finished <= '0';
        wait for CLK_PERIOD;

        axi_read(std_logic_vector(to_unsigned(16#14#, ADDR_WIDTH)), read_result);
        assert read_result(0) = '1' and read_result(1) = '0'
            report "FAIL: status register mismatch (ready)" severity error;
        report "PASS: status ready=1, chirp_finished=0";

        ----------------------------------------------------------------
        -- Test 7: Status with chirp_finished=1
        ----------------------------------------------------------------
        chirp_finished <= '1';
        wait for CLK_PERIOD;

        axi_read(std_logic_vector(to_unsigned(16#14#, ADDR_WIDTH)), read_result);
        assert read_result(0) = '1' and read_result(1) = '1'
            report "FAIL: status register mismatch (chirp_finished)" severity error;
        report "PASS: status ready=1, chirp_finished=1";

        ----------------------------------------------------------------
        report "All tests done";
        wait;
    end process;

end architecture;