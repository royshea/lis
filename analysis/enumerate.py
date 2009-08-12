#!/usr/bin/python

import sys
import getopt
import math

# Mode enumeration
GLOBAL_NAMESPACE = 1
LOCAL_NAMESPACE = 2

# Token encoding
ZERO_TOKEN = "00"
ONE_TOKEN = "11"
SYNC_TOKEN = "01"
RETURN_TOKEN = "10"


def int_to_encoded_binary(num, width, mode):
    assert 2**width > num
    assert num >= 0
    if width == 0: width = 1
    binary = [(num >> y) & 1 for y in range(width-1, -1, -1)]

    # Add a synch point before global functions
    if mode == GLOBAL_NAMESPACE: encoded_binary_str = SYNC_TOKEN
    else: encoded_binary_str = ""

    for b in binary:
        if b == 0: encoded_binary_str += ZERO_TOKEN
        elif b == 1: encoded_binary_str += ONE_TOKEN
        else: assert False, "b must be 0 or 1"
    return (int(encoded_binary_str, 2), len(encoded_binary_str))


def build_call_dictionary(data_stream):
    mode = None

    call_dictionary = {}
    for line in data_stream:
        data = line.split()

        # Select data mode if it has not yet been set
        if mode == None and len(data) == 1:
            mode = GLOBAL_NAMESPACE
        elif mode == None and len(data) == 2:
            mode = LOCAL_NAMESPACE
        elif mode == None:
            assert False, "Invalid data file format"

        # Parse the line
        if mode == GLOBAL_NAMESPACE:
            assert len(data) == 1
            caller = "GLOBAL_NAMESPACE"
            target = data[0]
        elif mode == LOCAL_NAMESPACE:
            assert len(data) == 2
            caller = data[0]
            target = data[1]
        else:
            assert False, "Mode not detected?"

        # Add data to dictionary
        call_dictionary.setdefault(caller, []).append(target)
    return call_dictionary


def print_call_dictionary(call_dictionary, stream=sys.stdout):

    if len(call_dictionary) == 1 and "GLOBAL_NAMESPACE" in call_dictionary:
        callees = call_dictionary["GLOBAL_NAMESPACE"]
        callees.sort()
        bit_width = int(math.ceil(math.log(len(callees), 2)))
        for i in range(len(callees)):
            (encoded_i, encoded_bit_width) = int_to_encoded_binary(i,
                    bit_width, GLOBAL_NAMESPACE)
            stream.write(
                    callees[i] +
                    " " + str(encoded_i) +
                    " " + str(encoded_bit_width) +
                    "\n")
    else:
        sorted_callers = sorted(call_dictionary.keys())
        for calling_function in sorted_callers:
            callees = call_dictionary[calling_function]
            callees.sort()
            bit_width = int(math.ceil(math.log(len(callees), 2)))
            for i in range(len(callees)):
                (encoded_i, encoded_bit_width) = int_to_encoded_binary(i,
                        bit_width, LOCAL_NAMESPACE)
                stream.write(
                        calling_function +
                        " " + callees[i] +
                        " " + str(encoded_i) +
                        " " + str(encoded_bit_width) +
                        "\n")
def usage():
    """Print usage information for runing as a standalone script"""

    print """Usage: enumerate [-o <outfile>] [-h] <infile>

    -o <outfile>
            Write output to outfile.  If not specified then output is
            written to stdout.

    -h
            This help

    <infile>
            Input file listing one function name and source file pair per line

    Enumerate has two modes of operation.  The mode is automatically
    selected based on the structure of the input file given the
    enumerate.

    The first mode simply enumerates (assigns a unique ID) to each
    function in the input file.  This mode is selected when the input
    data has the format:
        function_name file_name

    The second mode enumerates each target called by a given function.
    The same target called by different functions may be assigned
    different IDs.  This can be thought of as a per-caller enumeration
    of called functions.  This mode is selected when the input data has
    the format:
        caller_name file_name target_name number_of_times_called

    """
    return


if __name__ == "__main__":

    # Process arguments
    in_file = None
    output = None
    try:
        opts, args = getopt.getopt(sys.argv[1:], "ho:",
                ["help", "output="])
    except getopt.GetoptError, err:
        sys.stderr.write(err)
        usage()
        sys.exit(2)
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-o", "--output"):
            output = a
        else:
            assert False, "Unhandled option: " + o
    if len(args) != 1:
        print "Must only specify exactly one infile: " + str(args)
        usage()
        sys.exit(2)
    in_file = args[0]

    # Select output stream
    if output:
        stream = open(output, "w")
    else:
        stream = sys.stdout

    # Create call dictionary
    f = open(in_file)
    call_dictionary = build_call_dictionary(f)
    f.close()

    # Print the dictionary
    print_call_dictionary(call_dictionary, stream)

    # Close output file if needed
    if output: stream.close()
