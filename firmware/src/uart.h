#ifndef INC_UART_H
#define INC_UART_H

#include <stdint.h>

char getc(void);
void putc(char c);
void puts(const char *str);

#endif
