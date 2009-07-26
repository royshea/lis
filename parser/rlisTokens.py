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

import copy

class RlisEntry:
    """Representation of an RLIS entry"""

    # RLIS entry types
    CONDITIONAL = 1
    WATCH = 2
    CALL = 3
    HEADER = 4
    FOOTER = 5

    # Masks for the conditional flag
    IF = 0x01
    SWITCH = 0x02
    LOOP = 0x04

    # RLIS scope types
    POINT = 1
    LOCAL = 2
    GLOBAL = 3

    # RLIS token preambles
    POINT_PREAMBLE = "0"
    LOCAL_PREAMBLE = "11"
    GLOBAL_PREAMBLE= "10"

    def __init__(self, rlis_entry):
        """Create an RLIS entry from a list of RLIS datums.

        The three first three datums of each entry describe the type,
        target function, and scope respectivly.  The type can be one of:
        conditional, watch, call, header, or footer.  Target function
        can be any function name.  Scope can be one of: point, local, or
        global.

        Conditional entries have the full form:
        - conditional function_name scope flags watch_var id range width

        Watch entries have the full form:
        - watch function_name scope watch_var var_width id width

        Call entries have the full form:
        - call function_name scope target_function id width

        Header entries have the full form:
        - header function_name scope id width

        Footer entries have the full form:
        - footer function_name scope id width
        """

        # Every RlisEntry contains this data
        self.type = None
        self.function_name = None
        self.scope = None
        self.id = None
        self.width = None

        # These members of only set for some types of RLIS entries
        self.watch_var = None
        self.var_width = None
        self.target = None
        self.if_branch = None
        self.switch_branch = None
        self.loop_branch = None
        self.range = None

        self._set_type(rlis_entry[0])
        self.function_name = rlis_entry[1]
        self._set_scope(rlis_entry[2])

        if self.type == self.CONDITIONAL:
            self._create_conditional(rlis_entry[3:])
        elif self.type == self.WATCH:
            self._create_watch(rlis_entry[3:])
        elif self.type == self.CALL:
            self._create_call(rlis_entry[3:])
        elif self.type == self.HEADER:
            self._create_header(rlis_entry[3:])
        elif self.type == self.FOOTER:
            self._create_footer(rlis_entry[3:])
        else:
            raise Exception("Unexpected RLIS type: %d" % (self.type))


    def _set_type(self, type_string):
        """Set the type of an RLIS entry from a string."""

        if type_string == "conditional":
            self.type = self.CONDITIONAL
        elif type_string == "watch":
            self.type = self.WATCH
        elif type_string == "call":
            self.type = self.CALL
        elif type_string == "header":
            self.type = self.HEADER
        elif type_string == "footer":
            self.type = self.FOOTER
        else:
            raise Exception("Invalid RLIS entry type: %s" % (type_string))

        return


    def _string_of_type(self):
        """Print string representation of type."""

        if self.type == self.CONDITIONAL:
            return "conditional"
        elif self.type == self.WATCH:
            return "watch"
        elif self.type == self.CALL:
            return "call"
        elif self.type == self.HEADER:
            return "header"
        elif self.type == self.FOOTER:
            return "footer"
        elif self.type == None:
            return "none"
        else:
            raise Exception("Unexpected RLIS type: %d\n" % self.type)


    def _set_scope(self, scope_string):
        """Set the scope of an RLIS entry from a string."""

        if scope_string == "point":
            self.scope = self.POINT
        elif scope_string == "global":
            self.scope = self.GLOBAL
        elif scope_string == "local":
            self.scope = self.LOCAL
        else:
            raise Exception("Invalid RLIS scope type: %s" % (scope_string))

        return


    def _string_of_scope(self):
        """Print string representation of scope."""

        if self.scope == self.POINT:
            return "point"
        elif self.scope == self.GLOBAL:
            return "global"
        elif self.scope == self.LOCAL:
            return "local"
        else:
            raise Exception("Unexpected RLIS scope: %d" % (self.scope))


    def _create_conditional(self, data):
        """"Create an RLIS entry of type conditional."""

        branch_flag = int(data[0])
        self.if_branch = branch_flag & self.IF == 1
        self.switch_branch = branch_flag & self.SWITCH == 1
        self.loop_branch = branch_flag & self.LOOP == 1
        self.watch_var = data[1]
        self.id = int(data[2])
        self.range = int(data[3])
        self.width = int(data[4])
        return


    def _create_watch(self, data):
        """"Create an RLIS entry of type watch."""

        self.watch_var = data[0]
        self.var_width = int(data[1])
        self.id = int(data[2])
        self.width = int(data[3])
        return


    def _create_call(self, data):
        """"Create an RLIS entry of type call."""

        self.target = data[0]
        self.id = int(data[1])
        self.width = int(data[2])
        return


    def _create_header(self, data):
        """"Create an RLIS entry of type header."""

        self.id = int(data[0])
        self.width = int(data[1])
        return


    def _create_footer(self, data):
        """"Create an RLIS entry of type footer."""

        self.id = int(data[0])
        self.width = int(data[1])
        return


    def __str__(self):
        """Print token."""
        out_string = "Token:\n"
        out_string += "    Type = %s\n" % (self._string_of_type())
        out_string += "    Function = %s\n" % (self.function_name)
        out_string += "    Scope = %s\n" % (self._string_of_scope())

        if self.id:
            out_string += "    Id = %d\n" % (self.id)

        if self.width:
            out_string += "    Width = %d\n" % (self.width)

        if self.range != None:
            out_string += "    Range = %d\n" % (self.range)

        # These members of only set for some types of RLIS entries
        if self.watch_var != None:
            out_string += "    Watching = %s\n" % (self.watch_var)

        if self.var_width != None:
            out_string += "    Width of watched var = %d\n" % (self.var_width)

        if self.target != None:
            out_string += "    Target = %s\n" % (self.target)

        if self.if_branch == True:
            out_string += "    Includes if-else conditionals\n"

        if self.switch_branch == True:
            out_string += "    Includes switches\n"

        if self.loop_branch == True:
            out_string += "    Includes loops\n"

        return out_string


class TokenTable:
    """TokenTable contains the information required to parse a BitlogTrace"""

    def __init__(self, rlis_file):
        """Create token table using data in rlis_file.

        The rlis_file has one rlis entry on each line.  Each entry is a
        space separated list of ASCII data.  The information from
        rlis_file is loaded into a scope specific table.
        """

        self.global_tokens = {}
        self.global_token_width = None

        self.local_token_tables = {}
        self.local_token_widths = {}

        self.point_tokens = []
        # self.point_token_width = None
        self.point_token_width = 1

        # Create a generic POINT token with no information
        #
        # NOTE: This assumes that all point tokens are in the footer.
        # But that may not always be correct.
        self.point_token = RlisEntry(["footer", "", "point", 0, 0])
        self.point_token.function_name = None
        self.point_token.id = None
        self.point_token.width = None


        rlis_lines = open(rlis_file, "r")
        for line in rlis_lines:
            rlis_entry = RlisEntry(line.split())
            if rlis_entry.scope == RlisEntry.GLOBAL:
                self._add_global_token(rlis_entry)
            elif rlis_entry.scope == RlisEntry.LOCAL:
                self._add_local_token(rlis_entry)
            elif rlis_entry.scope == RlisEntry.POINT:
                self._add_point_token(rlis_entry)
        rlis_lines.close()


    def _add_global_token(self, token):
        """Add token to the global token table."""

        assert token.scope == RlisEntry.GLOBAL

        assert self.global_token_width == token.width or \
                self.global_token_width == None
        self.global_token_width = token.width

        assert not token.id in self.global_tokens
        if token.range == None:
            self.global_tokens[token.id] = token
        else:
            for offset in range(token.range):
                resolved_token = copy.copy(token)
                resolved_token.id = token.id + offset
                self.global_tokens[resolved_token.id] = resolved_token

        return


    def _add_local_token(self, token):
        """Add token to the local token table."""

        assert token.scope == RlisEntry.LOCAL

        assert not token.function_name in self.local_token_widths or \
                self.local_token_widths[token.function_name] == token.width
        self.local_token_widths[token.function_name] = token.width

        local_token_tables = self.local_token_tables.setdefault(
                token.function_name, {})
        assert not token.id in local_token_tables
        if token.range == None:
            local_token_tables[token.id] = token
        else:
            for offset in range(token.range):
                resolved_token = copy.copy(token)
                resolved_token.id = token.id + offset
                local_token_tables[resolved_token.id] = resolved_token

        return


    def _add_point_token(self, token):
        """Add token to the point token table."""

        assert token.scope == RlisEntry.POINT

        assert self.point_token_width == token.width or \
                self.point_token_width == None
        self.point_token_width = token.width

        # Note that token.range has no effect on a POINT token and there
        # are no safety checks to see if a POINT token in defined
        # multiple times.
        self.point_tokens.append(token)

        return


    def has_point_footer(self, function_name):
        """Check for a POINT token in the FOOTER of function_name."""

        for token in self.point_tokens:
            if token.function_name == function_name and \
                    token.type == RlisEntry.FOOTER:
                return True
        return False


    def get_token(self, scope, token_id, context):
        """Lookup token_id in the current context and scope."""

        if scope == RlisEntry.GLOBAL:
            token = self.global_tokens[token_id]
        elif scope == RlisEntry.LOCAL:
            local_token_table = self.local_token_tables[context]
            token = local_token_table[token_id]
        elif scope == RlisEntry.POINT:
            token = self.point_token
        else:
            raise Exception("Unexpected scope: %d\n" % (scope))

        return token


    def __str__(self):
        """Print token tables."""
        out_string = ""

        if self.point_tokens:
            out_string += "---- Point Tokens (width %d): ----\n" % (self.point_token_width)
            for token in self.point_tokens:
                out_string += str(token)

        if self.global_tokens:
            out_string += "---- Global Tokens (width %d): ----\n" % (self.global_token_width)
            for token in self.global_tokens.values():
                out_string += str(token)

        for function_name in self.local_token_tables.keys():
            out_string += "---- Local Token Table for %s (width %d) ----\n" % (
                    function_name, self.local_token_widths[function_name])
            for token in self.local_token_tables[function_name].values():
                out_string += str(token)
        return out_string



