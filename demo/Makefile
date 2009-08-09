# Author: Roy Shea (royshea@gmail.com)
# Date:  6/1/09

CC = gcc
CFLAGS = -g -Wall

SOURCES = demo.c
OBJECTS = $(SOURCES:.c=.o)

####
# Build Rules
# ####

all: demo

demo: $(OBJECTS)
	$(CC) $(CFLAGS) $? -o $@

.c.o:
	$(CC) -c $(CFLAGS) $< -o $@

####
# Cleaning up
####

clean:
	rm -f *.o

spotless: clean
	rm -f demo

####
# Special LIS target
####

LISGOAL = demo_lis
include Makefile.lis
