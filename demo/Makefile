# Author: Roy Shea (royshea@gmail.com)
# Date:  6/1/09

CC = gcc
CPP = cpp
CFLAGS = -g -Wall

SOURCES = demo.c
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

LISGOAL = demo_lis
include Makefile.lis

