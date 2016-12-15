#include "uart.h"

#define RX_EMPTY (1 << 1)
#define TX_FULL (1 << 0)

struct uart
{
    volatile uint32_t c;
    volatile uint32_t status;
};

static struct uart *uart = (struct uart *) 0xFFFFFF00;

char uart_getc(void)
{
    while (uart->status & RX_EMPTY);
    return uart->c;
}

void uart_putc(char c)
{
    while (uart->status & TX_FULL);
    uart->c = c;
}
