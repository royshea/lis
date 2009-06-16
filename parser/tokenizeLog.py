#!/usr/bin/env python

from optparse import OptionParser
import rlisTokens
import packet
import packetTrace
import chunkStream
import parseLog

def main():

    # Handle the command line
    usage = "usage: %prog [options] rlis trace"
    parser = OptionParser(usage)

    parser.add_option("-m", "--mode", dest="mode", metavar="STRING",
            default="network", help="Specify the trace mode that " +
            "may be either network or system [default: %default]")

    (options, args) = parser.parse_args()

    if len(args) != 2:
        parser.error("Must specify both the rlis and trace file names")
    (rlis_file, trace_file) = args

    # Load the token table and the parser
    token_table = rlisTokens.TokenTable(rlis_file)
    roi_parser = parseLog.RoiParser(token_table)

    # Read in the packets and make list of bitlog packets
    if options.mode == "network":
        packet_class = packet.AMPacket
    elif options.mode == "system":
        packet_class = packet.SystemPacket
    else:
        parser.error("option -m must be either network or system")
    packets = packet.read_packets(trace_file, packet_class)
    bitlog_packets = packet.BitlogPacket.get_bitlog_packets(packets)

    # Create a source trace from the packets
    bitlog_traces = packetTrace.SourceTrace(bitlog_packets)

    # Print tokens
    start_time = bitlog_traces.traces[0][0].timestamp
    for trace_id in sorted(bitlog_traces.traces.keys()):
        print "# ==== Trace for node %d ====" % (trace_id)
        trace = bitlog_traces.traces[trace_id]
        tokens_and_times = roi_parser.tokenize_trace(trace, start_time)
        [tokens, times] = zip(*tokens_and_times)
        for token in tokens:
            print token

if __name__ == '__main__':
    main()
