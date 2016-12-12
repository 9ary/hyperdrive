#include <stdint.h>

struct uart
{
    uint32_t c;
    uint32_t status;
};

volatile struct uart *uart = (struct uart *) 0xFFFFFF00;
uint32_t *led = (uint32_t *) 0xFFFFFE00;

int main()
{

    while (1)
    {
        if ((uart->status & 0x3) == 0x0)
        {
            uint32_t c = uart->c;
            uart->c = c;
            *led = ~*led;
        }
    }

    return 0;
}
