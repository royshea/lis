#!/usr/bin/python

# Copyright (c) 2009, Regents of the University of California
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following
# disclaimer in the documentation and/or other materials provided
# with the distribution.
#
# * Neither the name of the University of California, Los Angeles
# nor the names of its contributors may be used to endorse or
# promote products derived from this software without specific prior
# written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Author: Roy Shea

import sys
import getopt
import copy

import packet
import packetTrace
import rlisTokens
import chunkStream

def debug_out(text):
    """Minimal debugging output."""
    sys.stderr.write("===>\n")
    sys.stderr.write(str(text))
    sys.stderr.write("<===\n\n")
    return


class RoiParser:

    INDENT = "    "

    def __init__(self, token_table):
        """Initialize trace using packets from packet_trace.

        This assumes that data in the trace was delivered in order and
        that all packets are from the same node.
        """

        self.token_table = token_table


    def _indented_time(self, time, bit_offset, depth):
        out_string = ""
        out_string += "%4.6f %3d: " % (time, bit_offset)
        out_string += self.INDENT * depth
        return out_string


    def _print_tokens(self, tokens_and_times):
        out_string = ""

        call_depth = 0
        for (token, time_and_offset) in tokens_and_times:

            if not token:
                out_string += "\n\nEND OF CHUNK\n\n"
                call_depth = 0
                continue
            elif type(token) == tuple:
                # TODO: Badness to deal with possible tuple generated by
                # the watch token type.
                data = token[1]
                token = token[0]

            out_string += self._indented_time(time_and_offset[0],
                    time_and_offset[1], call_depth)

            if token.type == rlisTokens.RlisEntry.FOOTER:
                out_string = out_string[:-len(self.INDENT)]
                out_string += "<-- RETURN --\n"
                call_depth -= 1

            elif token.type == rlisTokens.RlisEntry.HEADER:
                out_string += "-- ENTRY --> %s\n" % token.function_name
                call_depth += 1

            elif token.type == rlisTokens.RlisEntry.CALL:
                if self.token_table.has_point_footer(token.target):
                    out_string += "-- BODY --> %s\n" % token.target
                    call_depth += 1
                else:
                    out_string += "Calling %s\n" % token.target

            elif token.type == rlisTokens.RlisEntry.CONDITIONAL:
                out_string += "Branch ID: %d (of %d)\n" % (
                        token.id, token.range)

            elif token.type == rlisTokens.RlisEntry.WATCH:
                out_string += "Watch point for %s with value: %d\n" % (
                        token.watch_var, (int(data, 2)))

            else:
                debug_out(token)
                out_string += "Non-ROI token encountered.\n"

        out_string += "\n\nEND OF DATA\n\n"
        return out_string

    def _processes_next_token(self, stream, call_stack):

        out_string = ""

        time_and_offset = stream.read_time()

        # TODO: Magic number 2 :-(  Perhaps something like
        # RlisEntry.MAX_PREAMBLE_LENGTH?
        peek = stream.peek_bytes(2)

        if peek[0] == rlisTokens.RlisEntry.POINT_PREAMBLE:

            # Handle a point token.  Note that only a generic POINT
            # token is worked with.
            stream.read_bytes(self.token_table.point_token_width)
            token = self.token_table.get_token(rlisTokens.RlisEntry.POINT, None, None)
            from_function = call_stack.pop()

        elif peek == rlisTokens.RlisEntry.GLOBAL_PREAMBLE:

            # Handle a global token
            stream.read_bytes(len(rlisTokens.RlisEntry.GLOBAL_PREAMBLE))
            id_width = self.token_table.global_token_width
            id_str = stream.read_bytes(id_width)
            id = int(id_str, 2)
            token = self.token_table.get_token(rlisTokens.RlisEntry.GLOBAL, id, None)

            # Maintain context
            if token.type == rlisTokens.RlisEntry.HEADER:
                call_stack.append(token.function_name)
            elif token.type == rlisTokens.RlisEntry.CALL and \
                    self.token_table.has_point_footer(token.target):
                # Only update call stack for calls to ROI functions
                call_stack.append(token.target)
            else:
                # Other tokens have no effect on the call stack
                pass


        elif peek == rlisTokens.RlisEntry.LOCAL_PREAMBLE:

            # Handle a local token
            stream.read_bytes(len(rlisTokens.RlisEntry.LOCAL_PREAMBLE))
            context = call_stack[-1]
            id_width = self.token_table.local_token_widths[context]
            id_str = stream.read_bytes(id_width)
            id = int(id_str, 2)
            token = self.token_table.get_token(rlisTokens.RlisEntry.LOCAL, id, context)

            # Maintain context
            if token.type == rlisTokens.RlisEntry.CALL and \
                    self.token_table.has_point_footer(token.target):
                call_stack.append(token.target)

        else:
            assert False, "Stream out of sync"
            out_string += "ABORTING. STREAM OUT OF SYNC\n"
            return out_string

        if token.type == rlisTokens.RlisEntry.WATCH:
            # TODO: Overloading the type returned by this function to be
            # either a token or a value.  A little ugly.  Clean this up
            # later.
            data = stream.read_bytes(token.var_width)
            token = (token, data)

        assert token, "Token should be set before return"
        return (token, call_stack, time_and_offset)


    def _scan_chunk(self, clean_stream):
        """Examine a single chunk to find the best offset for parsing
        that chunk."""

        MAX_OFFSET = 100
        guesses = []

        for offset in range(MAX_OFFSET):
            stream = copy.copy(clean_stream)
            call_stack = []
            tokens = []
            try:
                # Drop the leading offset bytes
                stream.read_bytes(offset)

                while True:
                    (token, call_stack, time_and_offset) = self._processes_next_token(stream, call_stack)
                    tokens.append(token)

            except chunkStream.DataMissing:
                # This excetpion is a good sign, since it means we
                # reached the end of a chunk without parsing errors.
                # Use the current offest to parse the block.
                if tokens != []:
                    guesses.append((offset, tokens))

            except chunkStream.DataEnd:
                # This excetpion is a good sign, since it means we
                # reached the end of the LAST chenk without parsing
                # errors.  Use the current offest to parse the block.
                if tokens != []:
                    guesses.append((offset, tokens))

            except IndexError:
                # Bad parse attempt
                continue

            except KeyError:
                # Bad parse attempt
                continue

        best_offset = None
        best_score = None
        for (guess_offset, guess_tokens) in guesses:
            score = self._heuristic_score(guess_offset, guess_tokens)
            if best_score == None:
                # Force setting best_score if it has not yet been set
                best_score = score - 1
            if score > best_score:
                best_offset = guess_offset
                best_score = score

        return best_offset

    def _heuristic_score(self, offset, tokens):
        # Determine how "good" a match a given parse of a block is by
        # examining the offset used and resulting parsed tokens.
        #
        # NOTE: This is a heuristic that has been determined to work
        # well for the ROI traces examined so far.  But this is ONLY a
        # heuristic.  YMMV.

        # Number of tokens is good
        num_tokens = len(tokens)

        # Small offset is good
        offset = offset

        # Global IDs encountered from a non-zero depth call stack are
        # avoided.  These imply one of:
        # - Interuption while within an ROI by an interrupt that we are
        #   also tracking.  (rarely observed in current data sets).
        # - Parsing error.
        # - Call to an entry function from within the ROI.  These
        #   happen, but this heuristic implementation assumes that they
        #   don't happen that often.
        double_global = 0
        call_depth = 0
        for token in tokens:

            if token.type == rlisTokens.RlisEntry.HEADER and \
                    token.scope == rlisTokens.RlisEntry.GLOBAL and \
                    call_depth > 0:
                double_global += 1

            if (token.type == rlisTokens.RlisEntry.HEADER and
                    token.scope == rlisTokens.RlisEntry.GLOBAL
                    ) or (
                    token.type == rlisTokens.RlisEntry.CALL and
                    token.scope == rlisTokens.RlisEntry.LOCAL):
                call_depth += 1
            elif token.type == rlisTokens.RlisEntry.FOOTER and \
                    token.scope == rlisTokens.RlisEntry.POINT:
                call_depth = max(call_depth - 1, 0)

        return num_tokens - offset - (10 * double_global)


    def print_roi_call_trace(self, trace, start_time=0):

        tokens_and_times = self.tokenize_trace(trace, start_time)
        out_string = self._print_tokens(tokens_and_times)
        return out_string



    def tokenize_trace(self, trace, start_time=0):
        """Tokenize a Packet Trace

        This tokenizer makes the following assumptions:
        - POINT tokens are only used in the FOOTER to log return
          statements and no function outside the ROI uses a POINT token
          in its FOOTER.  A POINT token in a FOOTER cause the context
          stack to be popped.
        - Entry points into the ROI use a GLOBAL token in their HEADER
          and no function that is not an entry to the ROI uses a GLOBAL
          in its HEADER.  A GLOBAL token in a HEADER causes the curernt
          function to be pushed onto the context stack.
        - LOCAL tokens will always be resolved in the context of the
          current context.
        - A CALL from the current context causes the called function to
          be pushed onto the context stack if the called function has a
          POINT token in its footer.  Otherwise the context is not
          updated by a CALL token.
        - If a function is an entry point into the ROI then no other
          function will log a CALL to it.
        - Any other token is accredited to the context on the top of the
          stack.  This will be the last known place that the code passed
          through, although the token may have been generated from a
          different location.
        """

        stream = chunkStream.ChunkStream(trace, start_time)
        tokens_and_times = []

        while True:

            # Add marker (None, None) noting that a new chunk has been
            # entered
            if tokens_and_times != []:
                tokens_and_times.append((None, None))

            offset = self._scan_chunk(stream)

            # Log how many bits were dropped when scanning the block
            if offset == None:
                sys.stderr.write("Dropped bits: %d\n" %
                        len(stream.chunks[stream.chunk_index]))
            else:
                sys.stderr.write("Dropped bits: %d\n" % offset)

            if offset == None:
                sys.stderr.write("Sync error on block %d\n" % stream.chunk_index)
                if not stream.next_chunk(): break
                continue

            call_stack = []
            try:
                # Drop the leading offet bytes
                stream.read_bytes(offset)

                while True:
                    (token, tmp_stack, time_and_offset) = self._processes_next_token(stream, call_stack)
                    tokens_and_times.append((token, time_and_offset))

            except chunkStream.DataMissing:
                if not stream.next_chunk(): break

            except chunkStream.DataEnd:
                assert not stream.next_chunk()
                break

        return tokens_and_times


    def __str__(self):
        """Print all packets in a trace."""
        out_string = ""
        for packet in self.log_packets:
            if packet == None: out_string += "==== MISSING PACKET(S) ====\n"
            else: out_string += str(packet) + "\n"
        return out_string


def usage():

    print """Usage: parseLog.py

    Attempt to print a trace of a program using information contianed
    within a trace file.

    -t, --trace=<trace_file>
        Name of file containing trace of log packets.  Default value
        is: trace.txt.

    -r, --rlsi=<rlis_file>
        File containing the RLSI specification for the log.

    -f, --format=<trace_file_format>
        Specify the format of the trace_file.  This could be "system" for
        trace files generated by a PC or "network" for trace files
        gathered from embedded wireless devices.  Default value is
        network.

    -p, --print
        Only print the raw data log packets for all nodes (this option
        ignores the -n option.)
    """

if __name__ == '__main__':

    # Process arguments
    trace_file = "trace.txt"
    rlis_file = None
    print_packets = False
    mode = "network"
    try:
        opts, args = getopt.getopt(sys.argv[1:], "ht:r:pf:",
                ["help", "trace=", "rlsi=", "print", "format="])
    except getopt.GetoptError, err:
        sys.stderr.write(str(err))
        usage()
        sys.exit(2)
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-t", "--trace"):
            trace_file = a
        elif o in ("-r", "--rlsi"):
            rlis_file = a
        elif o in ("-p", "--print"):
            print_packets = True
        elif o in ("-f", "--format="):
            mode = a
        else:
            raise Exception("Unhandled option: " + o)
    if len(args) != 0:
        usage()
        sys.exit(2)

    # Check for valid command line
    assert mode == "network" or mode == "system", "Unknown mode: %s" % mode
    assert print_packets or rlis_file, "Must specify rlis or print"

    # Read in the packets
    if mode == "network":
        packet_class = packet.AMPacket
    elif mode == "system":
        packet_class = packet.SystemPacket
    else:
        assert False, "Shouldn't be here.\n"
    packets = packet.read_packets(trace_file, packet_class)

    # Create list of bitlog packets:
    bitlog_packets = packet.BitlogPacket.get_bitlog_packets(packets)

    # Create a source trace from the packets
    bitlog_traces = packetTrace.SourceTrace(bitlog_packets)
    start_time = bitlog_traces.traces[0][0].timestamp

    # Print packets and exit if requested
    if print_packets:
        print bitlog_traces
        sys.exit(0)

    # Initialize the token tables
    token_table = rlisTokens.TokenTable(rlis_file)
    # print token_table

    # Initialize parser
    roi_parser = RoiParser(token_table)

    # Print all traces
    for trace_id in sorted(bitlog_traces.traces.keys()):
        print "==== Trace for node %d ====" % (trace_id)
        # print bitlog_traces.traces[trace_id]
        print roi_parser.print_roi_call_trace(
                bitlog_traces.traces[trace_id], start_time)
        print

    # debug_out("Success\n")
