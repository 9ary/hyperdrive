library ieee;
use ieee.std_logic_1164.all;

library work;

package components is
    component std_fifo
        generic (
            constant data_width : positive := 8;
            constant fifo_depth : positive := 256
        );
        port (
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

    type di_cmd_t is array(11 downto 0) of std_logic_vector(7 downto 0);
    type di_ctrl_t is (
        none,
        set_ready,
        lid_open,
        lid_close
    );

    component di
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
    end component;
end components;

package body components is
end components;
