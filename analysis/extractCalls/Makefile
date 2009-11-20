# Author: Roy Shea (royshea@gmail.com)
# Date:  11/19/09

# Ensure the correct enviornment exists
ifndef CILPATH
$(error Must set envioronment CILPATH to point to the root of your CIL installation)
endif

####
# Global build options
####
OCAMLMAKEFILE = OCamlMakefile
export LIBS = unix str cil
export INCDIRS = $(CILPATH)/obj/x86_LINUX

####
# LIS specific projects (additional projects can be added)
####
define PROJ_extractcalls
SOURCES = extractcalls.ml
RESULT = extractcalls
endef
export PROJ_extractcalls


####
# Default project to bulid
####
ifndef SUBPROJS
	export SUBPROJS = extractcalls
endif


####
# General build rule
####
all: clean bc
	@echo Done

# Catch-all target will be applied to all subprojects automatically
%:
	@$(MAKE) -f $(OCAMLMAKEFILE) subprojs SUBTARGET=$@
