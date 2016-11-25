library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;

entity hyperdrive is

    port
    (
        clk : in std_logic;
        led : out std_logic_vector(7 downto 0);
        --sw : in std_logic_vector(3 downto 0);

        --ft_acbus : inout std_logic_vector(7 downto 0);
        --ft_adbus : inout std_logic_vector(7 downto 0)

        -- Audio streaming
        AISLR : in std_logic;
        AISD : out std_logic;
        AISCLK : in std_logic;

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

end hyperdrive;

architecture Behavioral of hyperdrive is

begin

    led <= (others => '0');

    AISD <= 'Z';

    DIDSTRB <= 'Z';
    DIERRB <= 'Z';
    DICOVER <= 'Z';

    DID <= (others => 'Z');

end Behavioral;
