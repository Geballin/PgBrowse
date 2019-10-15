
proc Readme {} {

global basedir

toplevel .readme

wm title .readme "ReadMe for PgBrowse"


 text  .readme.command -width 100 -height 20  \
         -setgrid true  \
         -yscrollcommand {.readme.syc set } 
  ttk::scrollbar .readme.syc -command [list .readme.command yview]


 ttk::button .readme.exit -text "Exit Help" -command {destroy .readme}

 pack .readme.exit -side bottom 
 pack .readme.command -side left -expand true -fill both
 pack .readme.syc   -side left -fill y -pady 4

 # Insert the Help text 
set f [open [file normalize [file join [file dirname [info script]] "README.md"]] r]


 set contents [read $f]
 close $f
 .readme.command insert end $contents

}
