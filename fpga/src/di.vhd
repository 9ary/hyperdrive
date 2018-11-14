library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.components.all;

entity di is
    port (
        clk : in std_logic;

        status : out std_logic_vector(7 downto 0);
        cmd : out di_cmd_t; -- Command buffer
        ctrl : in di_ctrl_t;
        ctrl_arg : in std_logic_vector(7 downto 0);

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

    signal wr_buf_rst : std_logic;
    signal wr_buf_wr_en : std_logic;
    signal wr_buf_din : std_logic_vector(7 downto 0);
    signal wr_buf_rd_en : std_logic;
    signal wr_buf_dout : std_logic_vector(7 downto 0);
    signal wr_buf_empty : std_logic;
begin
    wr_buf : std_fifo generic map (
        data_width => 8,
        fifo_depth => 2 * 1024
    ) port map (
        clk => clk,
        rst => wr_buf_rst,
        wr_en => wr_buf_wr_en,
        din => wr_buf_din,
        full => open,
        rd_en => wr_buf_rd_en,
        dout => wr_buf_dout,
        empty => wr_buf_empty
    );

    process (clk)
        variable DIHSTRB_prev : std_logic;
        variable DIHSTRB_sync : std_logic;
        variable DIDIR_sync : std_logic;
        variable DIBRK_sync : std_logic;
        variable DIRSTB_prev : std_logic;
        variable DIRSTB_sync : std_logic;
        variable DID_sync : std_logic_vector(7 downto 0);

        variable status_cmd_ready : std_logic;
        variable status_reset : std_logic;
        -- TODO break
        variable status_cover : std_logic;
        -- TODO error

        variable ack : std_logic;
        variable cmd_bytes : natural range 0 to 12;

        variable host_ready : std_logic;
        variable strobe_count : natural range 0 to DIDSTRB_div - 1;
    begin
        if rising_edge(clk) then
            if DIRSTB_sync = '0' then
                DIDSTRB <= 'Z';
                DIERRB <= 'Z';
                DICOVER <= 'Z';
                DID <= (others => 'Z');

                status_cmd_ready := '0';
                status_reset := '0';
                -- TODO break
                status_cover := '1'; -- Open by default
                -- TODO error

                ack := '0';
                cmd_bytes := 0;

                host_ready := '0';
                strobe_count := 0;
            else
                if DIRSTB_prev = '0' then
                    status_reset := '1';
                end if;

                -- TODO handle DIBRK

                wr_buf_wr_en <= '0';
                wr_buf_rd_en <= '0';

                case ctrl is
                    when none => null;

                    when set_status =>
                        status_cmd_ready := status_cmd_ready and not ctrl_arg(0);
                        status_reset := status_reset and not ctrl_arg(1);
                        -- TODO break
                        status_cover := status_cover xor ctrl_arg(3);
                        -- TODO error

                    when bus_write =>
                        wr_buf_din <= ctrl_arg;
                        wr_buf_wr_en <= '1';
                end case;

                if DIDIR_sync = '0' then
                    -- Receiving
                    status_cmd_ready := '0';
                    host_ready := '0';
                    strobe_count := 0;

                    if DIHSTRB_prev = '0' and DIHSTRB_sync = '1' and cmd_bytes /= 12 then
                        cmd(cmd_bytes) <= DID_sync;
                        cmd_bytes := cmd_bytes + 1;

                        if cmd_bytes = 9 then
                            ack := '1';
                        end if;
                    end if;

                    DID <= (others => 'Z');
                    DIDSTRB <= ack;
                else
                    -- Sending
                    if cmd_bytes = 12 then
                        status_cmd_ready := '1';
                    end if;
                    ack := '0';
                    cmd_bytes := 0;

                    if DIHSTRB_sync = '0' then
                        host_ready := '1';
                    end if;

                    if host_ready = '1' and strobe_count = 0 and wr_buf_empty = '0' then
                        strobe_count := DIDSTRB_div - 1;
                        wr_buf_rd_en <= '1';
                    elsif strobe_count /= 0 then
                        strobe_count := strobe_count - 1;
                    end if;

                    DIDSTRB <= '1';
                    if strobe_count > DIDSTRB_div / 2 - 1 then
                        DIDSTRB <= '0';
                    end if;

                    DID <= wr_buf_dout;
                end if;

                DIERRB <= '1'; -- TODO
                DICOVER <= status_cover;
            end if;

            wr_buf_rst <= not host_ready;

            status <= (
                0 => status_cmd_ready,
                1 => status_reset,
                -- TODO break
                3 => status_cover,
                -- TODO error
                others => '0'
            );

            DIHSTRB_prev := DIHSTRB_sync;
            DIHSTRB_sync := DIHSTRB;
            DIDIR_sync := DIDIR;
            DIBRK_sync := DIBRK;
            DIRSTB_prev := DIRSTB_sync;
            DIRSTB_sync := DIRSTB;
            DID_sync := DID;
        end if;
    end process;
end drive;
