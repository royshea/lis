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


int main(int argc, char **argv)
{
    int number;
    int iterations;

    printf("Entering main\n");

    srandom(time(0));
    number = (int) (random() % 2048);

    iterations = collatz_conjecture(number);

    printf("%d requires %d iterations\n", number, iterations);

    printf("Exiting main\n");
    return 0;
}
