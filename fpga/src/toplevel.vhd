library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpupkg.all;
use work.ZPUDevices.all;

entity hyperdrive is
    port
    (
        clk : in std_logic;
        led : out std_logic_vector(7 downto 0);
        --sw : in std_logic_vector(3 downto 0);

        tx : out std_logic;
        rx : in std_logic;

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
        DID : inout std_logic_vector(7 downto 0)
    );
end hyperdrive;

architecture Behavioral of hyperdrive is

    -- TODO: change these to reduce FPGA usage later on
    constant maxAddrBit : integer := 31;
    constant maxAddrBitBRAM : integer := 13;

    signal mem_busy : std_logic;
    signal mem_read : std_logic_vector(wordSize - 1 downto 0);
    signal mem_write : std_logic_vector(wordSize - 1 downto 0);
    signal mem_addr : std_logic_vector(maxAddrBit downto 0);
    signal mem_writeEnable : std_logic;
    signal mem_readEnable : std_logic;

    signal zpu_to_rom : ZPU_ToROM;
    signal zpu_from_rom : ZPU_FromROM;

    signal reset : std_logic;

    constant dev_count : natural := 2;
    signal bus_selects : ZPUMuxSelects(0 to dev_count-1);
    signal bus_outs : ZPUMuxDevOuts(0 to dev_count-1);
    signal bus_in : ZPUDeviceIn;

    signal uart_sel : std_logic;
    signal uart_outs : ZPUDeviceOut;

    signal gpio_sel : std_logic;
    signal gpio_outs : ZPUDeviceOut;

begin

    reset <= '0';

    DIDSTRB <= 'Z';
    DIERRB <= 'Z';
    DICOVER <= 'Z';
    DID <= (others => 'Z');

    rom : entity work.hyperdrive_rom
    generic map
    (
        maxAddrBitBRAM => maxAddrBitBRAM -- This needs to match the signal of the same name in the ZPU's instantiation.
    )
    port map
    (
        clk => clk,
        from_zpu => zpu_to_rom,
        to_zpu => zpu_from_rom
    );

    zpu: zpu_core_flex
    generic map
    (
        IMPL_MULTIPLY => true,
        IMPL_COMPARISON_SUB => true,
        IMPL_EQBRANCH => true,
        IMPL_STOREBH => false,
        IMPL_LOADBH => false,
        IMPL_CALL => true,
        IMPL_SHIFT => true,
        IMPL_XOR => true,
        REMAP_STACK => false, -- We're not using SDRAM so no need to remap the Boot ROM / Stack RAM
        EXECUTE_RAM => false, -- We don't need to execute code from external RAM.
        CACHE => true,
        maxAddrBit => maxAddrBit,
        maxAddrBitBRAM => maxAddrBitBRAM
    )
    port map
    (
        clk => clk,
        reset => reset,
        in_mem_busy => mem_busy,
        mem_read => mem_read,
        mem_write => mem_write,
        out_mem_addr => mem_addr,
        out_mem_writeEnable => mem_writeEnable,
        out_mem_readEnable => mem_readEnable,
        from_rom => zpu_from_rom,
        to_rom => zpu_to_rom
    );

    uart: entity work.zpu_uart
    port map
    (
        Clock => clk,
        ZSelect => uart_sel,
        ZPUBusIn => bus_in,
        ZPUBusOut => uart_outs,

        rx => rx,
        tx => tx
    );

    gpio: entity work.gpio
    port map
    (
        Clock => clk,
        ZSelect => gpio_sel,
        ZPUBusIn => bus_in,
        ZPUBusOut => gpio_outs,

        led => led
    );

    bus_in.Reset <= reset;
    bus_in.mem_write <= mem_write;
    bus_in.mem_addr <= mem_addr;
    bus_in.mem_writeEnable <= mem_writeEnable;
    bus_in.mem_readEnable <= mem_readEnable;

    bus_selects <= (
        0 => uart_sel,
        1 => gpio_sel
    );

    bus_outs <= (
        0 => uart_outs,
        1 => gpio_outs
    );

    busmux: entity work.ZPUBusMux
    generic map
    (
        Devices => dev_count
    )
    port map
    (
        Clock => clk,
        mem_readEnable => mem_readEnable,
        mem_writeEnable => mem_writeEnable,
        DevSelects => bus_selects,
        DevOuts => bus_outs,
        mem_busy_out => mem_busy,
        mem_read_out => mem_read
    );

    process(mem_addr, mem_writeEnable, mem_readEnable)
    begin
        uart_sel <= '0';
        gpio_sel <= '0';
    if mem_writeEnable = '1' or mem_readEnable = '1' then
        case mem_addr(31 downto 28) is
            when x"F" => -- peripheral space
                case mem_addr(11 downto 8) is -- select with 256-byte granularity
                    when x"F" =>
                        uart_sel <= '1';
                    when x"E" =>
                        gpio_sel <= '1';
                    when others => null;
                end case;
            when others => null;
      end case;
    end if;
    end process;

end Behavioral;
