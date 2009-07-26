#!/bin/sh

# Install script for use with LIS.
#
# The script takes as input a single path specifying the base directory
# that LIS and support tools will be installed into.
#
# The installation assumes that OCaml and python are already installed on
# the system.  On Ubuntu distrobutions this can be accomplished via:
#
# sudo apt-get install python ocaml
#
# Author: Roy Shea (roy@cs.ucla.edu)
# Date: July 2009


set -o nounset
set -o errexit


####
# Get a copy of LIS
####
get_lis ()
{
    cd $BASE
    wget http://projects.nesl.ucla.edu/~rshea/lis/lis-core.tgz
    tar -xzvf lis-core.tgz
    cd -
}


####
# Get a copy of CIL
####
get_cil ()
{
    cd $BASE
    wget http://manju.cs.berkeley.edu/cil/distrib/cil-1.3.6.tar.gz
    tar -xzvf cil-1.3.6.tar.gz
    cd -
}


####
# Setup and build architecture specific versions of CIL sources
####
build_cil ()
{
    # Setup source for different targets
    cp -r cil 1.3.6-targets-native

    for PLAT in avr msp430
    do
        cp -r cil 1.3.6-targets-$PLAT
        cd $BASE/1.3.6-targets-$PLAT
        patch -p1 < $BASE/lis-core/install/cil-$PLAT.diff
        cd -
    done

    # Build source for different targets
    cd $BASE/1.3.6-targets-native
    autoconf && ./configure && make
    cd -

    for PLAT in avr msp430
    do
        cd $BASE/1.3.6-targets-$PLAT
        autoconf && ./configure --target=$PLAT && make
        cd -
    done

    # Put built binaries in one location
    mkdir $BASE/1.3.6-cil
    mkdir $BASE/1.3.6-cil/obj
    for TARGET in avr msp430 native
    do
        cp -r $BASE/1.3.6-targets-$TARGET/obj/* $BASE/1.3.6-cil/obj/
    done
}


####
# Build LIS
####
build_lis ()
{
    CILPATH=$BASE/1.3.6-cil make -C $BASE/lis-core/lis
}


####
# Core of the instalation
####

# Installation takes exactly one prameter that specifies where to
# install LIS and the related tools.
if [ $# -ne 1 ]
then
    echo "Must specify target install directory"
    exit
else
    cd $1
    BASE=`pwd`
    cd -
fi

# Obtain LIS
get_lis

# Obtain CIL
get_cil

# Build a patched version of CIL for use with embedded systems
build_cil

# Build LIS
build_lis
