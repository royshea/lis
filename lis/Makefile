# Ensure the correct enviornment exists
ifndef CILPATH
$(error Must set envioronment CILPATH to point to the root of your CIL installation)
endif

ifeq ($(MAKECMDGOALS),avr)
TARGET = avr
else ifeq ($(MAKECMDGOALS),msp430)
TARGET = msp430
else ifeq ($(MAKECMDGOALS),clean)
TARGET = none
else ifeq ($(MAKECMDGOALS),install)
TARGET = none
else
$(error Must specify as make target one of "avr" or "msp430")
endif

####
# Global build options
####
OCAMLMAKEFILE = OCamlMakefile
export LIBS = unix str cil
export INCDIRS = $(CILPATH)/obj/$(TARGET)_EMBEDDED

####
# Add projects here
####

define PROJ_extractcalls
SOURCES = extractcalls.ml
RESULT = $(TARGET)-extractcalls
endef
export PROJ_extractcalls

define PROJ_lis
SOURCES = lowlog.ml lis.ml
RESULT = $(TARGET)-lis
endef
export PROJ_lis


####
# Default project to bulid
####
ifndef SUBPROJS
	export SUBPROJS = extractcalls lis
endif


####
# General build rule
####
all: bc
	@echo Done

# NOTE: Change "bc" to "nc" to transition from byte-code (a little slow)
# to native-code

msp430: bc
	@echo Done

avr: bc
	@echo Done

install:
	cp *-extractcalls ../analysis/
	cp *-lis ../instrumentation/


# Catch-all target will be applied to all subprojects automatically
%:
	@$(MAKE) -f $(OCAMLMAKEFILE) subprojs SUBTARGET=$@
