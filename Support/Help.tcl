
proc Help {} {

global basedir

toplevel .help

 listbox .help.cmd -width 25 -height 10  \
      -borderwidth 3 \
      -relief groove \
      -yscrollcommand {.help.sy set } 
  scrollbar .help.sy -command [list .help.cmd yview]

 text  .help.command -width 50 -height 10  \
         -padx 4 \
         -borderwidth 3 \
         -relief  groove \
         -setgrid true  \
         -yscrollcommand {.help.syc set } 
  scrollbar .help.syc -command [list .help.command yview]

  # listboxen post virtual event to indicate selection change
  bind .help.cmd <<ListboxSelect>> {
    set cmdIndex [.help.cmd curselection]
    set searchStr [.help.cmd get $cmdIndex] 
    set findStr ""
    # Fortunately the Help Text is formatted for an easy lookup
    append findStr "Command:     " "$searchStr"
    set where [.help.command search $findStr 1.0 ]
    .help.command see $where
  }

 button .help.exit -text "Exit Help" -command {destroy .help }

 pack .help.exit -side bottom 
 pack .help.cmd  -side left -expand true -fill both -padx 4 -pady 4
 pack .help.sy   -side left -fill y
 pack .help.command -side left -expand true -fill both -padx 4 -pady 4
 pack .help.syc   -side left -fill y -pady 4

 # Insert the Help text 
 set f [open [file join $basedir Support help HelpFile] r]
 set helpContents [read $f]
 close $f
 .help.command insert end $helpContents

  # Insert the keys to the help text
  set f [open [file join $basedir Support help allCmds] r]
  while {  [gets $f line ] >= 0 } {
    .help.cmd insert end [string trim $line]
  }
  close $f
}
