#ifndef INC_SPI_H
#define INC_SPI_H

#include <stdint.h>

struct spi
{
    volatile uint32_t data;
    volatile uint32_t flags;
};

void spi_cs(struct spi *spi, int state);
uint8_t spi_dobyte(struct spi *spi, uint8_t byte);
void spi_writebuf(struct spi *spi, const void *buf, unsigned int size);
void spi_readbuf(struct spi *spi, void *buf, unsigned int size);

#endif
