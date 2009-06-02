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

#ifndef LOGGER_H
#define LOGGER_H

#ifndef NO_SYSTEM_INCLUDES
#include <stdint.h>
#endif /* NO_SYSTEM_INCLUDES */


/* The default BIT_DATA_BUFFER length is set based on limitations of the
 * TinyOS operating system that was the initial target for the bitlog
 * library.  The current length is based on:
 *   28 (Active message payload size)
 * -  4 (bitlog header)
 * -  8 (CTP routing layer header)
 * = 16 (size of bitlog payload)
 * Note that if the Bitlog struct uses a uint8_t to describe the number
 * of valid bits in a packet, so BIT_DATA_BUFFER should be no larger
 * than 256 / 8 == 32, or the Bitlog data structure will need to be
 * revised to handle larger values of num_valid_bits.
 */
enum {BIT_DATA_BUFFER = 16};


/* Bitlog data packet.  A flushed packet may only be partially full, so
 * num_valid_bits is used to track how much of bit_data actually
 * contains data.
 */
typedef struct
{
    uint8_t num_valid_bits;
    uint8_t sequence_number;
    uint16_t source_addr;
    uint8_t bit_data[BIT_DATA_BUFFER];
} Bitlog;


void bitlog_init(uint16_t log_identifier);
void bitlog_flush(void);
void bitlog_write_data(uint32_t bit_data, uint8_t bit_width);

#endif /* LOGGER_H */
