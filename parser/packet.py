#!/usr/bin/python

class Packet:
    """Core packet representation"""

    def __init__(self, dst_addr, src_addr, port, payload, timestamp=None):
        """Minimal fields that must be present for a packet.

        The payload is an array of integer values with each value
        encoding an 8-bit chunk of data.
        """

        self.dst_addr = dst_addr
        self.src_addr = src_addr
        self.port = port
        self.msg_len = len(payload)
        self.payload = payload
        self.timestamp = timestamp


    def __str__(self):
        """Print basic packet information."""

        out_string = ""
        out_string += "%d -> %d (%d):" % (
                self.dst_addr, self.src_addr, self.port)
        for byte in self.payload:
            out_string += " %02X" % byte
        return out_string


class AMPacket (Packet):
    """TinyOS active message packet.

    The format of this packet is that output by the TinyOS Serial
    Listener application.
    """

    def __init__(self, packet_string):
        """Parse space separated hex string from a TinyOS AM Packet."""

        # Output may have an optional timestamp.  This can be detected
        # by looking for a decmial in the first space separated field.
        fields = packet_string.split()
        if "." in fields[0]:
            timestamp = float(fields[0])
            fields = fields[1:]
        else:
            timestamp = None

        # Parse the AM packet
        data = [int(x, 16) for x in fields]
        zero = data[0]
        dst_addr = data[1] * 256 + data[2]
        src_addr = data[3] * 256 + data[4]
        msg_len = data[5]
        group_id = data[6]
        handler_id = data[7]
        payload = data[8:]

        # Verify the validity of the packet
        assert zero == 0, "Zero byte must be zero"
        assert msg_len == len(payload), "Incorrect payload length"

        # Create the core packet.  The TinyOS handler_id is equivalent
        # to a port.
        Packet.__init__(self, dst_addr, src_addr, handler_id, payload, timestamp)


class SystemPacket (Packet):
    """Basic representation of a packet output by libbitlog on an x86."""

    DUMMY_ADDR = 1
    BITLOG_ID = 7

    def __init__(self, packet_string):
        """Parse space separated hex string from a libbitlog system packet."""

        # Output may have an optional timestamp.  This can be detected
        # by looking for a decmial in the first space separated field.
        fields = packet_string.split()
        if "." in fields[0]:
            timestamp = float(fields[0])
            fields = fields[1:]
        else:
            timestamp = None

        data = [int(x, 16) for x in fields]
        src_addr = self.DUMMY_ADDR
        dst_addr = self.DUMMY_ADDR
        # TODO: Beware ugly hardcoded port :-/
        port = self.BITLOG_ID
        payload = data

        # Create the core packet
        Packet.__init__(self, dst_addr, src_addr, port, payload, timestamp)


class BitlogPacket (Packet):
    """Bitlog packet."""

    BITLOG_ID = 7
    BITLOG_LENGTH = 20

    def __init__(self, packet):
        """Create a bitlog packet by extracting the bitlog payload from
        another packet."""

        assert packet.port == self.BITLOG_ID, \
                "Invalid handler ID for BitlogPacket"
        assert packet.msg_len == self.BITLOG_LENGTH, \
                "Invalid length for BitlogPacket"
        self.num_bits = packet.payload[0]
        self.seq_num = packet.payload[1]
        src_addr = packet.payload[3] * 256 + packet.payload[2]

        # Fill in base fields
        Packet.__init__(self, packet.dst_addr, src_addr, packet.port,
                packet.payload[4:], packet.timestamp)


    def bit_string(self):
        """Return binary representation of hex string payload."""

        bit_str = ""
        for byte in self.payload:
            assert 2**8 > byte and byte >= 0, \
                    "Invalid 8-bit hex value: %s\n" % byte
            bits = "".join([str((byte >> y) & 1) for y in range(8-1, -1, -1)])
            bit_str += bits
        return bit_str[:self.num_bits]


    def __str__(self):
        """Print basic bitlog packet information and binary payload."""

        out_string = ""
        out_string += "Log %02d.%04d (at %f):" % \
                (self.src_addr, self.seq_num, self.timestamp)
        for byte in self.payload:
            out_string += " %02X" % byte
        return out_string


    @classmethod
    def is_bitlog_packet(self, packet):
        """Return true if packet is a BitlogPacket."""

        return packet.port == self.BITLOG_ID and \
                packet.msg_len == self.BITLOG_LENGTH



def read_packets(file, packet_class):
    """Read packets from file."""

    import sys

    # Read in packets
    try:
        file = open(file)
    except IOError:
        print "Unable to open file: %s" % file
        sys.exit(1)

    packets = []
    for line in file:
        packet = packet_class(line)
        packets.append(packet)
    file.close()

    return packets


if __name__ == '__main__':
    assert False, "These are not the droids you're looking for."


