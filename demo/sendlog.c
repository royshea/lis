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
 */

#include <stdio.h>
#include <inttypes.h>
#include <sys/time.h>
#include <time.h>

/* Dump log data out over stdout.  The log is prefixed with a timestamp
 * followed by space separetd hex formated log data. */
uint8_t send_log(void *data, uint8_t len)
{
    int i;
    char* log;
    struct timeval tv;

    /* Print time stamp */
    gettimeofday(&tv, NULL);
    fprintf(stderr, "%d.%d", (int)tv.tv_sec, (int)tv.tv_usec);

    /* Print log */
    log = (char *) data;
    for (i=0; i<len; i++)
        fprintf(stderr, " %02X", ((uint8_t *)log)[i]);
    fprintf(stderr, "\n");

    return 0;
}
