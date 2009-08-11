#!/bin/sh

set -o nounset
set -o errexit


####
# Checkout TinyOS
####
get_tinyos ()
{
    cvs -d:pserver:anonymous@tinyos.cvs.sourceforge.net:/cvsroot/tinyos login
    # NOTE: Documented problems using the -d option with pserver
    # connections to download a repository to a specific absolute
    # directory.  Do this manually for now with a mv.
    cvs -z3 -d:pserver:anonymous@tinyos.cvs.sourceforge.net:/cvsroot/tinyos \
            co -P -r release_tinyos_2_1_0_0 tinyos-2.x
    mv tinyos-2.x $TOSROOT
}


####
# Insert LIS into TinyOS
####
insert_lis ()
{
    # Basic environment setup
    cp $LIS/lowlog_env_setup.sh $TOSROOT/

    # Demo applications
    cp -r $LIS/apps/MultihopLogTapRadioCountToLeds $TOSROOT/apps/

    # Build system
    cp $LIS/support/make/lis_general.extra $TOSROOT/support/make/lis_general.extra
    cp $LIS/support/make/lowlog_general.extra $TOSROOT/support/make/lowlog_general.extra
    cp $LIS/support/make/lowlog_gid_general.extra $TOSROOT/support/make/lowlog_gid_general.extra
    for PLAT in avr msp
    do
        mv $TOSROOT/support/make/$PLAT/$PLAT.rules $TOSROOT/support/make/$PLAT/$PLAT.rules.orig
        cp $LIS/support/make/$PLAT/$PLAT.rules $TOSROOT/support/make/$PLAT/$PLAT.rules
        cp $LIS/support/make/$PLAT/lis.extra $TOSROOT/support/make/$PLAT/lis.extra
        cp $LIS/support/make/$PLAT/lowlog.extra $TOSROOT/support/make/$PLAT/lowlog.extra
        cp $LIS/support/make/$PLAT/lowlog_gid.extra $TOSROOT/support/make/$PLAT/lowlog_gid.extra
    done

    # LIS TinyOS Component
    cp -r $LIS/tos/lib/multihoplogtap $TOSROOT/tos/lib

    # LIS Tool Suite
    cp -r $LIS/support/utils $TOSROOT/support
}


####
# Core of the instalation
####

# Installation takes exactly one prameter that specifies where to
# install LIS and the related tools.
if [ $# -ne 2 ]
then
    echo "Usage: install_tos.sh <LIS_PATH> <TOS_PATH>"
    echo "Must specify exactly two arguments.  The first is the path to"
    echo "the base of your LIS installation.  The second is the path to"
    echo "where TinyOS with LIS should be placed."
    exit
else
    LIS=$1
    TOSROOT=$2
    mkdir $2
fi

get_tinyos
insert_lis
