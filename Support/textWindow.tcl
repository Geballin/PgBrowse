
proc showAsText {theString} {

global basedir

toplevel .asText

wm title .asText "Text Display Window"


 text  .asText.command  \
         -padx 4 \
         -borderwidth 3 \
         -relief  groove \
         -setgrid true  \
         -yscrollcommand {.asText.sy set } 
  scrollbar .asText.sy -command [list .asText.command yview]


 button .asText.exit -text "Exit Text Window" -command {destroy .asText}

 pack .asText.exit -side bottom 
 pack .asText.command -side left -expand true -fill both -padx 4 -pady 4
 pack .asText.sy   -side left -fill y -pady 4

 # Insert the  text 
 .asText.command insert end $theString

}
