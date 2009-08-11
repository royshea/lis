#!/bin/sh

export TOSROOT=`pwd`
export TOSDIR="$TOSROOT/tos"
export CLASSPATH=$TOSROOT/support/sdk/java:$TOSROOT/support/sdk/java/tinyos.jar:$CLASSPATH
export MAKERULES="$TOSROOT/support/make/Makerules"
export PATH=$TOSROOT/tools/quanto/labjack:$TOSROOT/tools/quanto/scripts:$TOSROOT/tools/mni/scripts:$PATH
export PYTHONPATH=$TOSROOT/support/sdk/python/mni:$TOSROOT/support/sdk/python
