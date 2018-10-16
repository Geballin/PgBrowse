

#if { [catch {package require Img } result ]} {
#	tk_messageBox -message "Img package not found.\
#	   Viewing images will not be possible." -type ok
# }

proc Scrolled_Canvas { c args } {
	frame $c
	eval {canvas $c.canvas \
		-xscrollcommand [list $c.xscroll set] \
		-yscrollcommand [list $c.yscroll set] \
		-highlightthickness 0 \
		-borderwidth 0} $args
	scrollbar $c.xscroll -orient horizontal \
		-command [list $c.canvas xview]
	scrollbar $c.yscroll -orient vertical \
		-command [list $c.canvas yview]
	grid $c.canvas $c.yscroll -sticky news
	grid $c.xscroll -sticky ew
	grid rowconfigure $c 0 -weight 1
	grid columnconfigure $c 0 -weight 1
	return $c.canvas
}

proc showAsImage { rawStr } {

  toplevel .asImage
  wm title .asImage "Image Viewer"
  
  set theView [Scrolled_Canvas .asImage.c -width 640 \
                -height 480 \
                -scrollregion {0 0 1000 1400} ]
                
   button .asImage.exit -text "Exit Image Window" -command {destroy .asImage}
   pack .asImage.exit -side bottom
   pack .asImage.c -side bottom -fill both -expand yes
   
   # critical step here...
   if { [catch {image create photo -data $rawStr} thePhoto] } {
        tk_messageBox -title PgBrowser \
                    -message "Can't recreate image: $thePhoto"  \
                    -type  ok
	destroy .asImage
        return 
    }
   #set thePhoto [image create photo -data $rawStr  ]
   
   set height [image height $thePhoto]
   set width  [image width  $thePhoto]
   

   $theView create image 0 0 -image $thePhoto -anchor nw -tag myPic
   $theView config -scrollregion [list 0 0 $width $height ]
 }
 
 # main code start here...
 
# wm withdraw .
 
# if { [catch {open /Users/jerry/desktop/Mary.jpg} fd ] } {
#  puts $fd 
# exit }
  
# fconfigure $fd -encoding binary  
 
# set str [read $fd]
# close $fd
 
# showAsImage $str
 