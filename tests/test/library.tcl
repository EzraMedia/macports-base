set autoconf "../../../Mk/macports.autoconf.mk"

# Set of procs used for testing.

# Sets $bindir variable from macports.autoconf.mk
# autogenerated file.
proc load_variables {} {
    global autoconf
    global bindir
    global datadir

    if { [file exists $autoconf] == 0 } {
        puts "$autoconf does not exist."
        exit 1
    }

    set line [get_line $autoconf "prefix"]
    set prefix [lrange [split $line " "] 1 1]

    set line [get_line $autoconf "bindir"]
    set bin [lrange [split $line "/"] 1 1]

    set bindir $prefix/$bin/
    set datadir $prefix/share

    #TO DO: Add PORTSRC var
}

# Sets initial directories
proc set_dir {} {
    global datadir
    set path [pwd]

    file delete -force /tmp/macports-tests/
    file delete -force PortIndex PortIndex.quick

    file mkdir /tmp/macports-tests/ports
    file mkdir /tmp/macports-tests/opt/local/etc/macports/
    file mkdir /tmp/macports-tests/opt/local/share/
    file mkdir /tmp/macports-tests/opt/local/var/macports/receipts/
    file mkdir /tmp/macports-tests/opt/local/var/macports/registry/
    file mkdir /tmp/macports-tests/opt/local/var/macports/build/

    file link -symbolic /tmp/macports-tests/opt/local/share/macports $datadir/macports
    file link -symbolic /tmp/macports-tests/ports/test $path/test
}

# Run portindex
proc port_index {} {
  global bindir

  set cmd "portindex"

  file copy sources.conf /tmp/macports-tests/opt/local/etc/macports/
  set result [exec $bindir$cmd 2>&1]
  file copy PortIndex PortIndex.quick /tmp/macports-tests/ports/
}

# Executes port clean.
proc port_clean {} {
    global bindir

    set args "clean"
    set cmd "port"

    set result [eval exec $bindir$cmd $args]]
}

# Runs the portfile.
proc port_run {} {
    global bindir

    set args "-d test"
    set output "output"
    set cmd "port"

    set result [catch {eval exec $bindir$cmd $args >&output} ]
    return $result
}

# Returns the line containint a given string
# from a given file, or -1 if nothing is found.
proc get_line {filename lookup} {
    set fp [open $filename r]

    while {[gets $fp line] != -1} {
        set line [string tolower $line]

        if {[string first $lookup $line 0] != -1} {
            close $fp
            return $line
        }
    }
    return -1
}