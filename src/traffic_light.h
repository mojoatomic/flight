/**
 * @file traffic_light.h
 * @brief P10-compliant traffic light state machine
 *
 * Simple finite state machine for traffic light control.
 * Follows NASA JPL Power of 10 rules.
 */

#ifndef TRAFFIC_LIGHT_H
#define TRAFFIC_LIGHT_H

#include <stdint.h>
#include <stddef.h>

/**
 * @brief Duration constants (in ticks)
 */
#define TRAFFIC_DURATION_RED    30U
#define TRAFFIC_DURATION_GREEN  25U
#define TRAFFIC_DURATION_YELLOW 5U

/**
 * @brief Status codes for operations
 */
typedef enum {
    STATUS_OK = 0,
    STATUS_ERROR = -1,
    STATUS_INVALID_PARAM = -2
} status_t;

/**
 * @brief Traffic light states
 */
typedef enum {
    TRAFFIC_STATE_RED = 0,
    TRAFFIC_STATE_YELLOW = 1,
    TRAFFIC_STATE_GREEN = 2
} traffic_state_t;

/**
 * @brief Traffic light state machine structure
 */
typedef struct {
    traffic_state_t state;      /**< Current state */
    uint32_t elapsed_ticks;     /**< Ticks elapsed in current state */
} traffic_light_t;

/**
 * @brief Assertion failure handler (provided by system)
 * @param[in] file Source file name
 * @param[in] line Line number
 * @param[in] expr Failed expression
 */
extern void assert_failed(const char *file, int line, const char *expr);

/**
 * @brief Assertion macro for P10 Rule 5 compliance
 */
#define ASSERT(expr) \
    do { if (!(expr)) { assert_failed(__FILE__, __LINE__, #expr); } } while (0)

/**
 * @brief Initialize traffic light to RED state
 * @param[out] tl Pointer to traffic light structure
 * @return STATUS_OK on success, STATUS_INVALID_PARAM if tl is NULL
 * @pre tl must point to valid memory
 * @post tl->state == TRAFFIC_STATE_RED, tl->elapsed_ticks == 0
 */
status_t traffic_light_init(traffic_light_t *tl);

/**
 * @brief Advance time by one tick, handle state transitions
 * @param[in,out] tl Pointer to traffic light structure
 * @param[out] state Pointer to store current state after tick
 * @return STATUS_OK on success, STATUS_INVALID_PARAM if tl or state is NULL
 * @pre tl must be initialized
 * @post elapsed_ticks incremented, state transitioned if duration exceeded
 */
status_t traffic_light_tick(traffic_light_t *tl, traffic_state_t *state);

/**
 * @brief Get current state without advancing time
 * @param[in] tl Pointer to traffic light structure
 * @param[out] state Pointer to store current state
 * @return STATUS_OK on success, STATUS_INVALID_PARAM if tl or state is NULL
 * @pre tl must be initialized
 * @post state contains current traffic light state
 */
status_t traffic_light_get_state(const traffic_light_t *tl, traffic_state_t *state);

#endif /* TRAFFIC_LIGHT_H */
