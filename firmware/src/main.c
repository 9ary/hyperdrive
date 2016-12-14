#include <stdint.h>
#include "sd.h"
#include "spi.h"
#include "uart.h"

volatile uint32_t *led = (uint32_t *) 0xFFFFFE00;

uint8_t readbuf[512];

int main()
{
    puts("\x0CHyperdrive initializing...\r\n");

    sd_init();

    return 0;
}
