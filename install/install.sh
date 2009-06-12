#!/bin/sh

set -o nounset
set -o errexit

####
# CUSTOMIZE THESE FOR YOUR SYSTEM
####


# Where you want LIS installed
BASE=/home/$USER/local/other

####
# Get a copy of LIS
####
get_lis ()
{
    # Grab a copy of LIS
    wget http://projects.nesl.ucla.edu/~rshea/lis/lis-core.tgz
    tar -xzvf lis-core.tgz
    mkdir $BASE/lis/build
    mv lis-core $BASE/lis/build
}

####
# Get a copy of CIL
####
get_cil ()
{
    # Grab a copy of CIL
    wget http://manju.cs.berkeley.edu/cil/distrib/cil-1.3.6.tar.gz
    tar -xzvf cil-1.3.6.tar.gz
    mkdir $BASE/cil/build
    mv cil $BASE/cil/build
}


####
# Setup and build architecture specific versions of CIL sources
####
build_cil ()
{
    CURRENT_DIR=`pwd`

    # Setup source for different targets

    cp -r $BASE/build/cil $BASE/build/1.3.6-targets-native

    for PLAT in avr msp430
    do
        echo $PLAT
        cp -r $BASE/build/cil $BASE/build/1.3.6-targets-$PLAT
        cd $BASE/build/1.3.6-targets-$PLAT
        patch -p1 < $CURRENT_DIR/cil-$PLAT.diff
        cd $CURRENT_DIR
    done

    # Build source for different targets

    cd $CIL/build/1.3.6-targets-native
    autoconf
    ./configure
    make
    cd $CURRENT_DIR

    for PLAT in avr msp430
    do
        cd $CIL/build/1.3.6-targets-$PLAT
        autoconf
        ./configure --target=$PLAT
        make
        cd $CURRENT_DIR
    done

    # Put built binaries in one location
    mkdir $CIL/1.3.6-cil
    mkdir $CIL/1.3.6-cil/obj
    for TARGET in avr msp430 native
    do
        cp -r $CIL/build/1.3.6-targets-$TARGET/obj/* $CIL/1.3.6-cil/obj/
    done
}


####
# Clean up CIL
####
clean_cil ()
{
    rm -rf $CIL/build
    rm -rf $CIL/1.3.6-cil
}

get_tinyos
insert_lis
get_cil
build_cil
build_lis

