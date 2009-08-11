#!/bin/sh

set -o nounset
set -o errexit

LL=$TOSROOT/support/utils/lowlog

IN_FILE=$1
TARGET=$2
CALL_FILE=$3
LIS_FILE=$4
ROI_FILE=$5

# Extract calls of interest based on specified components of interest
$LL/analysis/$TARGET-extractcalls $IN_FILE > $CALL_FILE

# Create LIS from ROI specification
$LL/analysis/calldata.py -r $ROI_FILE -l $CALL_FILE > $LIS_FILE

