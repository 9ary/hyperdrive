#include <stdint.h>
#include "sd.h"
#include "spi.h"
#include "uart.h"

volatile uint32_t *led = (uint32_t *) 0xFFFFFE00;

uint32_t readbuf[512];
uint32_t asdf[512];

int main()
{
    puts("\x0CHyperdrive initializing...\r\n");

    sd_init();

    unsigned int i = 0;
    while (1)
    {
        for (unsigned int j = 0; j < 32; j++)
        {
            sd_read(i, readbuf);
            i++;
            for (unsigned int k = 0; k < 512; k++)
                asdf[k] = readbuf[k];
        }
        putc('.');
    }

    return 0;
}
