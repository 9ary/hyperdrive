#ifndef INC_SD_H
#define INC_SD_H

#include <stdint.h>

void sd_init(void);
void sd_read(uint32_t lba, uint32_t *buf);
void sd_stream(uint32_t offset, unsigned int size, volatile uint32_t *target);

#endif
