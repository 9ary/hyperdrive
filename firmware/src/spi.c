#include "spi.h"

#define SPI_FLAG_SSEL (1 << 0)
#define SPI_FLAG_BUSY (1 << 1)

void spi_cs(struct spi *spi, int state)
{
    if (state)
        spi->flags |=  SPI_FLAG_SSEL;
    else
        spi->flags &= ~SPI_FLAG_SSEL;
}

uint32_t spi_dobyte(struct spi *spi, uint32_t byte)
{
    spi->data = byte;
    return spi->fastdata;
}

void spi_writebuf(struct spi *spi, const void *buf, unsigned int size)
{
    const uint8_t *buf_ = buf;
    for (unsigned int i = 0; i < size; i++)
        spi_dobyte(spi, buf_[i]);
}

void spi_readbuf(struct spi *spi, void *buf, unsigned int size)
{
    uint8_t *buf_ = buf;
    for (unsigned int i = 0; i < size; i++)
        buf_[i] = spi_dobyte(spi, 0xFF);
}

void spi_readbuf32(struct spi *spi, void *buf, unsigned int size)
{
    uint32_t *buf_ = buf;
    for (unsigned int i = 0; i < size; i++)
        buf_[i] = spi_dobyte(spi, 0xFF);
}

void spi_stream32(struct spi *spi, volatile uint32_t *target, unsigned int size)
{
    for (unsigned int i = 0; i < size; i++)
        *target = spi_dobyte(spi, 0xFF);
}
