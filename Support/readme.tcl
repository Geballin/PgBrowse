
proc Readme {} {

global basedir

toplevel .readme

wm title .readme "ReadMe for PgBrowse"


 text  .readme.command -width 100 -height 20  \
         -padx 4 \
         -borderwidth 3 \
         -relief  groove \
         -setgrid true  \
         -yscrollcommand {.readme.syc set } 
  scrollbar .readme.syc -command [list .readme.command yview]


 button .readme.exit -text "Exit Help" -command {destroy .readme}

 pack .readme.exit -side bottom 
 pack .readme.command -side left -expand true -fill both -padx 4 -pady 4
 pack .readme.syc   -side left -fill y -pady 4

 # Insert the Help text 
set f [open [file join file normalize [file dirname [info script]] "README.md"] r]


 set contents [read $f]
 close $f
 .readme.command insert end $contents

}
