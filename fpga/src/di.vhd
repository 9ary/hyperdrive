library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.components.all;

entity di is
    port (
        clk : in std_logic;

        status : out di_status_t;
        ctrl : in di_ctrl_t;
        read_data : out std_logic_vector(7 downto 0);

        -- Control signals
        DIHSTRB : in std_logic; -- Host strobe
        DIDIR : in std_logic; -- Bus direction
        DIBRK : in std_logic; -- Host cancel
        DIRSTB : in std_logic; -- Host reset

        DIDSTRB : out std_logic; -- Drive strobe
        DIERRB : out std_logic; -- Drive error
        DICOVER : out std_logic; -- Lid state

        -- Data
        DID : inout std_logic_vector(7 downto 0)
    );
end di;

architecture drive of di is
    -- At 100MHz, /8 (12.5MHz) is the closest to the real drive's 38/3MHz
    -- /6 (16.667MHz) appears to work fine, and is what the Wii uses according to Dolphin
    -- /4 doesn't get even get close to booting
    -- It's possible to overclock the bus to at least 20MHz with the current wired setup
    -- by holding DIDSTRB high for 3 cycles, then low for 2 cycles. Needs more testing
    -- on the final design.
    constant DIDSTRB_div : natural := 8;

    signal DIHSTRB_sync : std_logic_vector(1 downto 0);
    signal DIDIR_sync : std_logic;
    signal DIBRK_sync : std_logic;
    signal DIRSTB_sync : std_logic;
    signal DID_sync : std_logic_vector(7 downto 0);

    signal rd_buf_rst : std_logic;
    signal rd_buf_wr_en : std_logic;
    signal rd_buf_din : std_logic_vector(7 downto 0);
    signal rd_buf_almost_full : std_logic;

    signal wr_buf_rst : std_logic;
    signal wr_buf_rd_en : std_logic;
    signal wr_buf_dout : std_logic_vector(7 downto 0);
    signal wr_buf_empty : std_logic;
begin
    rd_buf : std_fifo generic map (
        fallthrough => true,
        data_width => 8,
        fifo_depth => 2 * 1024
    ) port map (
        clk => clk,
        rst => rd_buf_rst,
        wr_en => rd_buf_wr_en,
        din => rd_buf_din,
        full => open,
        almost_full => rd_buf_almost_full,
        rd_en => ctrl.read_enable,
        dout => read_data,
        empty => open
    );

    wr_buf : std_fifo generic map (
        data_width => 8,
        fifo_depth => 2 * 1024
    ) port map (
        clk => clk,
        rst => wr_buf_rst,
        wr_en => ctrl.write_enable,
        din => ctrl.write_data,
        full => open,
        almost_full => open,
        rd_en => wr_buf_rd_en,
        dout => wr_buf_dout,
        empty => wr_buf_empty
    );

    process (clk)
        variable lid : std_logic;

        variable rd_bytes : natural range 0 to 12;

        variable write_ready : std_logic;
        variable strobe_count : natural range 0 to DIDSTRB_div - 1;
    begin
        if rising_edge(clk) then
            rd_buf_rst <= '0';
            wr_buf_rst <= '0';

            if DIRSTB_sync = '0' or DIBRK_sync = '1' then
                DIDSTRB <= 'Z';
                DIERRB <= 'Z';
                DICOVER <= 'Z';
                DID <= (others => 'Z');

                status.cmd <= '0';

                rd_buf_rst <= '1';
                rd_bytes := 0;

                wr_buf_rst <= '1';
                write_ready := '0';
                strobe_count := 0;

                if DIRSTB_sync = '0' then
                    status.reset <= '1';
                    status.err <= '0';
                    lid := '1'; -- Open by default
                elsif DIBRK_sync = '1' then
                    status.break <= '1';
                end if;
            else
                rd_buf_wr_en <= '0';
                wr_buf_rd_en <= '0';

                if ctrl.set_status = '1' then
                    if ctrl.status.cmd = '1' then
                        status.cmd <= '0';
                    end if;
                    if ctrl.status.reset = '1' then
                        status.reset <= '0';
                    end if;
                    if ctrl.status.break = '1' then
                        status.break <= '0';
                    end if;
                    lid := lid xor ctrl.status.lid;
                    -- TODO error
                end if;

                if DIDIR_sync = '0' then
                    if rd_bytes = 0 then
                        DIDSTRB <= '0';
                    end if;

                    if DIHSTRB_sync = "01" and rd_bytes /= 12 then
                        rd_buf_din <= DID_sync;
                        rd_buf_wr_en <= '1';
                        rd_bytes := rd_bytes + 1;

                        if rd_bytes = 9 then
                            DIDSTRB <= '1';
                        end if;
                        if rd_bytes = 12 then
                            status.cmd <= '1';
                        end if;
                    end if;

                    DID <= (others => 'Z');

                    wr_buf_rst <= '1';
                    write_ready := '0';
                    strobe_count := 0;
                else
                    if DIHSTRB_sync(0) = '0' then
                        write_ready := '1';
                    end if;

                    if write_ready = '1' and strobe_count = 0 and wr_buf_empty = '0' then
                        strobe_count := DIDSTRB_div - 1;
                        wr_buf_rd_en <= '1';
                    elsif strobe_count /= 0 then
                        strobe_count := strobe_count - 1;
                    end if;

                    DID <= wr_buf_dout;
                    DIDSTRB <= '1';
                    if strobe_count > DIDSTRB_div / 2 - 1 then
                        DIDSTRB <= '0';
                    end if;

                    rd_bytes := 0;
                end if;

                DIERRB <= '1'; -- TODO
                DICOVER <= lid;
            end if;

            status.lid <= lid;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            DIHSTRB_sync <= DIHSTRB_sync(0) & DIHSTRB;
            DIDIR_sync <= DIDIR;
            DIBRK_sync <= DIBRK;
            DIRSTB_sync <= DIRSTB;
            DID_sync <= DID;
        end if;
    end process;
end drive;
