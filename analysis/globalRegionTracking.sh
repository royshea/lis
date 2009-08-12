#!/bin/sh

set -o nounset
set -o errexit

LL=$TOSROOT/support/utils/lowlog

FILE=`basename $1 .i`
DIR=`dirname $1`
FROM_DIR=`pwd`
TARGET=$2

cd $DIR

# Extract calls of interest based on specified components of interest
$LL/analysis/$TARGET-extractcalls $FILE.i > raw_calls.txt

# Create LIS from ROI specification
$LL/analysis/calldata.py -r roi.txt -g raw_calls.txt > $FILE.lis

cd $FROM_DIR
