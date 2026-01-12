# Domain: RP2040 Pico Embedded Systems

Raspberry Pi Pico (RP2040) dual-core embedded development with Pico SDK.

## Invariants

### MUST

#### Dual-Core Safety
- Core 0 owns safety-critical functions (watchdog, emergency systems)
- Core 1 handles complex logic (sensors, control loops, RC input)
- Use `multicore_fifo` for inter-core communication
- Implement cross-core heartbeat with timeout detection
- Core 0 code must be minimal (<500 lines) and cannot block

#### Initialization Sequence
- Initialize hardware before multicore launch
- Use startup handshake between cores
- Verify all peripherals before entering main loop
- Set hardware watchdog before Core 1 launch

#### Timing Constraints
- Core 0 safety loop: Fixed 100Hz (10ms period)
- Core 1 control loop: Fixed 50Hz (20ms period)
- Use `alarm_pool` or hardware timers, not busy-wait
- Document timing requirements in comments

#### Memory Safety
- All buffers statically allocated
- Define maximum sizes with `#define`
- No heap allocation (`malloc`/`free`)
- Use ring buffers for queues with fixed size

#### Hardware Access
- Single owner per peripheral (document in header)
- Use Pico SDK hardware abstractions
- Protect shared state with spinlocks (not mutexes)
- Check hardware status before operations

### NEVER

- `malloc()`, `free()` - static allocation only
- Blocking calls on Core 0 (safety core)
- Shared mutable state without spinlock protection
- Direct register access without SDK (use `hardware_*` APIs)
- Printf in interrupt handlers
- Floating point in safety-critical paths (use fixed-point)
- Recursive functions
- Unbounded loops

## Patterns

### Dual-Core Startup
```c
/* Core 0: Safety monitor - launches Core 1 */
int main(void)
{
    /* Hardware init */
    stdio_init_all();
    watchdog_enable(WATCHDOG_TIMEOUT_MS, true);
    
    /* Launch Core 1 */
    multicore_launch_core1(core1_entry);
    
    /* Wait for handshake */
    uint32_t handshake = multicore_fifo_pop_blocking();
    ASSERT(handshake == CORE1_READY_SIGNAL);
    
    /* Core 0 safety loop */
    while (true)
    {
        watchdog_update();
        safety_monitor_tick();
        sleep_ms(SAFETY_LOOP_PERIOD_MS);
    }
}

/* Core 1: Control systems */
void core1_entry(void)
{
    /* Core 1 init */
    sensors_init();
    control_init();
    
    /* Signal ready to Core 0 */
    multicore_fifo_push_blocking(CORE1_READY_SIGNAL);
    
    /* Core 1 control loop */
    while (true)
    {
        sensors_read();
        control_update();
        actuators_write();
        sleep_ms(CONTROL_LOOP_PERIOD_MS);
    }
}
```

### Inter-Core Heartbeat
```c
#define HEARTBEAT_TIMEOUT_MS 100U
static volatile uint32_t g_core1_heartbeat = 0U;
static spin_lock_t *g_heartbeat_lock;

/* Core 1: Send heartbeat */
void core1_heartbeat_send(void)
{
    uint32_t save = spin_lock_blocking(g_heartbeat_lock);
    g_core1_heartbeat = time_us_32();
    spin_unlock(g_heartbeat_lock, save);
}

/* Core 0: Check heartbeat */
bool core0_heartbeat_check(void)
{
    uint32_t save = spin_lock_blocking(g_heartbeat_lock);
    uint32_t last = g_core1_heartbeat;
    spin_unlock(g_heartbeat_lock, save);
    
    uint32_t elapsed_us = time_us_32() - last;
    return (elapsed_us < (HEARTBEAT_TIMEOUT_MS * 1000U));
}
```

### Hardware Watchdog
```c
#define WATCHDOG_TIMEOUT_MS 1000U

void watchdog_init_safe(void)
{
    /* Enable watchdog with pause on debug */
    watchdog_enable(WATCHDOG_TIMEOUT_MS, true);
}

void watchdog_feed(void)
{
    watchdog_update();
}

/* Call from Core 0 safety loop only */
void safety_tick(void)
{
    watchdog_feed();
    
    if (!core0_heartbeat_check())
    {
        /* Core 1 stalled - emergency action */
        emergency_surface();
    }
}
```

### Fixed-Size Ring Buffer
```c
#define RING_BUFFER_SIZE 64U

typedef struct {
    uint8_t data[RING_BUFFER_SIZE];
    uint32_t head;
    uint32_t tail;
    spin_lock_t *lock;
} ring_buffer_t;

status_t ring_buffer_write(ring_buffer_t *rb, uint8_t value)
{
    ASSERT(rb != NULL);
    
    uint32_t save = spin_lock_blocking(rb->lock);
    
    uint32_t next_head = (rb->head + 1U) % RING_BUFFER_SIZE;
    if (next_head == rb->tail)
    {
        spin_unlock(rb->lock, save);
        return STATUS_BUFFER_FULL;
    }
    
    rb->data[rb->head] = value;
    rb->head = next_head;
    
    spin_unlock(rb->lock, save);
    return STATUS_OK;
}
```

### GPIO with Interrupt
```c
#define LEAK_SENSOR_PIN 15U

static volatile bool g_leak_detected = false;

void leak_sensor_callback(uint gpio, uint32_t events)
{
    if (gpio == LEAK_SENSOR_PIN)
    {
        g_leak_detected = true;
        /* Set flag only - handle in main loop */
    }
}

void leak_sensor_init(void)
{
    gpio_init(LEAK_SENSOR_PIN);
    gpio_set_dir(LEAK_SENSOR_PIN, GPIO_IN);
    gpio_pull_up(LEAK_SENSOR_PIN);
    gpio_set_irq_enabled_with_callback(
        LEAK_SENSOR_PIN,
        GPIO_IRQ_EDGE_FALL,
        true,
        &leak_sensor_callback
    );
}

bool leak_sensor_check(void)
{
    return g_leak_detected;
}
```

### I2C Sensor Read (MS5837 Pressure)
```c
#define MS5837_ADDR 0x76U
#define I2C_TIMEOUT_US 10000U

status_t ms5837_read_pressure(i2c_inst_t *i2c, uint32_t *pressure_mbar)
{
    ASSERT(i2c != NULL);
    ASSERT(pressure_mbar != NULL);
    
    uint8_t cmd = MS5837_CMD_READ_PRESSURE;
    uint8_t data[3];
    
    int result = i2c_write_timeout_us(i2c, MS5837_ADDR, &cmd, 1, false, I2C_TIMEOUT_US);
    if (result != 1)
    {
        return STATUS_TIMEOUT;
    }
    
    result = i2c_read_timeout_us(i2c, MS5837_ADDR, data, 3, false, I2C_TIMEOUT_US);
    if (result != 3)
    {
        return STATUS_TIMEOUT;
    }
    
    *pressure_mbar = ((uint32_t)data[0] << 16) | ((uint32_t)data[1] << 8) | data[2];
    
    ASSERT(*pressure_mbar <= MAX_PRESSURE_MBAR);
    return STATUS_OK;
}
```

### PWM RC Input
```c
#define RC_CHANNEL_COUNT 6U
#define RC_MIN_US 1000U
#define RC_MAX_US 2000U
#define RC_TIMEOUT_MS 3000U

typedef struct {
    uint32_t pulse_us[RC_CHANNEL_COUNT];
    uint32_t last_update_ms;
    bool signal_valid;
} rc_input_t;

static rc_input_t g_rc_input;

void rc_input_update(uint32_t channel, uint32_t pulse_us)
{
    ASSERT(channel < RC_CHANNEL_COUNT);
    
    if (pulse_us >= RC_MIN_US && pulse_us <= RC_MAX_US)
    {
        g_rc_input.pulse_us[channel] = pulse_us;
        g_rc_input.last_update_ms = to_ms_since_boot(get_absolute_time());
        g_rc_input.signal_valid = true;
    }
}

bool rc_input_valid(void)
{
    uint32_t elapsed = to_ms_since_boot(get_absolute_time()) - g_rc_input.last_update_ms;
    return g_rc_input.signal_valid && (elapsed < RC_TIMEOUT_MS);
}
```

## Error Handling

### Status Codes
```c
typedef enum {
    STATUS_OK = 0,
    STATUS_ERROR = -1,
    STATUS_INVALID_PARAM = -2,
    STATUS_TIMEOUT = -3,
    STATUS_BUFFER_FULL = -4,
    STATUS_HARDWARE_FAULT = -5,
    STATUS_SIGNAL_LOST = -6,
    STATUS_EMERGENCY = -7
} status_t;
```

### Emergency Surface (Submarine-Specific)
```c
typedef enum {
    EMERGENCY_NONE = 0,
    EMERGENCY_SIGNAL_LOST,
    EMERGENCY_LOW_BATTERY,
    EMERGENCY_LEAK_DETECTED,
    EMERGENCY_DEPTH_EXCEEDED,
    EMERGENCY_PITCH_EXCEEDED,
    EMERGENCY_CORE_STALL
} emergency_reason_t;

void emergency_surface(emergency_reason_t reason)
{
    /* Disable normal control */
    control_disable();
    
    /* Open vent valve */
    gpio_put(VENT_VALVE_PIN, 1);
    
    /* Run pump to expel ballast */
    gpio_put(PUMP_DIRECTION_PIN, PUMP_EXPEL);
    gpio_put(PUMP_ENABLE_PIN, 1);
    
    /* Log reason */
    log_emergency(reason);
    
    /* This state cannot be cancelled - requires power cycle */
    while (true)
    {
        watchdog_update();
        sleep_ms(100U);
    }
}
```

## Project Structure

```
project/
├── src/
│   ├── main.c              # Core 0 entry, safety monitor
│   ├── core1.c             # Core 1 entry, control systems  
│   ├── safety/
│   │   ├── safety_monitor.c
│   │   ├── emergency.c
│   │   └── watchdog.c
│   ├── sensors/
│   │   ├── pressure.c      # MS5837
│   │   ├── imu.c           # MPU-6050
│   │   └── rc_input.c
│   ├── control/
│   │   ├── pid.c
│   │   ├── depth_control.c
│   │   └── pitch_control.c
│   └── actuators/
│       ├── ballast.c
│       ├── servo.c
│       └── valve.c
├── include/
│   ├── config.h            # Pin definitions, constants
│   ├── status.h            # Error codes
│   └── types.h             # Project types
├── test/
│   └── unit/               # Host-side unit tests
├── ci/
│   └── p10_check.py        # Power of 10 validator
└── CMakeLists.txt
```

## Validation Commands

```bash
# Build
mkdir build && cd build
cmake -DPICO_SDK_PATH=$PICO_SDK_PATH ..
make

# Static analysis
cppcheck --enable=all --error-exitcode=1 src/

# Power of 10 check
python3 ci/p10_check.py src/ --strict

# Unit tests (host)
cd test && ./run_tests.sh
```
