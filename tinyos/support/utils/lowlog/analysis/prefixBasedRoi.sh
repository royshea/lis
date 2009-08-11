#!/bin/sh

set -o nounset
set -o errexit

COMPONENTS=$1
OUT_FILE=$2

echo $COMPONENTS > $OUT_FILE

