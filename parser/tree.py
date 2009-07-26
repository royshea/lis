#!/usr/bin/env python

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

class CallTree:

    def __init__(self, body, parent=None):
        self.body = body
        self.parent = parent
        self.children = []


    def add_child(self, body):
        child = CallTree(body, self)
        self.children.append(child)
        return child


    def get_parent(self):
        return self.parent


    def __str__(self):
        out_string = ""
        out_string += "%s\n" % self.body
        for child in self.children:
            out_string += str(child)
            out_string += "%s -> %s\n" % (self.body, child.body)
        return out_string


if __name__ == '__main__':
    print "digraph test {"
    root = CallTree("root")
    a = root.add_child("a")
    b = a.add_child("b")
    c = b.add_child("c")
    d = c.add_child("d")
    e = c.add_child("e")
    f = b.add_child("f")
    g = b.add_child("g")
    h = c.add_child("h")
    i = h.add_child("i")
    print root
    print "}"

