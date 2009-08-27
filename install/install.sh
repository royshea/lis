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
CIL=cil-1.3.7

####
# Download a file
####
get_file ()
{
    if [ -x "`which sha1sum`" ]
    then
       SHA1SUM="sha1sum"
    else
       SHA1SUM="openssl dgst -sha1"
    fi

    wget -c --read-timeout=120 --retry-connrefused "$3" "$1"
    file=`basename $1`
    check_sum=`$SHA1SUM < $file | sed 's/ .*//'`
    if [ "$2"x != x -a "$check_sum"x != "$2"x ]
    then
       echo "sha1sum mismatch!  Rename $file and try again."
       exit 1
    fi
}

####
# Get a copy of LIS
####
get_lis ()
{
    cd $LISDIR
    get_file $PROJECTS/~rshea/lis/code/lis-core.tgz "" "--no-check-certificate"
    tar -xzvf lis-core.tgz
    mv lis-core.tgz tarballs/
    mv lis-core/* .
    rmdir lis-core
    cd -
}


####
# Get a copy of CIL
####
get_cil ()
{
    cd $LISDIR
    get_file $SOURCEFORGE/project/cil/cil/$CIL/$CIL.tar.gz c42a561beb32c4858dca02a2da943681a63d30bd ""
    tar -xzvf $CIL.tar.gz
    mv $CIL.tar.gz tarballs/
    cd -
}


####
# Setup and build CIL
####
build_cil ()
{
    cd $LISDIR/$CIL
    autoconf && ./configure && make
    cd -
}


####
# Build LIS
####
build_lis ()
{
    CILPATH=$LISDIR/$CIL make -C $LISDIR/lis
    make -C $LISDIR/bitlog
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
elif [ -e $1 ]
then
    echo "Aborting.  Directory already exists."
    exit
else
   LISDIR=$1
    mkdir -p $LISDIR
    mkdir $LISDIR/tarballs
fi

# Obtain LIS
get_lis

# Obtain CIL
get_cil

# Build a patched version of CIL for use with embedded systems
build_cil

# Build LIS
build_lis
