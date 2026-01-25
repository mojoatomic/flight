// RP2040 Pico C with violations
#include "pico/stdlib.h"
#include "hardware/gpio.h"

// N1: Blocking delay in ISR context
void gpio_callback(uint gpio, uint32_t events) {
    sleep_ms(100);  // Bad: blocking in ISR
}

// N2: Unbounded loop without watchdog
void bad_loop() {
    while(1) {
        // No watchdog_update()
        do_work();
    }
}

// N3: malloc in embedded (prefer static)
void bad_alloc() {
    char *buf = malloc(1024);
    use_buffer(buf);
}

int main() {
    stdio_init_all();
    gpio_set_irq_enabled_with_callback(15, GPIO_IRQ_EDGE_RISE, true, &gpio_callback);
    
    while(1) {
        tight_loop_contents();
    }
}
