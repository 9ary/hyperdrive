#include <stdint.h>
#include <stdio.h>
#include "di.h"
#include "sd.h"
#include "spi.h"
#include "uart.h"

struct di
{
    volatile uint32_t out;
    volatile uint32_t status;
    volatile uint32_t cmdbuf[3];
};

volatile uint32_t *led = (uint32_t *) 0xFFFFFE00;
struct di *di = (struct di *) 0xFFFFFC00;

uint32_t did[8] = { 0, 0x20010608, 0x61000000, 0, 0, 0, 0, 0 };

int main()
{
    printf("\x0CHyperdrive initializing...\r\n");

    sd_init();

    // Not ready yet, no error, cover closed
    di->status = (1 << 2) | (1 << 1) | (0 << 0);

    for (volatile int i = 0; i < 1000000; i++);

    while (1)
    {
        // We're ready now
        di->status &= ~(1 << 2);
        while (di->status & (1 << 2));

        for (volatile int i = 0; i < 20000; i++);
        printf("%08x %08x %08x\r\n", di->cmdbuf[0], di->cmdbuf[1], di->cmdbuf[2]);


        switch (di->cmdbuf[0] >> 24)
        {
        case 0xA8:
            sd_stream(di->cmdbuf[1] << 2, di->cmdbuf[2], &di->out);
            break;

        case 0xE4:
            for (unsigned int i = 0; i < 4; i++)
                di->out = 0;
            break;

        case 0x12:
            for (unsigned int i = 0; i < 32; i++)
                di->out = ((uint8_t *) did)[i];
            break;

        default:
            printf("Unhandled command\r\n");
            for (unsigned int i = 0; i < 4; i++)
                di->out = 0;
        }
        for (volatile int i = 0; i < 10000; i++);
    }

    return 0;
}
