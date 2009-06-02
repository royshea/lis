# Author: Roy Shea (royshea@gmail.com)
# Date:  6/1/09

SOURCES = demo.c
CFLAGS = -g -Wall -pedantic

CC = gcc
OBJECTS = $(SOURCES:.c=.o)

all: demo

demo: $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o $@

.c.o:
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	rm -f *.o

spotless: clean
	rm -f demo
