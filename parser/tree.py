#!/usr/bin/env python

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

