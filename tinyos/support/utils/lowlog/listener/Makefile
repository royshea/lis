CC = gcc
CFLAGS = -g -Wall -pedantic

SOURCES = timestampedlisten.c
OBJECTS = $(SOURCES:.c=.o)

INCLUDES = -I$(TOSROOT)/support/sdk/c/sf
LIBS = -L$(TOSROOT)/support/sdk/c/sf -lmote

all: timestampedlisten

timestampedlisten: $(OBJECTS)
	$(CC) $(CFLAGS) -Os $(OBJECTS) $(LIBS) -o $@

.c.o:
	$(CC) -c $(CFLAGS) $(INCLUDES) -Os $< -o $@

clean:
	rm -f *.o timestampedlisten

