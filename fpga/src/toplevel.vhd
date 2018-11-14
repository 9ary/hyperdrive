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

        DIDSTRB : inout std_logic; -- Drive strobe
        DIERRB : inout std_logic; -- Drive error
        DICOVER : inout std_logic; -- Lid state

        -- Data
        DID : inout std_logic_vector(7 downto 0);

        -- FTDI SPI
        sclk : in std_logic;
        mosi : in std_logic;
        miso : out std_logic;
        scs : in std_logic;
        int : out std_logic;

        -- PIC UART
        tx : out std_logic;
        rx : in std_logic
    );
end hyperdrive;

architecture Behavioral of hyperdrive is
    signal di_status : std_logic_vector(7 downto 0);
    signal di_cmd : di_cmd_t;
    signal di_ctrl : di_ctrl_t;
    signal di_ctrl_arg : std_logic_vector(7 downto 0);

    signal host_data_in : std_logic_vector(7 downto 0);
    signal host_data_out : std_logic_vector(7 downto 0);
    signal host_enable : std_logic;
    signal host_strobe : std_logic;
    signal host_push : std_logic;
begin
    led <= (0 => DIDIR, 7 => '1', others => '0');

    di_analyzer : analyzer generic map (
        sample_bytes => 2,
        pre_trigger_samples => 256
    ) port map (
        clk => clk,
        trigger => di_status(0),
        data => '0' & DIHSTRB & DIDIR & DIBRK & DIRSTB & DIDSTRB & DIERRB & DICOVER & DID,
        tx => tx,
        rx => rx
    );

    gc : di port map (
        clk => clk,
        status => di_status,
        cmd => di_cmd,
        ctrl => di_ctrl,
        ctrl_arg => di_ctrl_arg,
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
    process (clk)
        type state_t is (
            idle,
            read,
            write
        );
        variable state : state_t;

        variable read_count : natural range 0 to 12;
    begin
        if rising_edge(clk) then
            di_ctrl <= none;
            host_data_out <= x"FF";
            host_push <= '0';

            -- Bits cmd_ready, reset or break are set in the status register
            int <= di_status(2) or di_status(1) or di_status(0);

            if host_enable = '0' then
                state := idle;

                -- Instant readout of the status register
                host_data_out <= di_status;
                host_push <= '1';
            else
                if host_strobe = '1' then
                    case state is
                        when idle =>
                            -- TODO make sure that this is the value the future
                            -- master outputs while reading
                            if host_data_in = x"00" then
                                state := read;
                                -- First byte of the command here
                                host_data_out <= di_cmd(0);
                                host_push <= '1';
                                read_count := 1;
                            else
                                di_ctrl <= set_status;
                                di_ctrl_arg <= host_data_in;
                                state := write;
                            end if;

                        when read =>
                            host_data_out <= di_cmd(read_count);
                            host_push <= '1';
                            read_count := read_count + 1;
                            -- Overreading is undefined behavior

                        when write =>
                            di_ctrl <= bus_write;
                            di_ctrl_arg <= host_data_in;
                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;
