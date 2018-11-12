# Filename: pgconnect.tcl

# Read the pgbrowse config file and put the list of the sections to the global
# variable named $listname_arg
set PGBROWSE_CONFIG_FILENAME "~/.pgbrowse.cfg"
proc pg_connpopulate {} {
    global PGBROWSE_CONFIG_FILENAME
    set sectionslist ""
    if {[file exists $PGBROWSE_CONFIG_FILENAME]} {
	set inifile_handle [ini::open $PGBROWSE_CONFIG_FILENAME]
	set sectionslist [ini::sections $inifile_handle]
	ini::close $inifile_handle
    }
    return $sectionslist
}

proc pg_getconfignamed {configname} {
    global PGBROWSE_CONFIG_FILENAME
    set inifile_handle [ini::open $PGBROWSE_CONFIG_FILENAME]
    set config [ini::get $inifile_handle $configname]
    ini::close $inifile_handle
    return $config
}

proc pg_addconfignamed {configname config_arg} {
    global PGBROWSE_CONFIG_FILENAME
    set inifile_handle [ini::open $PGBROWSE_CONFIG_FILENAME]
    dict for {key value} $config_arg {
	ini::set $inifile_handle $configname $key $value
    }
    set sectionslist [ini::sections $inifile_handle]
    ini::commit $inifile_handle
    ini::close $inifile_handle
    return $sectionslist
}

proc pg_removeconfignamed {configname} {
    global PGBROWSE_CONFIG_FILENAME
    set inifile_handle [ini::open $PGBROWSE_CONFIG_FILENAME]
    ini::delete $inifile_handle $configname
    set sectionslist [ini::sections $inifile_handle]
    return $sectionslist
}

proc del_config {configname} {
  global dlg_savedFrame_scrolllist_value
  if {[tk_messageBox -message "Are you sure you want to delete $configname from the list of the configurations available ?" -type yesno]} {
      set dlg_savedFrame_scrolllist_value [pg_removeconfignamed $configname]
    }
}

proc load_config {configname} {
    set config [pg_getconfignamed $configname]
    lmap element [pg_conndefaults] {
	set textvariable [lindex $element 0]
	global $textvariable
	set $textvariable [dict get $config $textvariable]
    }
}

proc save_config {} {
    apply {{entryReturn} {
	if {$entryReturn ne ""} {
	    set configDict {}
	        lmap element [pg_conndefaults] {
		    set textvariable [lindex $element 0]
		    global $textvariable
		    dict append configDict $textvariable [set $textvariable]
		}
	    pg_addconfignamed $entryReturn $configDict
	    global dlg_savedFrame_scrolllist_value
	    set dlg_savedFrame_scrolllist_value [pg_connpopulate]
	}}} \
	[entry_dialog "Configuration name :" "pgBrowse" [expr {[.dlg.savedFrame.listbSaved curselection] != ""?[.dlg.savedFrame.listbSaved get [.dlg.savedFrame.listbSaved curselection]]:{}}] .dlg]
}

proc entry_dialog {message {title {}} {default_entry {}} {parentWindow .}} {
    global entryValue
    set entryValue {}
    set okAction {set entryValue [.entrydlg.entry get];destroy .entrydlg}
    set cancelAction {destroy .entrydlg}
    
    toplevel .entrydlg
    pack [label .entrydlg.lbl -text $message] -side top
    pack [entry .entrydlg.entry ] -side top
    pack [button .entrydlg.okbut -text "OK" -default active -command $okAction] -side right
    pack [button .entrydlg.cancelbut -text "Cancel" -command $cancelAction] -side right

    bind .entrydlg <Key-Return> $okAction
    bind .entrydlg <Key-Escape> $cancelAction

    .entrydlg.entry delete 0
    .entrydlg.entry insert 0 $default_entry
    
    wm title .entrydlg $title
    wm attributes .entrydlg -type dialog
    wm transient .entrydlg $parentWindow

    focus .entrydlg.entry
    tkwait window .entrydlg
    return $entryValue
}

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
  frame .dlg.savedFrame -bg lightblue
  frame .dlg.f -bg lightblue
  pack .dlg.savedFrame -side left -anchor sw -padx 15 -pady 5 -fill y
  pack .dlg.f -side right -anchor ne -padx 15 -pady 5 -fill both

  #  Create the saved list
  #
  global dlg_savedFrame_scrolllist_value
  set dlg_savedFrame_scrolllist_value [pg_connpopulate]
  
  grid [listbox .dlg.savedFrame.listbSaved -listvariable dlg_savedFrame_scrolllist_value -height 1 -yscrollcommand ".dlg.savedFrame.scrolllist set"] -column 0 -row 0 -columnspan 3 -sticky nsew
  grid [scrollbar .dlg.savedFrame.scrolllist -command ".dlg.savedFrame.listbSaved yview" -orient vertical] -column 3 -row 0 -sticky ns
  image create photo .dlg.savedFrame.trashIcon -file [file join [file dirname [file normalize [info script]]] "Support" "trash16.png"]
  grid [button .dlg.savedFrame.delBut -image .dlg.savedFrame.trashIcon -command \
	    {if {[.dlg.savedFrame.listbSaved curselection] != ""} {
		del_config [.dlg.savedFrame.listbSaved get [lindex [.dlg.savedFrame.listbSaved curselection] 0]]}} \
       ] -column 0 -row 1 
  grid [button .dlg.savedFrame.loadBut -text "Load" -command \
	    {if {[.dlg.savedFrame.listbSaved curselection] != ""} {
		load_config [.dlg.savedFrame.listbSaved get [lindex [.dlg.savedFrame.listbSaved curselection] 0]]}} \
       ] -column 1 -row 1  -pady 5
    grid [button .dlg.savedFrame.saveBut -text "Save" -command save_config] -column 2 -row 1  -pady 5
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

  #  Create the "Connect" and "Cancel" buttons
  add_button .dlg.f.cancel  "Cancel"  {exit}  1
  wm protocol .dlg WM_DELETE_WINDOW {exit}
  add_button .dlg.f.default "Connect" {set result Ok} 2

  .dlg.f.default configure -default active
  update
  wm minsize .dlg [winfo width .dlg] [winfo height .dlg]
  vwait result

  set result ""

  foreach prop [pg_conndefaults] { 
	set type [lindex $prop 2]
	set varname "$[lindex $prop 0]"
	set varval [subst $varname]

	if { $varval != "" } {
	    append result "[lindex $prop 0]=$varval "
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
	  set sticky "ws"
	} else { set sticky "es"	}

	button $path -text $text -command $command -highlightbackground lightblue 
	grid   $path -row $_next_row -column $column -sticky $sticky -pady 5
	grid rowconfigure $path $_next_row -weight 1
	grid columnconfigure $path $column -weight 1
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
