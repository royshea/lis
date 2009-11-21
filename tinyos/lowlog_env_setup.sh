#!/bin/sh

export TOSROOT=`pwd`
export TOSDIR="$TOSROOT/tos"
export CLASSPATH=$TOSROOT/support/sdk/java:$TOSROOT/support/sdk/java/tinyos.jar:$CLASSPATH
export MAKERULES="$TOSROOT/support/make/Makerules"
export PYTHONPATH=$TOSROOT/support/sdk/python
