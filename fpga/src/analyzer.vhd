library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.components.all;

entity analyzer is
    generic (
        constant sample_bytes : positive := 1;
        constant sample_depth : positive := 1024;
        constant pre_trigger_samples : positive := 0
    );
    port (
        clk : in std_logic;

        trigger : in std_logic;
        data : in std_logic_vector(sample_bytes * 8 - 1 downto 0);

        tx : out std_logic;
        rx : in std_logic
    );
end analyzer;

architecture analyzer of analyzer is
    signal uart_txd : std_logic_vector(7 downto 0);
    signal uart_txs : std_logic;
    signal uart_txa : std_logic;
    signal uart_rxd : std_logic_vector(7 downto 0);
    signal uart_rxs : std_logic;

    signal split_txd : std_logic_vector(sample_bytes * 8 - 1 downto 0);
    signal split_txs : std_logic;
    signal split_txa : std_logic;
begin
    host : uart generic map (
        baud => 200000,
        clock_frequency => 100e6
    ) port map (
        clock => clk,
        reset => '0',
        data_stream_in => uart_txd,
        data_stream_in_stb => uart_txs,
        data_stream_in_ack => uart_txa,
        data_stream_out => uart_rxd,
        data_stream_out_stb => uart_rxs,
        tx => tx,
        rx => rx
    );

    process (clk)
        type sample_buffer_t is array (0 to sample_depth - 1) of std_logic_vector(sample_bytes * 8 - 1 downto 0);
        variable sample_buffer : sample_buffer_t;
        variable i : natural range 0 to sample_depth - 1;

        type state_t is (
            wait_trigger,
            sample,
            upload
        );
        variable state : state_t := wait_trigger;

        variable samples : natural range 0 to sample_depth - 1;
    begin
        if rising_edge(clk) then
            split_txs <= '0';

            if state = wait_trigger or state = sample then
                sample_buffer(i) := data;
                i := (i + 1) rem sample_depth;
            end if;

            case state is
                when wait_trigger =>
                    if trigger = '1' then
                        samples := pre_trigger_samples;
                        state := sample;
                    end if;

                when sample =>
                    samples := (samples + 1) rem sample_depth;
                    if samples = 0 then
                        state := upload;
                    end if;

                when upload =>
                    if split_txa = '1' then
                        i := (i + 1) rem sample_depth;
                        samples := (samples + 1) rem sample_depth;
                        if samples = 0 then
                            state := wait_trigger;
                        end if;
                    end if;

                    split_txd <= sample_buffer(i);
                    split_txs <= '1';
            end case;
        end if;
    end process;

    process (clk)
        type state_t is (
            idle,
            active
        );
        variable state : state_t := idle;

        variable sr : std_logic_vector(sample_bytes * 8 - 1 downto 0);
        variable i : natural range 0 to sample_bytes - 1 := 0;
    begin
        if rising_edge(clk) then
            split_txa <= '0';
            uart_txs <= '0';

            case state is
                when idle =>
                    if split_txs = '1' then
                        sr := split_txd;
                        split_txa <= '1';
                        state := active;
                    end if;

                when active =>
                    if uart_txa = '1' then
                        sr := x"00" & sr(sample_bytes * 8 - 1 downto 8);
                        i := (i + 1) rem sample_bytes;
                        if i = 0 then
                            state := idle;
                        end if;
                    end if;

                    uart_txd <= sr(7 downto 0);
                    uart_txs <= '1';
            end case;
        end if;
    end process;
end analyzer;
