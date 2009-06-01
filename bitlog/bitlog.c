/*
 * "Copyright (c) 2009 The Regents of the University  of California.
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written
 * agreement is hereby granted, provided that the above copyright
 * notice, the following two paragraphs and the author appear in all
 * copies of this software.
 *
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
 * FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
 * ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN
 * IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
 * PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
 * CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
 * UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Author: Roy Shea (royshea@gmail.com)
 * Date last modified: 2/27/09
 */

/*
 * Infrastructure for maintain bit logs.
 */

#include "bitlog.h"


/*
 * External function called by bitlog_flush to pass a bitlog log of
 * length len bytes (including the bitlog header) back to a user.  The
 * sendLog function should not maintain any pointer to data after
 * returning, and so it should either create a deep copy of the buffer
 * or otherwise handle the data before returning.
 */
extern uint8_t sendLog(void *data, uint8_t len);


/* Double buffer for logging. */
static Bitlog bitlog_buffer[2];


/* The log_status variable is used to prevent re-entry into the bitlog
 * library. */
enum {READY, FLUSHING};
uint8_t log_status = FLUSHING;


/* An identifier for the device (node, computer, software subsystem,
 * etc.) that is generating the log.  Its value is set through
 * bitlog_init.
 */
uint16_t device_address;


/* Sequence number of the current log.  The sequence number is also used
 * to index the bitlog_buffer that is currently being written into.
 */
static uint8_t current_sequence_number;


/* Prepare the next bitlog buffer. */
static prep_buffer(uint8_t sequence_number)
{
    uint8_t i;
    Bitlog *log;

    log = &bitlog_buffer[sequence_number % 2];
    log->sequence_number = sequence_number;
    log->source_addr = device_address;
    log->num_valid_bits = 0;
    for (i=0; i<BIT_DATA_BUFFER; i++)
        log->bit_data[i] = 0;
}


/* Initialize the bit logging system. */
void bitlog_init(uint16_t log_identifier)
{
    device_address = log_identifier;
    current_sequence_number = 0;
    prep_buffer(current_sequence_number);
    log_status = READY;
}


/* Flush the currently active Bitlog.
 *
 * TODO: Need to protect this (along the lines of the log_status variable)
 * in cases where bitlog_flush is being called from external user code.
 * Else the sendLog function could generate calls back into bitlog, and
 * that would be bad.
 */
void bitlog_flush(void)
{
    Bitlog *log;
    log = &bitlog_buffer[current_sequence_number % 2];
    sendLog(log, sizeof(Bitlog));
}


/*
 * Write data into log.
 *
 * It is assumed that data is right shifted.  I.e. if bit_width is 12,
 * then the 20 most significant bits of data will be ignored.
 */
void bitlog_write_data(uint32_t bit_data, uint8_t bit_width)
{
    Bitlog *log;
    uint8_t byte_index;
    uint8_t bit_index;
    uint8_t data8;
    uint8_t valid;

    /* Disable logging while flushing the buffer to prevent re-entry.
     *
     * NOTE: This is not currently being protected by an atomic section.
     * Platform specific ports may want to extend this with platform
     * specific protection to prevent race conditions.
     */
    if (log_status != READY)
        return;
    log_status = FLUSHING;

    /* Grab the currently active buffer */
    log = &bitlog_buffer[current_sequence_number % 2];

    /* Left align the incoming bit_data */
    bit_data <<= 32 - bit_width;

    /* Each iteration through the loop writes to the next (potentially
     * partially filled on the first time through the loop) 8-bit chunk
     * of the log.
     *
     * On the last time through this loop, bit_width will be less than
     * or equal to the computed bit_index.  This results in data8 being
     * generated and written into bit_data with trailing zeros.  This is
     * okay since num_valid_bits reflects the true value of bit_width,
     * causing the trailing zeros to be overwritten by the next call to
     * bitlog.
     */
    while (bit_width != 0) {

        /* Flush buffer if needed. */
        if (log->num_valid_bits == 8 * BIT_DATA_BUFFER)
        {
            uint8_t i;
            bitlog_flush();
            ++current_sequence_number;
            prep_buffer(current_sequence_number);
        }

        /* Find index into bit_data */
        byte_index = log->num_valid_bits / 8;
        bit_index = log->num_valid_bits % 8;

        /* Calculate how many bits of data we can write in this
         * iteration through the loop.
         */
        valid = (8 - bit_index) < bit_width ? (8 - bit_index) : bit_width;

        /* Shift bit_data to grab the next chunk that will be written to
         * the log.
         */
        data8 = bit_data >> (24 + bit_index);

        /* Insert into bit_data. */
        log->bit_data[byte_index] |= data8;

        /* Update state for next iteration through the loop. */
        bit_data <<= valid;
        bit_width -= valid;
        log->num_valid_bits += valid;
    }

    log_status = READY;
    return;
}

