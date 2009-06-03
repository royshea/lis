#!/usr/bin/python
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

    def _processes_next_token(self, stream, call_stack):

        out_string = ""

        (time, bit_offset) = stream.read_time()

        # TODO: Magic number 2 :-(  Perhaps something like
        # RlisEntry.MAX_TOKEN_LENGTH?
        peek = stream.peek_bytes(2)

        if peek[0] == rlisTokens.RlisEntry.POINT_PREAMBLE:

            # Handle a point token.  Note that only a generic POINT
            # token is worked with.
            stream.read_bytes(self.token_table.point_token_width)
            token = self.token_table.get_token(rlisTokens.RlisEntry.POINT, None, None)
            from_function = call_stack.pop()
            out_string += self.INDENT * len(call_stack)
            out_string += "<-- (%s)\n" % from_function


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
                out_string += self.INDENT * (len(call_stack) - 1)
                out_string += "-- GLOBAL --> %s\n" % token.function_name
            elif token.type == rlisTokens.RlisEntry.CALL:
                if self.token_table.has_point_footer(token.target):
                    call_stack.append(token.target)
                    out_string += self.INDENT * (len(call_stack) - 1)
                    out_string += "-- GLOBAL --> %s\n" % token.target
                else:
                    out_string += self.INDENT * len(call_stack)
                    out_string += "%d %d: " % (time, bit_offset)
                    out_string += "Calling %s\n" % token.target
            elif token.type == rlisTokens.RlisEntry.CONDITIONAL:
                # Conditionals have no impact on the call stack, but may
                # as well be listed.
                out_string += self.INDENT * len(call_stack)
                out_string += "%d %d: " % (time, bit_offset)
                out_string += "Branch ID: %d (of %d)\n" % (
                        token.id, token.range)
            else:
                out_string += self.INDENT * len(call_stack)
                out_string += "%d %d: " % (time, bit_offset)
                out_string += "Non-ROI token encountered.\n"


        elif peek == rlisTokens.RlisEntry.LOCAL_PREAMBLE:

            # Handle a local token
            stream.read_bytes(len(rlisTokens.RlisEntry.LOCAL_PREAMBLE))
            context = call_stack[-1]
            id_width = self.token_table.local_token_widths[context]
            id_str = stream.read_bytes(id_width)
            id = int(id_str, 2)
            token = self.token_table.get_token(rlisTokens.RlisEntry.LOCAL, id, context)

            # Maintain context
            if token.type == rlisTokens.RlisEntry.CALL:
                if self.token_table.has_point_footer(token.target):
                    call_stack.append(token.target)
                    out_string += self.INDENT * (len(call_stack) - 1)
                    out_string += "%d %d: " % (time, bit_offset)
                    out_string += "--> %s\n" % token.target
                else:
                    out_string += self.INDENT * len(call_stack)
                    out_string += "%d %d: " % (time, bit_offset)
                    out_string += "Calling %s\n" % token.target
            elif token.type == rlisTokens.RlisEntry.CONDITIONAL:
                # Conditionals have no impact on the call stack, but may
                # as well be listed.
                out_string += self.INDENT * len(call_stack)
                out_string += "%d %d: " % (time, bit_offset)
                out_string += "Branch ID: %d (of %d)\n" % (
                        token.id, token.range)
            else:
                out_string += self.INDENT * len(call_stack)
                out_string += "%d: " % time
                out_string += "Non-ROI token encountered.\n"

        else:
            out_string += "ABORTING. STREAM OUT OF SYNC\n"
            return out_string

        if token.type == rlisTokens.RlisEntry.WATCH:
            data = stream.read_bytes(token.var_width)
            out_string += self.INDENT * len(call_stack)
            out_string += "%d %d: " % (time, bit_offset)
            out_string += "Watch point for %s with value: %d\n" % (
                    token.watch_var, (int(data, 2)))

        return (out_string, call_stack, time)


    def _scan_chunk(self, clean_stream):
        """Examine a single chunk to find the best offset for parsing
        that chunk."""

        MAX_OFFSET = 100
        string_guess = []

        for offset in range(MAX_OFFSET):
            stream = copy.copy(clean_stream)
            call_stack = []
            out_string = ""
            try:
                # Drop the leading offset bytes
                stream.read_bytes(offset)

                while True:
                    (s, call_stack, time) = self._processes_next_token(stream, call_stack)
                    out_string += s

            except chunkStream.DataMissing:
                # This excetpion is a good sign, since it means we
                # reached the end of a chunk without parsing errors.
                # Use the current offest to parse the block.
                if out_string != "":
                    string_guess.append((offset, out_string))

            except chunkStream.DataEnd:
                # This excetpion is a good sign, since it means we
                # reached the end of the LAST chenk without parsing
                # errors.  Use the current offest to parse the block.
                if out_string != "":
                    string_guess.append((offset, out_string))

            except IndexError:
                # Bad parse attempt
                continue

            except KeyError:
                # Bad parse attempt
                continue

        best_string = ""
        best_offset = None
        best_score = None
        # TODO: Sort string_guess list based on number of lines.  Remove
        # leading whitespace.  Then remove all sets that are a subset of
        # another member of the list.  If there is more than one
        # remaining list then life gets interesting.
        for (guess_offset, guess_string) in string_guess:
            score = self._heuristic_score(guess_offset, guess_string)
            if best_score == None:
                # Force setting best_score if it has not yet been set
                best_score = score - 1
            if score > best_score:
                best_string = guess_string
                best_offset = guess_offset
                best_score = score

        return best_offset

    def _heuristic_score(self, offset, string):
        # Determine how "good" a match a given parse of a block is by
        # examining the offset used and resulting string.
        #
        # NOTE: This is a heuristic that has been determined to work
        # well for the ROI traces examined so far.  But this is ONLY a
        # heuristic.  YMMV.

        # Number of lines of output is good
        lines = len(string.split("\n"))

        # Small offset is good
        offset = offset

        # Global IDs encountered from a non-zero depth call stack bad
        # (implies either an interrupt that is rarely observed in the
        # analysis done so far, or a parsing problem).  This is VERY
        # specific to the actual string used when printing output.
        interrupts = 0
        for line in string.split("\n"):
            if line.find("GLOBAL") > 0 and \
                    line[0:len(self.INDENT)] == self.INDENT:
                interrupts += 1

        return lines - offset - (10 * interrupts)


    def print_roi_call_trace(self, trace, start_time=0):
        """Pretty print the call trace.

        This printer makes the following assumptions:
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

        TODO: Currently has no support for synchronization points.  This
        is a big limitation so we should look at a robust, or at least
        okay, solution to the problem.
        """


        stream = chunkStream.ChunkStream(trace, start_time)
        out_string = ""

        while True:
            offset = self._scan_chunk(stream)
            if offset == None:
                out_string += "\n\nUnable to find valid offset.  SYNC ERROR.\n"
                if not stream.next_chunk(): break
                continue

            out_string += "\n\nChunk number: %d\nUsing offset: %d\n" % (stream.chunk_index, offset)
            call_stack = []
            try:
                # Drop the leading offet bytes
                stream.read_bytes(offset)

                while True:
                    (s, tmp_stack, time) = self._processes_next_token(stream, call_stack)
                    out_string += s

            except chunkStream.DataMissing:
                out_string += "\n\nEND OF CHUNK\n\n"
                if not stream.next_chunk(): break

            except chunkStream.DataEnd:
                out_string += "\n\nEND OF DATA\n\n"
                if not stream.next_chunk(): break

            except:
                out_string += "\n\nPARSE ERROR\n\n"
                if not stream.next_chunk(): break

        return out_string


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

    -r, --rlsi=<rlsi_file>
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
    rlsi_file = None
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
            rlsi_file = a
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
    assert print_packets or rlsi_file, "Must specify rlis or print"

    # Read in the packets
    if mode == "network":
        packet_class = packet.AMPacket
    elif mode == "system":
        packet_class = packet.SystemPacket
    else:
        assert False, "Shouldn't be here.\n"
    packets = packet.read_packets(trace_file, packet_class)

    # Create list of bitlog packets:
    bitlog_packets = []
    for p in packets:
        if packet.BitlogPacket.is_bitlog_packet(p):
            bitlog_packets.append(packet.BitlogPacket(p))


    # Create a source trace from the packets
    bitlog_traces = packetTrace.SourceTrace(bitlog_packets)
    start_time = bitlog_traces.traces[0][0].timestamp

    # Print packets and exit if requested
    if print_packets:
        print bitlog_traces
        sys.exit(0)

    # Initialize the token tables
    token_table = rlisTokens.TokenTable(rlsi_file)
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
