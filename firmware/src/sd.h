#ifndef INC_SD_H
#define INC_SD_H

#include <stdint.h>

void sd_init(void);
void sd_read(uint32_t lba, uint8_t *buf);

#endif
