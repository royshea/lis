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

SOURCEFORGE=http://downloads.sourceforge.net
PROJECTS=http://projects.nesl.ucla.edu

####
# Download a file
####
get_file ()
{
    cd $BASE
    wget -c --read-timeout=120 --retry-connrefused "$3" "$1"
    file=`basename $1`
    check_sum=`sha1sum < $file | sed 's/ .*//'`
    if [ "$check_sum"x != "$2"x ]
    then
       die "sha1sum mismatch!  Rename $file and try again."
    fi
    cd -
}

####
# Get a copy of LIS
####
get_lis ()
{
    cd $BASE
    get_file $PROJECTS/~rshea/lis/lis-core.tgz c9e1f5761d650f3631dc734180d7b70fdf300d82 "--no-check-certificate"
    tar -xzvf lis-core.tgz
    mv lis-core.tgz build.lis
    cd -
}


####
# Get a copy of CIL
####
get_cil ()
{
    cd $BASE
    get_file $SOURCEFORGE/project/cil/cil/cil-1.3.6/cil-1.3.6.tar.gz b57b08fad26b54a85e63c0fb6ded7858376939e2 ""
    tar -xzvf cil-1.3.6.tar.gz
    mv cil-1.3.6.tar.gz build.lis
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
    mv cil build.lis

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
        mv $BASE/1.3.6-targets-$TARGET $BASE/build.lis
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
    mkdir build.lis
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