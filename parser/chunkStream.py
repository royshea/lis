#!/usr/bin/python

import packet


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
