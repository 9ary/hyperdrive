library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity std_fifo is
    generic (
        constant fallthrough : boolean := false;
        constant data_width : positive := 8;
        constant fifo_depth : positive := 256;
        constant almost_full_thresh : positive := 4
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
end std_fifo;

architecture behavioral of std_fifo is

begin

    fifo_proc : process (clk)
        type fifo_memory is array (0 to fifo_depth - 1) of std_logic_vector (data_width - 1 downto 0);
        variable memory : fifo_memory;

        variable head : natural range 0 to fifo_depth - 1;
        variable tail : natural range 0 to fifo_depth - 1;

        variable looped : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                head := 0;
                tail := 0;

                looped := false;

                full <= '0';
                almost_full <= '0';
                empty <= '1';
            else

                if (rd_en = '1') then
                    if ((looped = true) or (head /= tail)) then
                        if not fallthrough then
                            dout <= memory(tail);
                        end if;

                        if (tail = fifo_depth - 1) then
                            tail := 0;
                            looped := false;
                        else
                            tail := tail + 1;
                        end if;
                    end if;
                end if;

                if (wr_en = '1') then
                    if ((looped = false) or (head /= tail)) then
                        memory(head) := din;

                        if (head = fifo_depth - 1) then
                            head := 0;
                            looped := true;
                        else
                            head := head + 1;
                        end if;
                    end if;
                end if;

                if fallthrough then
                    dout <= memory(tail);
                end if;

                if (head = tail) then
                    if looped then
                        full <= '1';
                    else
                        empty <= '1';
                    end if;
                else
                    empty <= '0';
                    full <= '0';

                    if (tail - head) mod fifo_depth <= almost_full_thresh then
                        almost_full <= '1';
                    else
                        almost_full <= '0';
                    end if;
                end if;

            end if;
        end if;
    end process;

end behavioral;
