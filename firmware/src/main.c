#include <stdint.h>
#include <stdio.h>
#include "di.h"
#include "sd.h"
#include "spi.h"
#include "uart.h"

volatile uint32_t *led = (uint32_t *) 0xFFFFFE00;
volatile uint32_t *di = (uint32_t *) 0xFFFFFC00;

uint32_t cmdbuf[3];
uint32_t did[8] = { 0, 0x20161215, 0x61000000, 0, 0, 0, 0, 0 };

int main()
{
    printf("\x0CHyperdrive initializing...\r\n");

    sd_init();

    for (volatile int i = 0; i < 2000000; i++);

    di[1] = (0 << 2) | (1 << 1);

    while (1)
    {
        printf("Waiting\r\n");
        for (unsigned int i = 0; i < 3; i++)
        {
            uint32_t w = 0;
            for (unsigned int j = 0; j < 4; j++)
            {
                uint32_t b = *di;
                w <<= 8;
                w |= b & 0xFF;
            }
            cmdbuf[i] = w;
        }

        printf("%08x %08x %08x\r\n", cmdbuf[0], cmdbuf[1], cmdbuf[2]);
        switch (cmdbuf[0] >> 24)
        {
        case 0xA8:
            sd_stream(cmdbuf[1] << 2, cmdbuf[2], di);
            break;

        case 0xE4:
            for (unsigned int i = 0; i < 4; i++)
                *di = 0;
            break;

        case 0x12:
            for (unsigned int i = 0; i < 32; i++)
                *di = ((uint8_t *) did)[i];
            break;

        case 0xE0:
            for (unsigned int i = 0; i < 4; i++)
                *di = 0;
            di[1] |= 1 << 1;
            break;

        case 0xE3:
            for (unsigned int i = 0; i < 4; i++)
                *di = 0;
            break;

        default:
            printf("Unhandled command\r\n");
        }

        di[1] &= ~(1 << 2);
    }

    return 0;
}
