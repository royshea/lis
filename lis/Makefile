# Author: Roy Shea (royshea@gmail.com)
# Date:  6/1/09

# Ensure the correct enviornment exists
ifndef CILPATH
$(error Must set envioronment CILPATH to point to the root of your CIL installation)
endif


# Target specific build rules.  These are selected based on common uses
# within TinyOS that would use:
# - avr for mica2 or micaz
# - msp430 for telsob
# - not specified for the default x86_NATIVE target
ifeq ($(MAKECMDGOALS),avr)
TARGET = avr
export INCDIRS = $(CILPATH)/obj/$(TARGET)_EMBEDDED

else ifeq ($(MAKECMDGOALS),msp430)
TARGET = msp430
export INCDIRS = $(CILPATH)/obj/$(TARGET)_EMBEDDED

else ifeq ($(MAKECMDGOALS),clean)
TARGET = none

else
TARGET = x86
export INCDIRS = $(CILPATH)/obj/$(TARGET)_LINUX

endif

####
# Global build options
####
OCAMLMAKEFILE = OCamlMakefile
export LIBS = unix str cil

####
# LIS specific projects (additional projects can be added)
####
define PROJ_lis
SOURCES = lowlog.ml lis.ml
RESULT = $(TARGET)-lis
endef
export PROJ_lis


####
# Default project to bulid
####
ifndef SUBPROJS
	export SUBPROJS = lis
endif


####
# General build rule
####
all: clean bc
	@echo Done

# NOTE: Change "bc" to "nc" to transition from byte-code (a little slow)
# to native-code

msp430: clean bc
	@echo Done

avr: clean bc
	@echo Done

spotless: clean
	rm -f *-lis

# Catch-all target will be applied to all subprojects automatically
%:
	@$(MAKE) -f $(OCAMLMAKEFILE) subprojs SUBTARGET=$@
