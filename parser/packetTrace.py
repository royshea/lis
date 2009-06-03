#!/usr/bin/python


class SourceTrace:
    """Set of per-source packet traces."""

    MAX_SEQ_NUM = 255

    def __init__(self, packets):
        """Sort set of packets into per-source traces."""

        self.traces = {}

        # Sort incoming packets into per-source lists
        sorted_packets = {}
        for packet in packets:
            trace = sorted_packets.setdefault(packet.src_addr, [])
            trace.append(packet)


        # For the trace from each source...
        for source in sorted_packets.keys():

            # Create an empty trace
            self.traces[source] = []
            prior_seq_num = None

            # Insert "None" packets to mark for each sorted trace
            for packet in sorted_packets[source]:
                # Insert packet into stream using None to mark missing packets.
                if prior_seq_num == None or \
                        (prior_seq_num + 1) % self.MAX_SEQ_NUM == packet.seq_num:
                    self.traces[source].append(packet)
                    prior_seq_num = packet.seq_num
                elif (prior_seq_num) % self.MAX_SEQ_NUM == packet.seq_num:
                    # Assume repated packet sequence number is the result of
                    # a retransmission or similar network problem.  Simply
                    # save the most recent packet.
                    self.traces[source] = self.traces[source][:-1]
                    self.traces[source].append(packet)
                    prior_seq_num = packet.seq_num
                else:
                    self.traces[source].append(None)
                    self.traces[source].append(packet)
                    prior_seq_num = packet.seq_num


    def __str__(self):
        """Print a raw copy of all traces."""
        out_string = ""
        for id in self.traces.keys():
            out_string += "Trace for node %d:\n" % (id)
            for packet in self.traces[id]:
                if packet:
                    out_string += "    " + str(packet) + "\n"
                else:
                    out_string += "    " + "MISSING DATA\n"
        return out_string



if __name__ == '__main__':
    assert False, "Stick a fork in it 'cause you're done."

