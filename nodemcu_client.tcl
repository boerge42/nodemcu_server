#!/bin/sh
# A Tcl comment, whose contents don't matter \
exec tclsh "$0" "$@"
#
#                nodemcu_client.tcl
#                ==================
#                 Uwe Berger; 2016
#
#
# Sendet den Inhalt der, in den Aufruf-Parametern angegebenen, Datei
# an den nodemcu-Server
#
# Aufruf-Parameter:
# -----------------
# -f <fname> : Lua-Datei
# -w         : Lua-Datei im nodemcu-Dateisystem anlegen/aendern
# -e         : Lua-Datei nach Anlage auf nodemcu-Dateisystem ausfuehren
# -c         : Lua-Datei uebersetzen und als .lc auf nodemcu ablegen 
#
#
#  ---------
#  Have fun!
# 
#  ---------------------------------------------------------------------
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#
#  ---------------------------------------------------------------------

set h localhost
set p 12345

# **************************************************
# http://wiki.tcl.tk/17342
proc getopt {_argv name {_var ""} {default ""}} {
	upvar 1 $_argv argv $_var var
	set pos [lsearch -regexp $argv ^$name]
	if {$pos>=0} {
		set to $pos
		if {$_var ne ""} {
			set var [lindex $argv [incr to]]
		}
		set argv [lreplace $argv $pos $to]
		return 1
	} else {
		if {[llength [info level 0]] == 5} {set var $default}
		return 0
	}
}

# **************************************************
proc send2server {s} {
	global h p
#	puts $s
#	return
	if {[catch {set chan [socket $h $p];puts $chan $s;flush $chan;close $chan}]} {
		puts "Fehler: nodemcu-Server nicht verfuegbar!"
		exit 1
	}
}

# **************************************************
# **************************************************
# **************************************************

# Aufruf-Parameter einlesen/pruefen
set with_cmd_dofile 	[getopt argv -e]
set create_nodemcu_file	[getopt argv -w]
set with_lua_compile   [getopt argv -c]
set fname ""
getopt argv -f fname

# ...es muss ein Datei angegeben sein, die auch existiert!
if {([string length Fname] == 0) || ([file exists $fname] == 0)} {
	puts "Fehler: keine Option -f angeben oder Datei $fname existiert nicht!"
	exit 1
}

# ...Parameter -e nur dann, wenn auch -w angegeben ist
if {($with_cmd_dofile == 1) && ($create_nodemcu_file == 0)} {
	puts "Fehler: Option -e nur mit -w zusammen!"
	exit 1
}

# ...Parameter -c nur dann, wenn auch -w angegeben ist
if {($with_lua_compile == 1) && ($create_nodemcu_file == 0)} {
	puts "Fehler: Option -c nur mit -w zusammen!"
	exit 1
}

# Lua-Datei oeffnen/einlesen und als Liste bereitstellen
set fd [open $fname r] 
set data [read $fd [file size $fname]]
close $fd
set lines [split $data \n]

# Lua-Datei auf ESP oeffen
if {$create_nodemcu_file} {
	send2server "file.open('$fname', 'w+')"
}

# Liste zeilenweise an Server senden
foreach line $lines {
	if {$create_nodemcu_file} {
		send2server "file.writeline(\[\[$line\]\])"
	} else {
		send2server $line
	}
}

# Lua-Datei auf ESP schliessen, uebersetzen und starten
if {$create_nodemcu_file} {
	send2server "file.close()"
}
if {$with_lua_compile} {
	send2server "node.compile('$fname')"
}
if {$with_cmd_dofile} {
	send2server "dofile('$fname')"
}

exit 0
