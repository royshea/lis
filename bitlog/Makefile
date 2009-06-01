ifeq ($(MAKECMDGOALS),avr)
TARGET = avr
TARGETFLAGS = 
DEVICE = atmega128
else ifeq ($(MAKECMDGOALS),msp430)
TARGET = msp430
TARGETFLAGS = -specs=/usr/lib/ncc/tdspecs -mdisable-hwmul
DEVICE = msp430x1611
else ifneq ($(MAKECMDGOALS),clean)
$(error Must specify as make target one of "avr" or "msp430")
endif

CC = $(TARGET)-gcc
AR = $(TARGET)-ar
CFLAGS = -g -c -Wall -pedantic -DUSE_SYSTEM_INCLUDES
SOURCES = bitlog.c

OBJECTS = $(SOURCES:.c=.o)
LIB = libbitlog-$(TARGET).a

all:
	$(error Must specify as make target one of "avr" or "msp430")

msp430: $(LIB)

avr: $(LIB)

$(LIB): $(OBJECTS)
	$(AR) rcs $(LIB) $(OBJECTS)

.c.o:
	$(CC) $(TARGETFLAGS) -mmcu=$(DEVICE) $(CFLAGS) -Os $< -o $@

clean:
	rm -f *.o
