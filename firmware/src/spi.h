#ifndef INC_SPI_H
#define INC_SPI_H

#include <stdint.h>

struct spi
{
    volatile uint32_t data;
    volatile uint32_t flags;
    volatile uint32_t fastdata;
};

void spi_cs(struct spi *spi, int state) __attribute__((always_inline));
uint32_t spi_dobyte(struct spi *spi, uint32_t byte) __attribute__((always_inline));
void spi_writebuf(struct spi *spi, const void *buf, unsigned int size);
void spi_readbuf(struct spi *spi, void *buf, unsigned int size);
void spi_readbuf32(struct spi *spi, void *buf, unsigned int size);

#endif
