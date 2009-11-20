#!/bin/sh

set -o nounset
set -o errexit

IN_FILE=$1
OUT_FILE=$2
TARGET=$3
LIS_FILE=$4

$LIS_PATH/lis/$TARGET-lis --lis $LIS_FILE --rlis $LIS_FILE.rlis --out $OUT_FILE $IN_FILE
