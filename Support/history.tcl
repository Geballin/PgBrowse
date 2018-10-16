
proc Init_History {} {
  global History
  global History_Index
  global Max_History_Index
  
  set Max_History_Index 15
  set History {}
  set History_Index -1
  # Check for the history file
  if { ![file exists "~/SQLScripts"]} { file mkdir "~/SQLScripts" }
  if { [file exists "~/SQLScripts/HiStOrY.tcl"] } {
      source "~/SQLScripts/HiStOrY.tcl"
      if { [llength $History]} { set History_Index 0 }
    } 
}

proc next_history {} {
  global History
  global History_Index
  global Max_History_Index
  global ui_vars
  
  if {[llength $History] == 0 } return
  # set the display to the next item in the history list
  incr History_Index
  if { $History_Index > [expr {[llength $History] -1 }]} {set History_Index 0 }
  #puts "Index: $History_Index Max: $Max_History_Index"
  $ui_vars(code) delete 1.0 end
  $ui_vars(code) insert 1.0 [lindex $History $History_Index]
}

proc prev_history {} {
  global History
  global History_Index
  global ui_vars
  
  if { [llength $History] == 0 } return
  #set the display to the previous item
  incr History_Index -1
  if { $History_Index == -1 } {
    set History_Index [expr { [llength $History] - 1 } ]
  }
  $ui_vars(code) delete 1.0 end
  $ui_vars(code) insert 1.0 [lindex $History $History_Index ]
}

proc add_history {cmd} {
  global History
  global History_Index
  global Max_History_Index
 
  if { $Max_History_Index == [expr {[llength $History] -1 } ]} {
    set History [lrange $History 1 end ]
  }
  lappend History $cmd
  set History_Index [llength $History]
  incr History_Index -1
  #puts "$History_Index"
}

proc save_history {} {
    global History
  catch {
      set fd [open ~/SQLScripts/HiStOrY.tcl w]
      puts $fd "set History [list $History ]"
      close $fd
  } result
}

#Init_History