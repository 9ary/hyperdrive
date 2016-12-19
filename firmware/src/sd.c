#include <stdio.h>
#include "sd.h"
#include "spi.h"
#include "uart.h"

static struct spi *sd = (struct spi *) 0xFFFFFD00;

static int is_sdhc;

static uint32_t do_cmd(uint32_t idx, uint32_t arg, uint32_t crc)
{
    // Wait for card ready
    uint32_t ret = 0;
    if (idx)
        while ((ret = spi_dobyte(sd, 0xFF)) == 0);

    spi_dobyte(sd, idx | 0x40);
    spi_writebuf(sd, &arg, 4);
    spi_dobyte(sd, crc);

    ret = 0xFF;
    while ((ret = spi_dobyte(sd, 0xFF)) == 0xFF);
    return ret;
}

void sd_init(void)
{
    // Powerup init
    spi_cs(sd, 1);
    for (unsigned int i = 0; i < 10; i++)
        spi_dobyte(sd, 0xFF);

    // Keep this fucker active, it's the only card on the bus
    spi_cs(sd, 0);

    // Reset the card
    do_cmd(0, 0, 0x95); // CMD0, CRC needs to be correct since we're still in native mode

    // Check for SDCv2+
    uint32_t r = do_cmd(8, 0x1AA, 0x87);
    if (r == 1) // Are we in idle mode with no other errors?
    {
        uint32_t r7;
        spi_readbuf(sd, &r7, 4);

        if ((r7 & 0xFFF) == 0x1AA)
            puts("SDCv2+ compatible with voltage range");
        else
            puts("SDCv2+ incompatible with voltage range");
    }
    else
    {
        puts("SDCv1/MMC");
    }

    puts("Starting card init");
    r = 1;
    while (r != 0)
    {
        do_cmd(55, 0, 1); // SPI mode now, don't care about CRC
        r = do_cmd(41, (1 << 30), 1);
    }

    is_sdhc = 0;
    r = do_cmd(58, 0, 1);
    if (r == 0)
    {
        uint32_t r3;
        spi_readbuf(sd, &r3, 4);

        if (r3 & (1 << 30))
        {
            puts("Card is SDHC");
            is_sdhc = 1;
        }
    }

    puts("SD init done");
}

void sd_read(uint32_t lba, uint32_t *buf)
{
    if (is_sdhc == 0)
        lba = lba << 9;

    do_cmd(17, lba, 1);

    uint32_t byte;
    while ((byte = spi_dobyte(sd, 0xFF)) != 0xFE);
    spi_readbuf32(sd, buf, 512);

    // Discard the CRC bytes
    spi_dobyte(sd, 0xFF);
    spi_dobyte(sd, 0xFF);
}

void sd_stream(uint32_t offset, unsigned int size, volatile uint32_t *target)
{
    while (size)
    {
        uint32_t lba = offset >> 9;
        if (is_sdhc == 0)
            lba = lba << 9;

        do_cmd(17, lba, 1);
        uint32_t byte;
        while ((byte = spi_dobyte(sd, 0xFF)) != 0xFE);


        uint32_t discard = offset & (512 - 1);
        unsigned int n = (size + discard > 512) ? 512 - discard : size;

        for (unsigned int i = 0; i < discard; i++)
            spi_dobyte(sd, 0xFF);

        sd->fastdata = n;

        discard = 512 - n - discard;
        for (unsigned int i = 0; i < discard; i++)
            spi_dobyte(sd, 0xFF);

        // Discard the CRC bytes
        spi_dobyte(sd, 0xFF);
        spi_dobyte(sd, 0xFF);

        size -= n;
        offset += n;
    }
}
