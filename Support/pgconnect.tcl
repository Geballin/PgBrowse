# Filename: pgconnect.tcl

proc connect_dialog { } {
	
  global _next_row
  set _next_row 0
  set set_focus true
  
  #  Create a new window with the title 
  #     "Connection Info"
  #
  set w [toplevel .dlg]
  wm title .dlg "Connection Info"
  .dlg configure -bg lightblue
  frame .dlg.savedFrame
  frame .dlg.f -bg lightblue
  pack .dlg.savedFrame -side left -anchor nw -padx 15 -pady 5 -fill y
  pack .dlg.f -side right -anchor ne -padx 15 -pady 5 -expand 0 -fill both

  #  Create the saved list
  #
  grid [listbox .dlg.savedFrame.listbSaved -yscrollcommand ".dlg.savedFrame.scrolllist set"] -column 0 -row 0 -columnspan 3 -sticky nsew
  grid [scrollbar .dlg.savedFrame.scrolllist -command ".dlg.savedFrame.listbSaved yview" -orient vertical] -column 3 -row 0 -sticky ns
  image create photo .dlg.savedFrame.trashIcon -file [file join [file dirname [file normalize [info script]]] "Support" "trash16.png"]
  grid [button .dlg.savedFrame.delBut -image .dlg.savedFrame.trashIcon] -column 0 -row 1 
  grid [button .dlg.savedFrame.loadBut -text "Load"] -column 1 -row 1
  grid [button .dlg.savedFrame.saveBut -text "Save"] -column 2 -row 1
  bind .dlg.savedFrame.listbSaved <Double-Button-1> "consEditConf"
  bind .dlg.savedFrame.listbSaved {%W yview scroll [expr {%D/-120}] units}
  grid rowconfigure .dlg.savedFrame 0 -weight 1
  grid columnconfigure .dlg.savedFrame 0 -weight 1

  
  #  Create the labels and entry fields for this dialog
  #

  foreach prop [pg_conndefaults] { 
	
	set varname    [lindex $prop 0]
	set label_text [lindex $prop 1]
	set type       [lindex $prop 2]
	set length     [lindex $prop 3]
	set default    [lindex $prop 4]

	if { $type != "D" } {

	  global $varname

	  set $varname $default
	  
	  set entry [add_label_field .dlg.f $label_text $varname]

	  if { $type == "*" } {
			$entry configure -show "*"
	  }

	  if { $set_focus == "true" } {
		focus -force $entry
		set set_focus false
	  }
	}
  }

  #  Create the "Connect" and "Cancel" buttons
  add_button .dlg.f.cancel  "Cancel"  {exit}  1
  wm protocol .dlg WM_DELETE_WINDOW {exit}
  add_button .dlg.f.default "Connect" {set result Ok} 2

  .dlg.f.default configure -default active

  vwait result

  set result ""

  foreach prop [pg_conndefaults] { 

	set type [lindex $prop 2]

	if { $type != "D" } {

	  set varname "$[lindex $prop 0]"
	  set varval [subst $varname]

	  if { $varval != "" } {
		append result "[lindex $prop 0]=$varval "
	  }
	}
  }

  destroy .dlg 
  #puts $result
  return $result
}

proc add_label_field { w text textvar } {

	global _next_row 

	set _next_row  [expr {$_next_row + 1}]
	set label_path "$w.label_$textvar"
	set entry_path "$w.$textvar"

	label $label_path -text $text -bg lightblue
	grid  $label_path -row $_next_row -column 1 -sticky e

	entry $entry_path -textvariable $textvar
	grid  $entry_path -row $_next_row -column 2 -sticky w

	bind $entry_path <Return> "$w.default invoke"

	return $entry_path
}

proc add_button { path text command column } {

	global _next_row 

	if { $column == 1 } {
	  set _next_row  [expr {$_next_row + 1}]
	  set sticky "w"
	} else { set sticky "e"	}

	button $path -text $text -command $command -highlightbackground lightblue 
	grid   $path -row $_next_row -column $column -sticky $sticky -pady 5

	bind $path <Return> "$path invoke"
}

proc connect { } {

 # package require Pgtcl

  set result "retry"

  while { $result == "retry" } {
    set connstr [connect_dialog]

    if { [catch {pg_connect -conninfo $connstr} conn] } {
      set result [tk_messageBox \
      				-icon warning \
					-message $conn \
					-title "Connection failed" \
					-type retrycancel]
    } else {
	  return [list $conn $connstr]
    }
  }
  return {}
}
