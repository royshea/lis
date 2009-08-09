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
#include <stdlib.h>
#include <time.h>

/* Calculate the number of iterations required for number to satisfy the
 * Collatz conjecture.  Returns either the number of iterations required
 * or a -1 in the case of an error.  */
int collatz_conjecture(int number)
{
    int iterations = 0;

    /* Abort on non-positive inputs */
    if (number < 1)
        return -1;

    while (number != 1)
    {
        if (number % 2 == 0)
            number /= 2;
        else
            number = number * 3 + 1;

        /* Abort on integer overflows */
        if (number < 1)
            return -1;
        ++iterations;
    }
    return iterations;
}


/* Calculate the number of interations required for a (small) random
 * number to converge to 1 using the Collatz algorithm. */
int main(int argc, char **argv)
{
    int number;
    int iterations;

    srandom(time(0));
    number = (int) (random() % 2048);
    iterations = collatz_conjecture(number);
    printf("%d requires %d iterations\n", number, iterations);

    return 0;
}
