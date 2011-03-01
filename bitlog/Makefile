# Author: Roy Shea (royshea@gmail.com)
# Date:  6/1/09

SOURCES = bitlog.c
CFLAGS = -g -Wall -pedantic -ansi
# CFLAGS += -DNO_SYSTEM_INCLUDES

# Target specific build rules.  These are selected based on common uses
# within TinyOS that would use:
# - avr for mica2 or micaz
# - msp430 for telsob
# - not specified for the default PC
ifeq ($(MAKECMDGOALS),avr)
CC = avr-gcc
AR = avr-ar
LIB = libbitlog-avr.a
TARGETFLAGS = -mmcu=atmega128

else ifeq ($(MAKECMDGOALS),msp430)
CC = msp430-gcc
AR = msp430-ar
LIB = libbitlog-msp430.a
TARGETFLAGS = -specs=/usr/lib/ncc/tdspecs -mdisable-hwmul -mmcu=msp430x1611

else ifneq ($(MAKECMDGOALS),clean)
CC = gcc
AR = ar
LIB = libbitlog.a

endif


OBJECTS = $(SOURCES:.c=.o)

####
# Target specific default rulse
####
all: clean $(LIB)

msp430: clean $(LIB)

avr: clean $(LIB)


####
# Generic build rules for constructing a library
####
$(LIB): $(OBJECTS)
	$(AR) rcs $(LIB) $(OBJECTS)

.c.o:
	$(CC) $(TARGETFLAGS) $(CFLAGS) -c -Os $< -o $@


####
# Clean up our mess...
####
clean:
	rm -f *.o

spotless: clean
	rm -f libbitlog*.a
