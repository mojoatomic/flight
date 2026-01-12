/**
 * @file traffic_light.c
 * @brief P10-compliant traffic light state machine implementation
 *
 * All functions follow NASA JPL Power of 10 rules:
 * - ≥2 assertions per function
 * - No dynamic allocation
 * - Bounded operations
 * - Single pointer dereference
 */

#include "traffic_light.h"

/**
 * @brief Get duration for a given state
 * @param[in] state Traffic light state
 * @param[out] duration Pointer to store duration
 * @return STATUS_OK on success, STATUS_ERROR on invalid state
 */
static status_t get_state_duration(traffic_state_t state, uint32_t *duration)
{
    ASSERT(duration != NULL);

    status_t result = STATUS_OK;

    switch (state)
    {
        case TRAFFIC_STATE_RED:
            *duration = TRAFFIC_DURATION_RED;
            break;
        case TRAFFIC_STATE_GREEN:
            *duration = TRAFFIC_DURATION_GREEN;
            break;
        case TRAFFIC_STATE_YELLOW:
            *duration = TRAFFIC_DURATION_YELLOW;
            break;
        default:
            *duration = 0U;
            result = STATUS_ERROR;
            break;
    }

    ASSERT(result == STATUS_OK || result == STATUS_ERROR);
    return result;
}

/**
 * @brief Get next state in transition sequence
 * @param[in] current Current state
 * @param[out] next Pointer to store next state
 * @return STATUS_OK on success, STATUS_ERROR on invalid state
 */
static status_t get_next_state(traffic_state_t current, traffic_state_t *next)
{
    ASSERT(next != NULL);

    status_t result = STATUS_OK;

    switch (current)
    {
        case TRAFFIC_STATE_RED:
            *next = TRAFFIC_STATE_GREEN;
            break;
        case TRAFFIC_STATE_GREEN:
            *next = TRAFFIC_STATE_YELLOW;
            break;
        case TRAFFIC_STATE_YELLOW:
            *next = TRAFFIC_STATE_RED;
            break;
        default:
            *next = TRAFFIC_STATE_RED;
            result = STATUS_ERROR;
            break;
    }

    ASSERT(result == STATUS_OK || result == STATUS_ERROR);
    return result;
}

status_t traffic_light_init(traffic_light_t *tl)
{
    ASSERT(tl != NULL);

    status_t result = STATUS_OK;

    if (tl == NULL)
    {
        result = STATUS_INVALID_PARAM;
    }
    else
    {
        tl->state = TRAFFIC_STATE_RED;
        tl->elapsed_ticks = 0U;
    }

    ASSERT(result == STATUS_OK || result == STATUS_INVALID_PARAM);
    return result;
}

status_t traffic_light_tick(traffic_light_t *tl, traffic_state_t *state)
{
    ASSERT(tl != NULL);
    ASSERT(state != NULL);

    status_t result = STATUS_OK;

    if (tl == NULL)
    {
        result = STATUS_INVALID_PARAM;
    }
    else if (state == NULL)
    {
        result = STATUS_INVALID_PARAM;
    }
    else
    {
        tl->elapsed_ticks = tl->elapsed_ticks + 1U;

        uint32_t duration = 0U;
        result = get_state_duration(tl->state, &duration);

        if (result == STATUS_OK)
        {
            if (tl->elapsed_ticks >= duration)
            {
                traffic_state_t next_state = TRAFFIC_STATE_RED;
                result = get_next_state(tl->state, &next_state);

                if (result == STATUS_OK)
                {
                    tl->state = next_state;
                    tl->elapsed_ticks = 0U;
                }
            }
        }

        *state = tl->state;
    }

    ASSERT(result == STATUS_OK || result == STATUS_INVALID_PARAM || result == STATUS_ERROR);
    return result;
}

status_t traffic_light_get_state(const traffic_light_t *tl, traffic_state_t *state)
{
    ASSERT(tl != NULL);
    ASSERT(state != NULL);

    status_t result = STATUS_OK;

    if (tl == NULL)
    {
        result = STATUS_INVALID_PARAM;
    }
    else if (state == NULL)
    {
        result = STATUS_INVALID_PARAM;
    }
    else
    {
        *state = tl->state;
    }

    ASSERT(result == STATUS_OK || result == STATUS_INVALID_PARAM);
    return result;
}
