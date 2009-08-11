#!/bin/sh

# 'Cause sh bugs suck.
set -o nounset
set -o errexit

IN_FILE=$1
OUT_FILE=$2
TARGET=$3

# Insert header bitlog routines and replace generic HOLDER_FUNC with
# an actual logging routien.  Then preprocess to pull in the include.
echo "- Replacing HOLDER_FUNC with calls to bitlog_write_data"
sed -e 's/extern void HOLDER_FUNC(char const   \*msg ) ;/#include "bitlog.h"/' < $IN_FILE > $IN_FILE.include
sed -e 's/HOLDER_FUNC("\(.*\) \(.*\)");/bitlog_write_data(\1, \2);/' < $IN_FILE.include > $IN_FILE.bitlog

# Shuffle :-/
$TARGET-cpp -I$BITLOG_PATH $IN_FILE.bitlog $IN_FILE.bitlog.i
rm $IN_FILE.include $IN_FILE.bitlog

# Expose functions used by the logging library and then insert logging library.
echo "- Inserting the bitlog logging library (libbitlog-$TARGET)"
sed -e '/__inline static void RealMainP__Boot__booted(void) *$/{
N
s/__inline static void RealMainP__Boot__booted(void) *\n{/__inline static void RealMainP__Boot__booted(void) \n{\n  bitlog_init(TOS_NODE_ID);\n/
}
' < $IN_FILE.bitlog.i > $IN_FILE.init.i

# Re-set ActiveMessageAddressC__addr and ActiveMessageAddressC__group to
# the enumerations TOS_AM_ADDRESS and TOS_AM_GROUP respectivly.
# CIL notes these as constants and folds them in.
#
# TODO: Stop CIL from folding these constants in.
echo "- Redefining ActiveMessageAddressC__addr and ActiveMessageAddressC__group"
echo "  to TOS_AM_ADDRESS and TOS_AM_GROUP respectivly."
echo
echo "  WARNING: Any other use of TOS_AM_ADDRESS and TOS_AM_GROUP in"
echo "  your system need to be manually updated.  (Although there"
echo "  probably aren't othe any such uses.)"
echo
echo "  WARNING: Tools such as Avrora and tos-set-symbols need too look"
echo "  for a revised ActiveMessageAddressC__addr rather than the"
echo "  default ActiveMessageAddressC\$addr.  This can be accomplished"
echo "  - In TinyOS by updating makefiles to redifine the AMADDR variable,"
echo "    normally defined in \$TOSROOT/support/make/\$PROC/\$PROC.rules."
echo "  - In Avrora by extending the updateNodeID function in"
echo "    SensorSimulation.java to include the line:"
echo "    updateVariable(smap, "ActiveMessageAddressC__addr", id); // LIS"
echo

sed -e 's/am_addr_t ActiveMessageAddressC__addr = (am_addr_t )1;/am_addr_t ActiveMessageAddressC__addr = (am_addr_t )TOS_AM_ADDRESS;/g' < $IN_FILE.init.i > $IN_FILE.addr.i
sed -e 's/am_group_t ActiveMessageAddressC__group = (am_group_t )34;/am_group_t ActiveMessageAddressC__group = (am_group_t )TOS_AM_GROUP;/g' < $IN_FILE.addr.i > $IN_FILE.group.i

sed -e 's/extern uint16_t TOS_NODE_ID;/uint16_t TOS_NODE_ID;/g' < $IN_FILE.group.i > $IN_FILE.extern.i

mv $IN_FILE.extern.i $OUT_FILE
rm $IN_FILE.bitlog.i $IN_FILE.init.i $IN_FILE.addr.i $IN_FILE.group.i

