library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.components.all;

entity di is
    port (
        clk : in std_logic;

        cmd : out di_cmd_t; -- Command buffer
        cmd_ready : out std_logic;
        resetting : out std_logic;
        wr_data : in std_logic_vector(7 downto 0);
        ctrl : in di_ctrl_t;

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
    signal wr_buf_rst : std_logic;
    signal wr_buf_wr_en : std_logic;
    signal wr_buf_din : std_logic_vector(7 downto 0);
    signal wr_buf_rd_en : std_logic;
    signal wr_buf_dout : std_logic_vector(7 downto 0);
    signal wr_buf_empty : std_logic;
begin
    wr_buf : std_fifo generic map (
        data_width => 8,
        fifo_depth => 256
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
        variable DIRSTB_sync : std_logic;
        variable DID_sync : std_logic_vector(7 downto 0);

        variable cover_state : std_logic;

        variable busy : std_logic;
        variable cmd_bytes : natural range 0 to 12;

        variable host_ready : std_logic;
        variable strobe_count : natural range 0 to 7;
    begin
        if rising_edge(clk) then
            if DIRSTB_sync = '0' then
                DIDSTRB <= 'Z';
                DIERRB <= 'Z';
                DICOVER <= 'Z';
                DID <= (others => 'Z');

                cover_state := '1'; -- Open by default

                -- TODO investigate why we can't be "busy" on reset in the IPL
                -- Probably a timing issue
                busy := '0';
                cmd_bytes := 0;

                host_ready := '0';
                strobe_count := 0;
                cmd_ready <= '0';
            else
                -- TODO handle DIBRK

                wr_buf_wr_en <= '0';
                wr_buf_rd_en <= '0';

                case ctrl is
                    when none => null;
                    when set_ready => busy := '0';
                    when lid_close => cover_state := '0';
                    when lid_open => cover_state := '1';
                    when bus_write =>
                        wr_buf_din <= wr_data;
                        wr_buf_wr_en <= '1';
                    when ack_cmd => cmd_ready <= '0';
                end case;

                if DIDIR_sync = '0' then
                    -- Receiving
                    host_ready := '0';
                    strobe_count := 0;
                    cmd_ready <= '0';

                    if DIHSTRB_prev = '0' and DIHSTRB_sync = '1' and cmd_bytes /= 12 then
                        cmd(cmd_bytes) <= DID_sync;
                        cmd_bytes := cmd_bytes + 1;

                        if cmd_bytes = 9 then
                            busy := '1';
                        end if;
                    end if;

                    DID <= (others => 'Z');
                    DIDSTRB <= busy;
                else
                    -- Sending
                    if cmd_bytes = 12 then
                        cmd_ready <= '1';
                    end if;
                    busy := '0';
                    cmd_bytes := 0;

                    if DIHSTRB_sync = '0' then
                        host_ready := '1';
                    end if;

                    if host_ready = '1' and strobe_count = 0 and wr_buf_empty = '0' then
                        strobe_count := 7;
                        wr_buf_rd_en <= '1';
                    elsif strobe_count /= 0 then
                        strobe_count := strobe_count - 1;
                    end if;

                    DIDSTRB <= '1';
                    if strobe_count > 3 then
                        DIDSTRB <= '0';
                    end if;

                    DID <= wr_buf_dout;
                end if;

                DIERRB <= '1'; -- TODO
                DICOVER <= cover_state;
            end if;

            wr_buf_rst <= not host_ready;

            resetting <= not DIRSTB_sync;

            DIHSTRB_prev := DIHSTRB_sync;
            DIHSTRB_sync := DIHSTRB;
            DIDIR_sync := DIDIR;
            DIBRK_sync := DIBRK;
            DIRSTB_sync := DIRSTB;
            DID_sync := DID;
        end if;
    end process;
end drive;
