library ieee;
use ieee.std_logic_1164.all;

library work;

package components is
    component std_fifo
        generic (
            constant fallthrough : boolean := false;
            constant data_width : positive := 8;
            constant fifo_depth : positive := 256
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

            wr_en : in std_logic;
            din : in std_logic_vector(data_width - 1 downto 0);
            full : out std_logic;
            almost_full : out std_logic;

            rd_en : in std_logic;
            dout : out std_logic_vector(data_width - 1 downto 0);
            empty : out std_logic
        );
    end component;

    component spi_slave
        port (
            clk : in std_logic;

            data_in : out std_logic_vector(7 downto 0);
            data_out : in std_logic_vector(7 downto 0);
            enable : out std_logic;
            strobe : out std_logic;
            push : in std_logic;

            sclk : in std_logic;
            mosi : in std_logic;
            miso : out std_logic;
            scs : in std_logic
        );
    end component;

    type di_status_t is record
        cmd : std_logic;
        reset : std_logic;
        break : std_logic;
        lid : std_logic;
        err : std_logic;
    end record;

    type di_ctrl_t is record
        status : di_status_t;
        set_status : std_logic;
        write_data : std_logic_vector(7 downto 0);
        write_enable : std_logic;
        read_enable : std_logic;
    end record;

    component di
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
    end component;

    component analyzer is
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
    end component;

    component uart is
        generic (
            baud : positive;
            clock_frequency : positive
        );
        port (
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
