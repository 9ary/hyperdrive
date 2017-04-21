library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.components.all;

entity di is
    port (
        clk : in std_logic;

        cmd : out di_cmd_t; -- Command buffer
        resetting : out std_logic;
        listening : out std_logic;
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
begin
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
            else
                -- TODO handle DIBRK

                case ctrl is
                    when none => null;
                    when set_ready => busy := '0';
                    when lid_close => cover_state := '0';
                    when lid_open => cover_state := '1';
                end case;

                if DIDIR_sync = '0' then
                    -- Receiving
                    host_ready := '0';

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
                    busy := '0';
                    cmd_bytes := 0;

                    if DIHSTRB_sync = '0' then
                        host_ready := '1';
                    end if;

                    -- TODO handle replying properly
                    DIDSTRB <= '1';
                end if;

                listening <= host_ready;

                DIERRB <= '1'; -- TODO
                DICOVER <= cover_state;
            end if;

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
