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

class DataMissing(Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)


class DataEnd(Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)



class ChunkStream:
    """Present a stream of data as blocks of contiguous data payloads.

    Separate items in the list represent data separated by one or more
    missing packets.
    """

    def __init__(self, packets, start_time=0):

        self.start_time = start_time

        # List of tripplets:
        #    (chunk, offset, time)
        # that describes that time occurres starting at offset within
        # chink.
        self.times = []

        self.chunks = []
        self._read_chunks(packets)

        self.chunk_index = 0
        self.bit_index = 0


    def _read_chunks(self, packets):
        current_chunk = ""
        tmp_chunk_offset = 0
        tmp_bit_offset = 0

        for p in packets:
            if p:
                current_chunk += p.bit_string()
                self.times.append((tmp_chunk_offset, tmp_bit_offset, p.timestamp))
                tmp_bit_offset += len(p.bit_string())
            elif len(current_chunk) > 0:
                self.chunks.append(current_chunk)
                current_chunk = ""
                tmp_chunk_offset += 1
                tmp_bit_offset = 0
            else:
                # Never expect to see more thane one None instances in a
                # row within the packets list
                assert False

        # Write the last packet as a chunk
        if len(current_chunk) > 0:
            self.chunks.append(current_chunk)
        return


    def peek_bytes(self, length):

        current_chunk = self.chunks[self.chunk_index]

        if len(current_chunk) >= self.bit_index + length:
            # Normal operation
            bytes = ''.join(current_chunk[self.bit_index:self.bit_index+length])
            assert len(bytes) == length

        elif self.chunk_index < len(self.chunks) - 1:
            # Request can't be satisfied in the current chunk, but there
            # are more chunks around.  This implies that we missed some
            # data.  Need to move onto next black and then try to resynchronize.
            raise DataMissing("Fail")
        else:
            # Out of data.  Raise an error noting that we are at the end
            # of the input.
            raise DataEnd("Fail")

        return bytes


    def next_chunk(self):
        # Update our index to point to the start of the next block.
        self.chunk_index += 1
        self.bit_index = 0
        return self.chunk_index < len(self.chunks)


    def read_bytes(self, length):
        bytes = self.peek_bytes(length)
        self.bit_index += length
        return bytes


    def read_time(self):
        chunk_times = [t for t in self.times if \
                t[0] == self.chunk_index and t[1] <= self.bit_index]
        time = chunk_times[-1][2]
        start_bit = chunk_times[-1][1]
        return (time - self.start_time, self.bit_index - start_bit)



if __name__ == '__main__':
    assert False, "Stick a fork in it 'cause you're done."
