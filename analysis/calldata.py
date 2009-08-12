#! /usr/bin/python

import sys
import getopt
import re

def debug(debug_out):
    sys.stderr.write(debug_out)

class FunctionCalls:
    """Information about a function."""

    def __init__(self, fname, is_inline, file):
        """Set barebones function information.

        - fname is the name of the function
        - calls made by the function begins empty
        - is_inline is true if this is an inline function
        - file is the name of the file containing the function
        """

        self.name = fname
        self.calls = []
        self.is_inline = is_inline
        self.file = file


    def makes_call(self, called_function):
        """Add called_function to list of functions called by this function."""
        self.calls.append(called_function)


    def __str__(self):
        """Print information about this function."""
        output = ""
        if self.is_inline == True:
            output += "%s (inline):\n" % (self.name)
        elif self.is_line == None:
            output += "%s (unknown inline status):\n" % (self.name)
        else:
            output += "%s\n" % (self.name)
        for call in self.calls:
            output += "  %s\n" % (call)
        return output


class ProgramFunctionCalls:
    """Record function call information.

    This class builds the self.functions hash to store all functions
    that it knows about.  Each entry is an instance of FunctionCalls,
    recording the set of targets called by a particular function.
    """

    def __init__(self, in_file):
        """Create an empty listing."""
        self.called_by = None
        self.functions = {}
        self._load_from_file(in_file)


    def _reset_called_by(self):
        """Invalidate the reverse lookup table.

        This should be called whenever the functions hash is changed.
        """
        self.called_by = None


    def add_function(self, fname, is_inline, file):
        """Add fname to functions.

        Add fname if nothing is known about it.
        """
        self._reset_called_by()
        if fname not in self.functions:
            self.functions[fname] = FunctionCalls(fname, is_inline, file)
        assert self.functions[fname].is_inline == is_inline
        assert self.functions[fname].file == file


    def add_call(self, from_function, to_function, is_inline, file):
        """Add call from caller from_function to target to_function.

        The from_function is added to the set of functions tracked by
        this class if it is not already tracked.  The to_function is NOT
        added to the set of functions tracked by this class.
        """

        self._reset_called_by()
        self.add_function(from_function, is_inline, file)
        self.functions[from_function].makes_call(to_function)


    def get_entry_points(self, roi):
        """Return functions acting as entry points to within the ROI.

        Region of interest (ROI) describes a set of functions that are
        of particular interest.
        """

        # Update called_by if required
        if self.called_by == None:
            self._build_called_by()

        # Find set of entry points into ROI
        entry_points = []
        for target in roi:
            for caller in self.called_by[target]:
                # If caller is not in ROI then the target is an entry
                # point.  Add target to entry_points if it is not yet
                # accounted for.
                if caller not in roi and target not in entry_points:
                    entry_points.append(target)
        return entry_points


    def get_roi_functions(self, roi_prefixes):
        """Get functions in an ROI.

        Returns any function matching any of the specified roi_prefixes.
        """
        roi = []
        for prefix in roi_prefixes:
            prefixRe = re.compile(prefix)
            for caller in self.functions.keys():
                if prefixRe.match(caller) != None and caller not in roi:
                    roi.append(caller)
        return roi


    def _load_from_file(self, in_file):
        """Load data from in_file into this class instance.

        The format of in_file is one entry per line with each line
        containing the space separated fields:
            is_inline caller_file caller_name target_name
        If the target name is the special token "__DECLARATION__" then
        the caller is simply added to the set of tracked functions.
        Else it is recorded that the caller makes a call to the target.
        """
        self._reset_called_by()
        fid = open(in_file, "r")
        for line in fid:
            (inline_str, caller_file, caller, target) = line.split()
            is_inline = (inline_str == "true" or
                    inline_str == "True" or
                    inline_str == "TRUE")
            if target == "__DECLARATION__":
                self.add_function(caller, is_inline, file)
            else:
                self.add_call(caller, target, is_inline, file)
        fid.close()


    def _build_called_by(self):
        """Generate a table containing called by data.

        For function f this hash stores the set of functions known (from
        the data stored in self.functions) to call f.
        """
        self.called_by = {}
        for target in self.functions.keys():
            self.called_by[target] = []
            for caller in self.functions.keys():
                if target in self.functions[caller].calls:
                    self.called_by[target].append(caller)


    def __str__(self):
        """Print what each function calls."""

        output = ""
        for function in self.functions.values():
            output += str(function)
        return output


def usage():

    print """Usage: calldata.py [-h] <rawCallFile>

    <rawCallFile>
            File contining raw call information with one function call
            on each line formated as:
                isInlineCaller callerName targetName
            where isInlineCaller is true if callerName is an inlined
            function.

    -r, --roi=roi_prefixes
            The roi_prefixes describe the functions making up the region
            of interest (ROI).  More than one prefix may be specified
            using a quoted string of space separated prefixes.  Any
            function matching any of the specified prefixes is assumed
            to be in the ROI.

    -e, --entry
            Print names of functions acting as entry points into the
            reigion of interest.

    -b, --body
            Print all calls from body functions, except for those to
            entry functions, from within the ROI.

    -l, --lis
            Output LIS script encoding logging for the ROI using local
            caller specific identifiers and including ALL local calls
            (compare this to --kis).

    -k, --kis
            Output LIS script encoding logging for the ROI using local
            caller specific identifiers and only including local calls
            that are to functions within the ROI.

    -g, --gid
            Output LIS script encoding logging for the ROI using global
            function identifiers.

    -m, --main
            Define the name of the entry point into the program.  The
            default value is 'main'.

    -h, --help
            Print this help information.
    """
    return


if __name__ == '__main__':

    # Process command line
    rawCallsFile = None
    action = "lis"
    roi_prefix_file = None
    main = "main"
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hr:eblkgm:",
                ["help", "roi=", "entry", "body", "lis", "kis", "gid", "main"])
    except getopt.GetoptError, err:
        sys.stderr.write(err.msg)
        usage()
        sys.exit(2)
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-r", "--roi"):
            roi_prefix_file = a
        elif o in ("-e", "--entry"):
            action = "entry"
        elif o in ("-b", "--body"):
            action = "body"
        elif o in ("-l", "--lis"):
            action = "lis"
        elif o in ("-l", "--kis"):
            action = "kis"
        elif o in ("-g", "--gid"):
            action = "gid"
        elif o in ("-m", "--main"):
            main = a
        else:
            assert False, "Unhandled option: " + o
    if len(args) != 1:
        sys.stderr.write("Must specify the input file name\n")
        usage()
        sys.exit(2)
    rawCallsFile = args[0]

    # Create table
    call_data = ProgramFunctionCalls(rawCallsFile)

    # Generate list of functions in ROI
    if roi_prefix_file:
        prefix_file = open(roi_prefix_file, "r")
        roi_lines = ""
        for line in prefix_file:
            roi_lines += line[:-1] + " "
        roi_prefixes = roi_lines.split()
        prefix_file.close()
    else:
        roi_prefixes = None

    # Calcualet the ROI, entry functions, and body functions
    roi = call_data.get_roi_functions(roi_prefixes)
    entry_functions = call_data.get_entry_points(roi)
    if main in roi and main not in entry_functions:
        entry_functions.append(main)

    # Do stuff!
    if action == "body":
        for body_function in roi:
            for target in call_data.functions[body_function].calls:
                if target not in entry_functions:
                    print body_function, target

    elif action == "entry":
        for entry_function in entry_functions:
            print entry_function

    elif action == "lis":
        # Trace entry points
        for entry_function in entry_functions:
            print "header %s global" % entry_function
        # Trace local calls to non-entry functions
        for body_function in roi:
            for target in call_data.functions[body_function].calls:
                if target not in entry_functions:
                    print "call %s local %s" % (body_function, target)
        # Trace returns
        for function in roi:
            print "footer %s point" % function

    elif action == "kis":
        # Trace entry points
        for entry_function in entry_functions:
            print "header %s global" % entry_function
        # Trace local calls to non-entry functions
        for body_function in roi:
            for target in call_data.functions[body_function].calls:
                if target not in entry_functions and target in roi:
                    print "call %s local %s" % (body_function, target)
        # Trace returns
        for function in roi:
            print "footer %s point" % function

    elif action == "gid":
        # Trace returns
        for function in roi:
            print "header %s global" % function
            print "footer %s point" % function

    else:
        print "Please specify -e, -b, or -l action option."
        usage()
        sys.exit(2)
