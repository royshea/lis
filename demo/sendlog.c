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
