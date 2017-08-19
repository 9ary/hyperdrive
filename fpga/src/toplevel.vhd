library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.components.all;

entity hyperdrive is
    port (
        clk : in std_logic;
        led : out std_logic_vector(7 downto 0);
        --sw : in std_logic_vector(3 downto 0);

        -- Audio streaming
        --AISLR : in std_logic;
        --AISD : out std_logic;
        --AISCLK : in std_logic;

        -- Control signals
        DIHSTRB : in std_logic; -- Host strobe
        DIDIR : in std_logic; -- Bus direction
        DIBRK : in std_logic; -- Host cancel
        DIRSTB : in std_logic; -- Host reset

        DIDSTRB : out std_logic; -- Drive strobe
        DIERRB : out std_logic; -- Drive error
        DICOVER : out std_logic; -- Lid state

        -- Data
        DID : inout std_logic_vector(7 downto 0);

        -- FTDI SPI
        sclk : in std_logic;
        mosi : in std_logic;
        miso : out std_logic;
        scs : in std_logic
    );
end hyperdrive;

architecture Behavioral of hyperdrive is
    signal di_cmd : di_cmd_t;
    signal di_resetting : std_logic;
    signal di_cmd_ready : std_logic;
    signal di_wr_data : std_logic_vector(7 downto 0);
    signal di_ctrl : di_ctrl_t;

    signal host_data_in : std_logic_vector(7 downto 0);
    signal host_data_out : std_logic_vector(7 downto 0);
    signal host_enable : std_logic;
    signal host_strobe : std_logic;
    signal host_push : std_logic;
begin
    led <= (0 => DIDIR, others => '1');

    gc : di port map (
        clk => clk,
        cmd => di_cmd,
        resetting => di_resetting,
        cmd_ready => di_cmd_ready,
        wr_data => di_wr_data,
        ctrl => di_ctrl,
        DIHSTRB => DIHSTRB,
        DIDIR => DIDIR,
        DIBRK => DIBRK,
        DIRSTB => DIRSTB,
        DIDSTRB => DIDSTRB,
        DIERRB => DIERRB,
        DICOVER => DICOVER,
        DID => DID
    );

    ftdi : spi_slave port map (
        clk => clk,
        data_in => host_data_in,
        data_out => host_data_out,
        enable => host_enable,
        strobe => host_strobe,
        push => host_push,
        sclk => sclk,
        mosi => mosi,
        miso => miso,
        scs => scs
    );

    -- Top-level command processor
    -- Supervise all the things
    -- TODO
    -- When refactoring this to be interrupt-driven with a master MCU, allow reading the
    -- entire state (SR + DI command) with a single SPI transaction to minimize overhead
    -- Also implement all ACKs and status changes as a single write of the corresponding
    -- bits to the status register
    process (clk)
        type state_t is (
            cmd,
            read_di_cmd,
            write_di_data
        );
        variable state : state_t;

        variable read_di_cmd_count : natural range 0 to 12;
    begin
        if rising_edge(clk) then
            di_ctrl <= none;
            host_data_out <= x"FF";
            host_push <= '0';

            if host_enable = '0' then
                state := cmd;
            else
                case state is
                    when cmd =>
                        if host_strobe = '1' then
                            case host_data_in is
                                when x"01" =>
                                    host_data_out <= (
                                        0 => di_resetting,
                                        1 => di_cmd_ready,
                                        others => '0');
                                    host_push <= '1';

                                when x"03" =>
                                    di_ctrl <= lid_close;

                                when x"04" =>
                                    di_ctrl <= lid_open;

                                when x"05" =>
                                    di_ctrl <= ack_cmd;
                                    host_data_out <= di_cmd(0);
                                    host_push <= '1';
                                    read_di_cmd_count := 1;
                                    state := read_di_cmd;

                                when x"06" =>
                                    state := write_di_data;

                                when x"FF" => -- Special case for reads
                                    null;

                                when others => -- Invalid command
                                    host_data_out <= x"AA";
                                    host_push <= '1';
                            end case;
                        end if;

                    when read_di_cmd =>
                        if host_strobe = '1' then
                            host_data_out <= di_cmd(read_di_cmd_count);
                            host_push <= '1';
                            read_di_cmd_count := read_di_cmd_count + 1;
                            if read_di_cmd_count = 12 then
                                state := cmd;
                            end if;
                        end if;

                    when write_di_data =>
                        if host_strobe = '1' then
                            di_wr_data <= host_data_in;
                            di_ctrl <= bus_write;
                        end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;
