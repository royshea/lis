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
