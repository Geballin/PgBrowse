#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
# exec tclsh "$0" ${1+"$@"}

#an attempt to repackage the hv.tcl program as a
#callable procedure to display html documentation.

# These are loaded by the main line code

#package require Tkhtml
#package require Img

proc initSystem {} {
 
# some image standins    
image create photo biggray -data {
    R0lGODdhPAA+APAAALi4uAAAACwAAAAAPAA+AAACQISPqcvtD6OctNqLs968+w+G4kiW5omm
    6sq27gvH8kzX9o3n+s73/g8MCofEovGITCqXzKbzCY1Kp9Sq9YrNFgsAO///
    }
image create photo smgray -data {
    R0lGODdhOAAYAPAAALi4uAAAACwAAAAAOAAYAAACI4SPqcvtD6OctNqLs968+w+G4kiW5omm
    6sq27gvH8kzX9m0VADv/
    }
image create photo nogifbig -data {
    R0lGODdhJAAkAPEAAACQkADQ0PgAAAAAACwAAAAAJAAkAAACmISPqcsQD6OcdJqKM71PeK15
    AsSJH0iZY1CqqKSurfsGsex08XuTuU7L9HywHWZILAaVJssvgoREk5PolFo1XrHZ29IZ8oo0
    HKEYVDYbyc/jFhz2otvdcyZdF68qeKh2DZd3AtS0QWcDSDgWKJXY+MXS9qY4+JA2+Vho+YPp
    FzSjiTIEWslDQ1rDhPOY2sXVOgeb2kBbu1AAADv/
    }
image create photo nogifsm -data {
    R0lGODdhEAAQAPEAAACQkADQ0PgAAAAAACwAAAAAEAAQAAACNISPacHtD4IQz80QJ60as25d
    3idKZdR0IIOm2ta0Lhw/Lz2S1JqvK8ozbTKlEIVYceWSjwIAO///
    }
global underlineHyper LastFile PrevFiles NextFiles

global showImages showTableStruct lastDir

  set underlineHyper 1
  set LastFile {}
  set PrevFiles {}
  set NextFiles {}
  set showImages 1
  set showTableStruct 0
  set lastDir [pwd]

 # new toplevel for this window
toplevel .dv

}

# A font chooser routine.
#
# .h.h config -fontcommand pickFont
proc pickFont {size attrs} {
  global tcl_platform
  #puts "FontCmd: $size $attrs"
  set a [expr {-1<[lsearch $attrs fixed]?{courier}:{times}}]
  set b [expr {-1<[lsearch $attrs italic]?{italic}:{roman}}]
  set c [expr {-1<[lsearch $attrs bold]?{bold}:{normal}}]
  if { $tcl_platform(os) eq "Darwin" && $a eq "times"} { incr size  2 }
  if {$tcl_platform(os) eq "Darwin" && $a eq "courier"} { incr size }
  set d [expr {int(12*pow(1.2,$size-4))}]
  list $a $d $b $c
} 

# This routine is called for each form element
#
proc FormCmd {n cmd args} {
  # puts "FormCmd: $n $cmd $args"
  switch $cmd {
    select -
    textarea -
    input {
      set w [lindex $args 0]
      label $w -image nogifsm
    }
  }
}

proc ImageCmd {args} {
  global OldImages Images showImages
  if {!$showImages} {
    return smgray
  }
  set fn [lindex $args 0]
  if {[info exists OldImages($fn)]} {
    set Images($fn) $OldImages($fn)
    unset OldImages($fn)
    return $Images($fn)
  }
  if {[catch {image create photo -file $fn} img]} {
    return smgray
  }
  if {[image width $img]*[image height $img]>20000} {
    global BigImages
    set b [image create photo -width [image width $img] \
           -height [image height $img]]
    set BigImages($b) $img
    set img $b
    after idle "MoveBigImage $b"
  }
  set Images($fn) $img
  return $img
}

proc MoveBigImage b {
  global BigImages
  if {![info exists BigImages($b)]} return
  $b copy $BigImages($b)
  image delete $BigImages($b)
  unset BigImages($b)
  update
}

# This routine is called for every <APPLET> markup
#
proc AppletCmd {w arglist} {
  # puts "AppletCmd: w=$w arglist=$arglist"
  label $w -text "The Applet $w" -bd 2 -relief raised
}

# This routine is called for every <SCRIPT> markup
#
proc ScriptCmd {args} {
  # puts "ScriptCmd: $args"
}

namespace eval tkhtml {
    array set Priv {}
}

# This procedure is called when the user clicks on a hyperlink.
# See the "bind .h.h.x" below for the binding that invokes this
# procedure
#
proc HrefBinding {x y} {
  # koba & dg marking text
  .dv.h.h selection clear
  set ::tkhtml::Priv(mark) $x,$y
  set list [.dv.h.h href $x $y]
  if {![llength $list]} {return}
  foreach {new target} $list break
  if {$new!=""} {
    regsub -all {^{|}$}  $new {} new
    global LastFile
    set pattern $LastFile#
    set len [string length $pattern]
    incr len -1
    if {[string range $new 0 $len]==$pattern} {
      incr len
      .dv.h.h yview [string range $new $len end]
    } else {
      LoadFile $new
    }
  }
}
# Read a file
#
proc ReadFile {name} {
  # dgroth fix for files containing anchors
  #puts "Before Stripping: $name"
  #regexp "\{(.+)\}" $name match name
  regexp {(.+)#} $name match name
  #puts "In ReadFile: $name"
  if {[catch {open $name r} fp]} {
    tk_messageBox -icon error -message $fp -type ok
    return {}
  } else {
    fconfigure $fp -translation binary
    set r [read $fp [file size $name]]
    close $fp
    return $r
  }
}
# Load a file into the HTML widget
#
proc LoadFile {name} {
  # jcw 06/10/2000 - drop "#tag", if present
  set basename [lindex [split $name #] 0]
  set html [ReadFile $basename]
  if {$html==""} return
  Clear
  global LastFile
  
  # jcw: new code for back/forward history
  #   PrevFiles are previous pages, last seen is at end
  #   NextFiles are next pages, pushed back while retreating
  global PrevFiles NextFiles
  #puts "$name: $PrevFiles << $LastFile >> $NextFiles"
  if {$name != $LastFile && $LastFile != ""} {
      if {$name == [lindex $PrevFiles end]} {
          set NextFiles [linsert $NextFiles 0 $LastFile]
          set PrevFiles [lreplace $PrevFiles end end]
      } else {
          lappend PrevFiles $LastFile
          
          if {$name == [lindex $NextFiles 0]} {
              set NextFiles [lrange $NextFiles 1 end]
          } else {
              set NextFiles {}
          }
      }
  }
  # jcw: show which page is being displayed
  wm title .dv [file tail $name ]
  # jcw: end of new code
  
  set LastFile $name
   .dv.h.h config -base $name
  # jcw 06/10/2000 - deal with text files (as suggested by Uwe Koloska)
  if {![regexp -nocase {<html>|<!doctype|<body} [string range $html 0 200]]} {
      set html "<pre>$html</pre>\n"
  }
  # jcw: end of changed code
  .dv.h.h parse $html
  ClearOldImages

  # dgroth 13/11/2003 add jumping to internal name
  if {[regexp {(.+)#(.+)} $LastFile match file anchor]} {
       #tk_messageBox -title "Info!" -icon info -message "message jumping to $anchor" -type ok
       .dv.h.h yview $anchor
   }
}
proc ChangeUnderline args {
  global underlineHyper
  .dv.h.h config -underlinehyperlinks $underlineHyper
}

proc ShowTableStruct args {
  global showTableStruct HtmlTraceMask
  if {$showTableStruct} {
    set HtmlTraceMask [expr {$HtmlTraceMask|0x8}]
    .dv.h.h config -tablerelief flat
  } else {
    set HtmlTraceMask [expr {$HtmlTraceMask&~0x8}]
    .dv.h.h config -tablerelief raised
  }
  Refresh
}

proc Refresh {args} {
  global LastFile
  if {![info exists LastFile]} return
  LoadFile $LastFile
}

proc buildHtmlViewer {} {
    #First some menu stuff...
    frame .dv.mbar -bd 2 -relief raised
    pack .dv.mbar -side top -fill x
    menubutton .dv.mbar.file -text File -underline 0 -menu .dv.mbar.file.m
    pack .dv.mbar.file -side left -padx 5
    set m [menu .dv.mbar.file.m]
    $m add command -label Open -underline 0 -command Load
    $m add command -label Refresh -underline 0 -command Refresh
    $m add separator
    $m add command -label Close -underline 1 -command [list destroy .dv]
    menubutton .dv.mbar.view -text View -underline 0 -menu .dv.mbar.view.m
    pack .dv.mbar.view -side left -padx 5
    set m [menu .dv.mbar.view.m]
    $m add checkbutton -label {Underline Hyperlinks} -variable underlineHyper
    $m add checkbutton -label {Show Table Structure} -variable showTableStruct
    $m add checkbutton -label {Show Images} -variable showImages
    $m add separator
    $m add command -label Home -underline 1 -command \
                                      {LoadFile [lindex $PrevFiles 0]}
    $m add command -label Back -underline 1 -command \
                                      {LoadFile [lindex $PrevFiles end]}
    $m add command -label Forward -underline 1 -command \
                                      {LoadFile [lindex $NextFiles 0]}


# Construct the main HTML viewer
#
    frame .dv.h
    pack .dv.h -side top -fill both -expand 1
    html .dv.h.h \
      -yscrollcommand {.dv.h.vsb set} \
      -xscrollcommand {.dv.f2.hsb set} \
      -padx 5 \
      -pady 9 \
      -fontcommand pickFont \
      -formcommand FormCmd \
      -imagecommand ImageCmd \
      -scriptcommand ScriptCmd \
      -appletcommand AppletCmd \
      -underlinehyperlinks 1 \
      -unvisitedcolor blue \
      -bg beige -tablerelief raised
    
# Pack the HTML widget into the main screen.
#
    pack .dv.h.h -side left -fill both -expand 1
    scrollbar .dv.h.vsb -orient vertical -command {.dv.h.h yview}
    pack .dv.h.vsb -side left -fill y
    
    frame .dv.f2
    pack .dv.f2 -side top -fill x
    frame .dv.f2.sp -width [winfo reqwidth .dv.h.vsb] -bd 2 -relief raised
    pack .dv.f2.sp -side right -fill y
    scrollbar .dv.f2.hsb -orient horizontal -command {.dv.h.h xview}
    pack .dv.f2.hsb -side top -fill x
    
    bind .dv.h.h.x <1> {HrefBinding %x %y}
    # marking text with the mouse and copying to the clipboard just with tkhtml2.0 working
    bind .dv.h.h.x <B1-Motion> {
    %W selection set @$::tkhtml::Priv(mark) @%x,%y
    clipboard clear
    # avoid tkhtml0.0 errors 
    # anyone can fix this for tkhtml0.0
    catch {
        clipboard append [selection get]
    }
   }
  # display a hand cursor when mouse over a hypertext link
  bind HtmlClip <Motion> {
  set parent [winfo parent %W]
  set url [$parent href %x %y] 
  if {[string length $url] > 0} {
    $parent configure -cursor hand2
  } else {
    $parent configure -cursor {}
   }
  }
  #some useful bindings
  bind .dv <KeyPress-space> {
    .dv.h.h yview scroll +1 pages
    }
    bind .dv <KeyPress-Next> {
        .dv.h.h yview scroll +1 pages 
    }
    bind .dv <KeyPress-Down> {
        .dv.h.h yview scroll +2 units
    }
    bind .dv <Shift-space> {
        .dv.h.h yview scroll -1 pages
    }
    bind .dv <KeyPress-Prior> {
        .dv.h.h yview scroll -1 pages
    }
    bind .dv <KeyPress-Up> {
        .dv.h.h yview scroll -2 units
    }
    
    # Support the MouseWheel
    
     bind .dv <Button-4> {
        .dv.h.h yview scroll -5 units
     }
     bind .dv <Button-5> {
        .dv.h.h yview scroll +5 units
     }    
    
    bind .dv <MouseWheel> {
      if { %D < 0} {
          .dv.h.h yview scroll +5 units
         } else {
          .dv.h.h yview scroll -5 units
         }
    }
  

# dgroths popup
menu .dv.popup -tearoff 0
.dv.popup add command -label Refresh -underline 0 -command Refresh
.dv.popup add separator 
.dv.popup add command -label Home -underline 1 -command \
                                      {LoadFile [lindex $PrevFiles 0]}
.dv.popup add command -label Back -underline 1 -command \
                                      {LoadFile [lindex $PrevFiles end]}
.dv.popup add command -label Forward -underline 1 -command \
          {LoadFile [lindex $NextFiles 0]}


bind .dv <Control-1> {
    if { [winfo exists .dv.popup] } {
        set x [winfo pointerx .]
        
        set y [winfo pointery .]
        
        tk_popup .dv.popup $x $y 
    }
}

}
proc Load {} {
  set filetypes {
    {{Html Files} {.html .htm}}
    {{All Files} *}
  }
  global lastDir htmltext
  set f [tk_getOpenFile -initialdir $lastDir -filetypes $filetypes]
  if {$f!=""} {
    LoadFile $f
    set lastDir [file dirname $f]
  }
}
# Clear the screen.
#
# Clear the screen.
#
proc Clear {} {
  global Images OldImages hotkey
  if {[winfo exists .dv.fs.h]} {set w .dv.fs.h} else  {set w .dv.h.h}
  $w clear
  catch {unset hotkey}
  ClearBigImages
  ClearOldImages
  foreach fn [array names Images] {
    set OldImages($fn) $Images($fn)
  }
  catch {unset Images}
}
proc ClearOldImages {} {
  global OldImages
  foreach fn [array names OldImages] {
    image delete $OldImages($fn)
  }
  catch {unset OldImages}
}
proc ClearBigImages {} {
  global BigImages
  foreach b [array names BigImages] {
    image delete $BigImages($b)
  }
  catch {unset BigImages}
}

# The following proc is the actual entry point into the system
proc showPgDoc {file } {
    initSystem
    buildHtmlViewer
    LoadFile $file
}