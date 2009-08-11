#!/bin/sh

set -o nounset
set -o errexit

FILE=`basename $1`
DIR=`dirname $1`
OUT_FILE=$2

# Convert all dollar signs to two underscores (NesC)
sed -e 's/\$/__/g' < $DIR/$FILE > $OUT_FILE
