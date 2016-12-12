library ieee;
use ieee.std_logic_1164.all;

library work;

package components is

    component std_fifo
        generic
        (
            constant data_width : positive := 8;
            constant fifo_depth : positive := 256
        );
        port
        (
            clk : in std_logic;
            rst : in std_logic;

            wr_en : in std_logic;
            din : in std_logic_vector(data_width - 1 downto 0);
            full : out std_logic;

            rd_en : in std_logic;
            dout : out std_logic_vector(data_width - 1 downto 0);
            empty : out std_logic
        );
    end component;

    component uart is
        generic
        (
            baud : positive;
            clock_frequency : positive
        );
        port
        (
            clock : in std_logic;
            reset : in std_logic;
            data_stream_in : in std_logic_vector(7 downto 0);
            data_stream_in_stb : in std_logic;
            data_stream_in_ack : out std_logic;
            data_stream_out : out std_logic_vector(7 downto 0);
            data_stream_out_stb : out std_logic;
            tx : out std_logic;
            rx : in std_logic
        );
    end component;

end components;

package body components is
end components;
