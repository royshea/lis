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


    def get_start_time(self):

        min_time = None
        for node_id in self.traces.keys():

            # Ignore empty traces
            if len(self.traces[node_id]) == 0:
                continue

            # Track the minimum start time
            if min_time:
                min_time = min(min_time, self.traces[node_id][0].timestamp)
            else:
                min_time = self.traces[node_id][0].timestamp

        return min_time

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

