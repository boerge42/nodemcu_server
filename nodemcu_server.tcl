#!/bin/sh
# A Tcl comment, whose contents don't matter \
exec tclsh "$0" "$@"
#
#                nodemcu_server.tcl
#                ==================
#                 Uwe Berger; 2016
#
#
#  Server-Anteil des NodeMCU-Client/-Server-Konstrukts, welches die
#  -------------
#  Kommandos, die via TCP/IP vom Client gesendet werden, entgegen nimmt 
#  und an das ESP-Modul, auf welchem NodeMCU installiert ist, via 
#  serieller Schnittstelle weiterleitet. 
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

package require Tk

# theoretisch potentielle Konfigurationeinstellungen
set device						/dev/ttyUSB0
set baud						9600
set databits					8
set stopbits					1
set parity						n
set nodemcu_echo				0
set server_echo					1
set gui(color_term_bg)			black
set gui(color_term_fg)			green
set gui(color_term_cursor)		grey
set gui(color_term_serial_rx)	white
set gui(color_term_serial_tx)	yellow
set gui(color_term_server_rx)	blue
set gui(term_font)				"Courier 12"



# NodeMCU-Kommandos, aus denen auch die entsprechenden Buttons 
# generiert werden
set esp_cmd(getip) "print(''); print(wifi.sta.getip())"
set esp_cmd(filelist) "\
print('');\
l = file.list();\
for k,v in pairs(l) do\
print(''..k..' --> '..v)\
end\
"
set esp_cmd(fsinfo) "\
remaining, used, total=file.fsinfo();\
print('');\
print('File system info:')\
print('Total : '..total..' Bytes')\
print('Used  : '..used..' Bytes')\
print('Remain: '..remaining..' Bytes')\
"
set esp_cmd(fsformat) "file.format()"
set esp_cmd(restart) "node.restart()"
set esp_cmd(heapsize) "print(''); print(node.heap())"
set esp_cmd(sysinfo) "\
ma, mi, dev, cid, fid, fsi, fmo, fsp = node.info();\
print('');\
print('NodeMCU '..ma..'.'..mi..'.'..dev);\
print('ChipID    : '..cid);\
print('FlashID   : '..fid);\
print('FlashSize : '..fsi);\
print('FlashMode : '..fmo);\
print('FlashSpeed: '..fsp);\
"

# interne Variablen...
set mode				"$baud,$parity,$databits,$stopbits"
set com					""
set com_is_open			0
set nodemcu_echo_is		1

# *******************************************
proc gui_init {} {
	global device mode com esp_cmd nodemcu_echo server_echo gui
	wm title . "NodeMCU-Server" 
	wm resizable .
	wm minsize . 600 500

	frame .f1
	pack  .f1 -side bottom -fill x

	# Serielle Schnittstelle zu ESP-Modul
	labelframe .f1.f_con  -text "Connections"
	label .f1.f_con.l_port -text "Port"
	entry .f1.f_con.e_port -textvariable device -width 15
	label .f1.f_con.l_mode -text "Mode"
	entry .f1.f_con.e_mode -textvariable mode -width 15
	label .f1.f_con.l_nodemcu_echo -text "NodeMCU-Echo"
	checkbutton .f1.f_con.cb_nodemcu_echo -variable nodemcu_echo -command {nodemcu_set_echo}
	label .f1.f_con.l_server_echo -text "Server-Echo"
	checkbutton .f1.f_con.cb_server_echo -variable server_echo
	button .f1.f_con.b_con_open -text "Connect..." -command {serial_open}
	pack .f1.f_con -side left -fill x -pady 2 -padx 2
	pack .f1.f_con.l_port .f1.f_con.e_port\
		 .f1.f_con.l_mode .f1.f_con.e_mode\
		 .f1.f_con.b_con_open\
		 .f1.f_con.l_nodemcu_echo .f1.f_con.cb_nodemcu_echo\
		 .f1.f_con.l_server_echo .f1.f_con.cb_server_echo\
		 -side left  -pady 2 -padx 2
	
	# ...sonstige Kommandos
	labelframe .f1.f_prog  -text "Programm"
	button .f1.f_prog.term_clear -text "Clear Console" -command {term_clear} 
	button .f1.f_prog.exit -text "Exit" -command {exit} 
	pack .f1.f_prog -side right -fill x -pady 2 -padx 2
	pack .f1.f_prog.exit .f1.f_prog.term_clear -side right -padx 2 -pady 2
	
	# serielle Konsole
	labelframe .f_term -text "Terminal"
	text .f_term.term -bd 2 -bg $gui(color_term_bg) -fg $gui(color_term_fg)\
		-insertbackground $gui(color_term_cursor)\
		-font $gui(term_font)\
		-yscrollcommand ".f_term.yscroll set"
	scrollbar .f_term.yscroll -command {.f_term.term yview}
	pack .f_term -side left -fill both -expand yes -padx 2 -pady 2
	pack .f_term.yscroll -side right -fill y
	pack .f_term.term -fill both -expand yes
	# Konsolenfarben
	.f_term.term tag configure color_rx -background $gui(color_term_bg) -foreground $gui(color_term_serial_rx)
	.f_term.term tag configure color_tx -background $gui(color_term_bg) -foreground $gui(color_term_serial_tx)
	.f_term.term tag configure color_server_rx -background $gui(color_term_bg) -foreground $gui(color_term_server_rx)
	# Bindings fuer Konsole
	bind .f_term.term <Return> execute_term_cmd
	bind .f_term.term <Return> +break

	# Kommando-Buttons
	labelframe .f_cmd  -text "NodeMCU"
	pack .f_cmd -side left -fill both -expand no -padx 2 -pady 2
	# ...ESP-Kommandos
	label .f_cmd.l_esp_cmd -text "Commands..." -pady 3
	pack .f_cmd.l_esp_cmd -side top -anchor w
	foreach name [array names esp_cmd] {
		button .f_cmd.b_$name -text $name -padx 2 -pady 2 -command [list nodemcu_cmd $esp_cmd($name)]
		pack .f_cmd.b_$name -side top -fill x
	}
	
	set_widget_state .f_cmd disable
	focus .f_term.term
}

# *******************************************
proc set_widget_state {tl state} {
	foreach w [winfo children $tl] {
		$w configure -state $state
	}
}

# *******************************************
proc format_term_cmd_line {txt} {
	return [string trimleft $txt {> " "}]
}

# *******************************************
proc execute_term_cmd {} {
	set c .f_term.term
	if {[$c compare {insert + 1 lines} < end]} then {
		set l [format_term_cmd_line [$c get {insert linestart} {insert lineend}]]
		$c insert {end - 1 chars} \n[string trimright $l]
	} else {
		set l [format_term_cmd_line [$c get end-1lines end-1chars]]
	}
	serial_tx $l 1
	.f_term.term insert end "\n" color_tx
	focus .f_term.term
}

# *******************************************
proc nodemcu_set_echo {} {
	global com_is_open nodemcu_echo nodemcu_echo_is
	if {$com_is_open} {
		if {$nodemcu_echo != $nodemcu_echo_is} {
				serial_tx "uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, $nodemcu_echo)" 0
		}
		set nodemcu_echo_is $nodemcu_echo
	}
}

# *******************************************
proc term_clear {} {
	.f_term.term delete 0.0 end
	focus .f_term.term 
}

# *******************************************
proc serial_open {} {
	global device mode com com_is_open
	if {$com_is_open == 0} {
		set com [open $device RDWR]
		fconfigure $com -mode $mode -translation binary -buffering none -blocking 0
		fileevent $com readable {serial_rx $com}
		set com_is_open 1
		.f1.f_con.b_con_open configure -text "Disconnect..."
		set_widget_state .f_cmd normal
		nodemcu_set_echo
	} else {
		close $com
		set com_is_open 0
		.f1.f_con.b_con_open configure -text "Connect..."
		set_widget_state .f_cmd disable
	}
	focus .f_term.term
}

# *******************************************
proc nodemcu_cmd {txt} {
	global nodemcu_echo
	nodemcu_set_echo
	serial_tx $txt 1
	focus .f_term.term
}

# *******************************************
proc serial_rx {com} {
	.f_term.term insert end [read $com 1] color_rx
	.f_term.term see end
}

# *******************************************
proc serial_tx {txt echo} {
	global com com_is_open
	if {$echo} {.f_term.term insert end "\n" color_tx}
	foreach c [split $txt ""] {
		if {$echo} {.f_term.term insert end $c color_tx}
		if {$com_is_open} {puts -nonewline $com $c}
	}
	if {$echo} {.f_term.term insert end "\n" color_tx}
	if {$com_is_open} {puts -nonewline $com "\n\n"}
	.f_term.term see end
}

# ******************************************
proc server_rx {chan addr port} {
	global server_echo
	nodemcu_set_echo
	set cmd [gets $chan]
	if {$server_echo} {
		.f_term.term insert end "$cmd\n" color_server_rx
		.f_term.term see end
	}
	serial_tx $cmd 0
	close $chan
}

# *******************************************
# *******************************************
# *******************************************

# GUI...
gui_init

# Server-Socket definieren
socket -server server_rx 12345
