# et:ts=4
# portinstall.tcl
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide portinstall 1.0
package require portutil 1.0

set com.apple.install [target_new com.apple.install install_main]
target_runtype ${com.apple.install} always
target_provides ${com.apple.install} install
target_requires ${com.apple.install} main fetch extract checksum patch configure build destroot
target_prerun ${com.apple.install} install_start

set UI_PREFIX "---> "

proc install_start {args} {
	global UI_PREFIX portname portversion portrevision variations os.platform os.arch portvariants
    
	if { ![info exists portvariants] } {
		set portvariants ""
	}

	set vlist [lsort -ascii [array names variations]]

 	# Put together variants in the form +foo+bar for the registry
	foreach v $vlist {
		if { ![string equal $v ${os.platform}] && ![string equal $v ${os.arch}] } {
			set portvariants "${portvariants}+${v}"
		}
	}

	ui_msg "$UI_PREFIX [format [msgcat::mc "Installing %s %s_%s%s"] $portname $portversion $portrevision $portvariants]"
}

proc install_element {src_element dst_element} {
    # don't recursively copy directories
    if {[file isdirectory $src_element] && [file type $src_element] != "link"} {
	file mkdir $dst_element
    } else {
	file copy -force $src_element $dst_element
    }
    
    # if the file is a symlink, do not try to set file attributes
    # if the destination file is an existing directory,
    # do not overwrite its file attributes
    if {[file type $src_element] != "link" || [file isdirectory $dst_element]} {
	set attributes [file attributes $src_element]	
	for {set i 0} {$i < [llength $attributes]} {incr i} {
	    set opt [lindex $attributes $i]
	    incr i
	    set arg [lindex $attributes $i]
	    file attributes $dst_element $opt $arg
	    # set mtime on installed element
	    exec touch -r $src_element $dst_element
	}
    }
}

proc directory_dig {rootdir workdir regref {cwd ""}} {
    global installPlist
    set pwd [pwd]
    if {[catch {cd $workdir} err]} {
	puts $err
	return
    }
    
    foreach name [readdir .] {
	if {[string match $name "."] || [string match $name ".."]} {
	    continue
	}
	set element [file join $cwd $name]
	
	# XXX jpm's cross-platform code to find file separator
	# replace with [file seperator] with tcl 8.4
	if {![info exists root]} {
	    if {[string match [file tail "/monkey"] "monkey"]} {
		set root "/"
	    } elseif {[string match [file tail ":monkey"] "monkey"]} {
		set root ":" 
	    } else {
		set root "\\"		
	    }
	}
	
	if { [registry_prop_retr $regref installtype] == "image" } {
		set imagedir [registry_prop_retr $regref imagedir]
		set root [file join $root $imagedir]
	}
	
	set dst_element [file join $root $element]
	set src_element [file join $rootdir $element]
	# overwrites files but not directories
	if {![file exists $dst_element] || ![file isdirectory $dst_element]} {
	    ui_debug "installing file: $dst_element"
	    install_element $src_element $dst_element
	    lappend installPlist $dst_element
	}
	if {[file isdirectory $name] && [file type $name] != "link"} {
	    directory_dig $rootdir $name $regref [file join $cwd $name]
	}
    }
    cd $pwd
}

proc install_main {args} {
	global portname portversion portpath categories description long_description homepage depends_run installPlist package-install uninstall workdir worksrcdir pregrefix UI_PREFIX destroot portrevision maintainers ports_force portvariants

	# Begin the registry entry
   	set regref [registry_new $portname $portversion $portrevision $portvariants]
    
  	# Install the files	
	directory_dig ${destroot} ${destroot} ${regref}
    
	registry_prop_store $regref categories $categories
    
    if {[info exists description]} {
		registry_prop_store $regref description $description
    }
    if {[info exists long_description]} {
		registry_prop_store $regref long_description ${long_description}
    }
    if {[info exists homepage]} {
		registry_prop_store $regref homepage ${homepage}
    }
	if {[info exists maintainers]} {
		registry_prop_store $regref maintainers ${maintainers}
    }
	if {[info exists depends_run]} {
		registry_prop_store $regref run_depends $depends_run
    }
    if {[info exists installPlist]} {
		registry_prop_store $regref contents [fileinfo_for_index $installPlist]
	}
	if {[info exists package-install]} {
		registry_prop_store $regref package-install ${package-install}
    }
    if {[info proc pkg_uninstall] == "pkg_uninstall"} {
		registry_prop_store $regref uninstall [proc_disasm pkg_uninstall]
    }

	registry_write $regref 

    return 0
}

proc proc_disasm {pname} {
    set p "proc "
    append p $pname " {"
    set space ""
    foreach arg [info args $pname] {
	if {[info default $pname $arg value]} {
	    append p "$space{" [list $arg $value] "}"
	} else {
	    append p $space $arg
	}
	set space " "
    }
    append p "} {" [info body $pname] "}"
    return $p
}
