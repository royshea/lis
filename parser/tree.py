#!/usr/bin/env python

from optparse import OptionParser
import rlisTokens
import packet
import packetTrace
import chunkStream
import parseLog

class CallTree:
    """Basic tree class used to build call trees.

    This implementation does not provide any guarntees of ordering
    between siblings within the tree.  Such information is left to
    higher levels and can be encoded within the node_id or body.
    """

    def __init__(self, node_id, body=None, parent=None):
        self.node_id = node_id
        self.body = body
        self.parent = parent
        self.children = []


    def _insert_child(self, child):
        self.children.append(child)


    def add_child(self, node_id, body=None):
        child = CallTree(node_id, body, self)
        self._insert_child(child)
        return child


    def get_parent(self):
        return self.parent


    def __str__(self):
        out_string = ""
        out_string += "%s\n" % self.node_id
        for child in self.children:
            out_string += str(child)
            out_string += "%s -> %s\n" % (self.node_id, child.node_id)
        return out_string


class FullCallTree(CallTree):
    """Specialized CallTree that forecs each node to be unique."""


    def __init__(self, node_id, body=None, parent=None):
        CallTree.__init__(self, node_id, body, parent)
        self.tree_counter = None
        if parent == None:
            self.tree_counter = 0



    def add_child(self, token, data=None):
        node_id = self._token_id(token, data)
        child = FullCallTree(node_id, token, self)
        self._insert_child(child)
        return child


    def build_from_tokens(self, tokens):

        node = self
        for token in tokens:

            # Examine token to see if it is:
            # - None indicating missing data.  Need to continue next
            #   building tree using next token from the root.
            # - Tuple indicating a watch token with data.  Need to separate
            #   out the two pieces of information.
            # - Normal case is just a token.
            if not token:
                node = self
                continue
            elif type(token) == tuple:
                # TODO: Badness to deal with possible tuple generated by
                # the watch token type.
                data = token[1]
                token = token[0]

            # Add the token to the tree!
            if token.type == rlisTokens.RlisEntry.FOOTER:
                node = node.get_parent()

            elif token.type == rlisTokens.RlisEntry.HEADER or \
                    token.type == rlisTokens.RlisEntry.CALL:
                node = node.add_child(token)

            elif token.type == rlisTokens.RlisEntry.CONDITIONAL:
                ignore = node.add_child(token)

            elif token.type == rlisTokens.RlisEntry.WATCH:
                ignore = node.add_child(token, data)

            else:
                assert False, "Unexpected token type"

    def _next_tree_counter(self):
        if self.parent == None:
            counter = self.tree_counter
            self.tree_counter += 1
        else:
            counter = self.parent._next_tree_counter()

        return counter


    def _token_id(self, token, data=None):
        """Generate an ID for the current token.

        This method assigns each token a unque identifier to create a
        complete call tree where each call to a function is treated
        independantly.  This is implemented by including within each ID
        a counter unique to the entire tree.
        """

        if token.type == rlisTokens.RlisEntry.HEADER or \
                token.type == rlisTokens.RlisEntry.FOOTER or \
                token.type == rlisTokens.RlisEntry.CALL:
            id = "%s_%d" % (token.function_name, self._next_tree_counter())

        elif token.type == rlisTokens.RlisEntry.CONDITIONAL:
            id = "%s_%d_branch_%d" % (token.function_name,
                    self._next_tree_counter(), token.id)

        elif token.type == rlisTokens.RlisEntry.WATCH:
            assert data, "Data must not be None for watch points"
            id = "%s_%d_watch_%d_val_%d" % (token.function_name,
                    self._next_tree_counter(), token.id, data)

        else:
            assert False, "Unexpected token type:\n%s" % str(token)

        return id


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
        tree = FullCallTree("root")
        tree.build_from_tokens(tokens)
        print tree


if __name__ == '__main__':
    main()

