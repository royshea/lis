#!/bin/sh

set -o nounset
set -o errexit

####
# CUSTOMIZE THESE FOR YOUR SYSTEM
####

# Where you want TinyOS installed
CVS=/home/$USER/cvs
TOSROOT=$CVS/tinyos-2.1.0-tagged


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
    mv tinyos-2.x $CVS/tinyos-2.1.0-tagged
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
# Build LIS support within TinyOS
####
build_lis ()
{
    CURRENT_DIR=`pwd`
    echo "# Copy and paste the following commands"

    echo export CILPATH=$CIL/1.3.6-cil
    echo export CURRENT_DIR=`pwd`

    echo cd $TOSROOT
    echo . lowlog_env_setup.sh
    echo cd $TOSROOT/support/utils/lowlog
    echo sh install.sh
    echo cd $CURRENT_DIR
}



