library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_lite_chirp_regs is
    generic (
        C_S_AXI_DATA_WIDTH: integer := 32;
        C_S_AXI_ADDR_WIDTH: integer := 5
    );
    port (
        S_AXI_ACLK         : in  std_logic;
        S_AXI_ARESETN      : in  std_logic;
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
        start_freq         : out std_logic_vector(15 downto 0);
        stop_freq          : out std_logic_vector(15 downto 0);
        freq_step          : out std_logic_vector(15 downto 0);
        freq_step_down     : out std_logic_vector(15 downto 0);
        do_chirp           : out std_logic;
        ready              : in  std_logic;
        chirp_finished     : in  std_logic;
        repeat_chirp       : out std_logic;
        enable_chirp_module: out std_logic
    );
end entity;

architecture rtl of axi_lite_chirp_regs is

    signal aw_en: std_logic;
    signal axi_awaddr: std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
    signal axi_awready: std_logic;
    signal axi_wready: std_logic;
    signal axi_bvalid: std_logic;
    signal axi_arready: std_logic;
    signal axi_rvalid: std_logic;
    signal axi_rdata: std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);

    signal slv_reg_wren: std_logic;
    signal write_addr: integer;
    signal read_addr: integer; -- signal, not variable
    signal rd_data: std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);

begin

    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= "00";
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= "00";
    S_AXI_RVALID  <= axi_rvalid;

    slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID;
    write_addr   <= to_integer(unsigned(axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto 0)));
    read_addr    <= to_integer(unsigned(S_AXI_ARADDR(C_S_AXI_ADDR_WIDTH - 1 downto 0)));
    --------------------------------------------------------------------------
    -- Register bank instance
    --------------------------------------------------------------------------
    i_chirp_reg: entity work.chirp_reg
        port map (
            clk                 => S_AXI_ACLK,
            resetn              => S_AXI_ARESETN,
            wr_en               => slv_reg_wren,
            wr_addr             => write_addr,
            wr_data             => S_AXI_WDATA,
            rd_addr             => read_addr,
            rd_data             => rd_data,
            ready               => ready,
            chirp_finished      => chirp_finished,
            start_freq          => start_freq,
            stop_freq           => stop_freq,
            freq_step           => freq_step,
            freq_step_down      => freq_step_down,
            do_chirp            => do_chirp,
            repeat_chirp        => repeat_chirp,
            enable_chirp_module => enable_chirp_module
        );

    --------------------------------------------------------------------------
    -- Write Address Handshake
    --------------------------------------------------------------------------
    p_aw: process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awready <= '0';
                aw_en       <= '1';
                axi_awaddr  <= (others => '0');
            else
                if axi_awready = '0' and S_AXI_AWVALID = '1' and
                    S_AXI_WVALID = '1' and aw_en = '1' then
                    axi_awready <= '1';
                    axi_awaddr  <= S_AXI_AWADDR;
                    aw_en       <= '0';
                elsif S_AXI_BREADY = '1' and axi_bvalid = '1' then
                    axi_awready <= '0';
                    aw_en       <= '1';
                else
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Write Data Handshake
    --------------------------------------------------------------------------
    p_w: process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_wready <= '0';
            else
                if axi_wready = '0' and S_AXI_WVALID = '1' and
                    S_AXI_AWVALID = '1' and aw_en = '1' then
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Write Response
    --------------------------------------------------------------------------
    p_b: process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_bvalid <= '0';
            else
                if axi_awready = '1' and S_AXI_AWVALID = '1' and
                    axi_wready = '1' and S_AXI_WVALID = '1' and
                    axi_bvalid = '0' then
                    axi_bvalid <= '1';
                elsif S_AXI_BREADY = '1' then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Read Address Handshake
    --------------------------------------------------------------------------
    p_ar: process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_arready <= '0';
            else
                if axi_arready = '0' and S_AXI_ARVALID = '1' then
                    axi_arready <= '1';
                else
                    axi_arready <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Read Data
    --------------------------------------------------------------------------
    p_r: process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rvalid <= '0';
                axi_rdata  <= (others => '0');
            else
                if axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0' then
                    axi_rvalid <= '1';
                    axi_rdata  <= rd_data;  -- rd_data is combinational from chirp_reg
                elsif S_AXI_RREADY = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture;