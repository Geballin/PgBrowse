#!/bin/sh 
# \
exec wish "$0" "$@"

#!/usr/bin/wish
#
# Filename: PgBrowse.tcl
# Version:  1.8
# Released: Oct 27, 2004
# 
# Sorta Authored by: Jerry LeVan  http://homepage.mac.com/levanj
# Email: jerry.levan@eku.edu
#
# Location: http://homepage.mac.com/TclTk
#
# This program is an enhanced version of the tcl client
# found in the books "PostgreSQL" by Douglas and Douglas.
#
# It also contains features from my BiggerSql Cocoa based
# browser.
#
# This program will allow the user to browse and interact
# with PostgreSQL databases.
# Requirements:
#   TkTable (any recent version)
#   PostgreSQL
#   Tcl/Tk     
#
# We will keep important globals in ui_vars
# ui_vars(cmdStatus) = .top.cmdStatus.t , where the status and notices show
# ui_vars(code)      = .top.code.t , where the sql code is entered
# ui_vars(table)     = .top.resFrame.table , where the selections are displayed

set VERSION 1.8

proc main { } {

  global ui_vars
  global connect_parms
  global psql
  global windows
  global macosx
  global linux
  global tcl_platform
  
  wm withdraw .

  set psql [findPsql]
  
  set results [connect]
   
  if { $results != {} } {
    
    set ui_vars(conn)  [lindex $results 0]
    set conn $ui_vars(conn)
   
    set dsn [lindex $results 1]
    set items [split $dsn " "]
    foreach item $items {
        if {[string equal $item "" ] } continue
        set itemlist [split $item '=']
        set connect_parms([lindex $itemlist 0]) [lindex $itemlist 1]
     }
     # parray connect_parms

    # set some global bindings for...
    # event add <<Copy>> <Control-Key-c>
    # event add <<Paste>> <Control-Key-v>

    # do some extra if running under macosx
    set macosx 0
    if { $tcl_platform(os) eq "Darwin" && [ tk windowingsystem ] eq "aqua" } {
      set macosx 1
    }
    
    set windows 0
    if {$tcl_platform(platform) eq "windows" } {
        set windows 1
    }
    
    set linux 0
    if { [tk windowingsystem ] eq "x11"} {
      set linux 1
    }
    # build the user interface
    
    build_ui $conn
           
   # register a handler to get messages from the back end 
    pg_notice_handler $conn "insertMessage "

   # create application menus
    build_menus  $conn
  
  #check for the scripts library directory and try to create...
  if { ![file exists "~/SQLScripts" ] } {
    file mkdir "~/SQLScripts"
    $ui_vars(cmdStatus) insert end "\nCreated ~/SQLScripts directory."
   } elseif { [file isfile "~/SQLScripts"] } {
    $ui_vars(cmdStatus) insert end "~/SQLScripts is an ordinary file not a \
   directory. The Scripts Library Directory cannot be created."   }  
    
    if { $psql != ""} {
      $ui_vars(cmdStatus) insert end "\nPsql found at $psql."
    } else {
      $ui_vars(cmdStatus) insert end "\nPsql not found."
    }
    
    Init_History
    
    $ui_vars(cmdStatus) insert end "\nReady...\n"
    
    wm deiconify .
    
    tkwait window .
 
    pg_disconnect $conn
  }
}

proc sendSelectionToPsql {} {
     global ui_vars
     
     $ui_vars(cmdStatus) delete "1.0" end
     set startTime [clock clicks -milliseconds]
     if { [$ui_vars(code) tag ranges sel ] != "" } {
        set command [$ui_vars(code) get sel.first sel.last ]
        sendToPsql $command
      }
     set finishTime [clock clicks -milliseconds]
     set lapsedTime [expr {abs($finishTime - $startTime)}]
     $ui_vars(cmdStatus) insert end "\nPsql done in $lapsedTime milliseconds\n"
     $ui_vars(cmdStatus) see end
}

proc findPsql {} {
  if { [file exists /usr/bin/psql]} {return /usr/bin/psql}
  if { [file exists /usr/local/bin/psql]} {return /usr/local/bin/psql}
  if { [file exists /usr/local/pgsql/bin/psql]} {return /usr/local/pgsql/bin/psql}
   
  return ""
}

proc sendToPsql { cmd } {
  global ui_vars
  global connect_parms
  global psql
  
  # build the connect string
  foreach key { user dbname host port } {
    set key ""
  }
  foreach {key value} [array get connect_parms] {
    if { $key== "user"}    { set user $value }
    if { $key == "dbname"} { set dbname $value }
    if { $key == "host"}   { set host $value }
    if { $key == "port" }  { set port $value }
  }
   
  #set results [exec $psql -U $user -d $dbname -h $host -p $port -c $cmd]
  if {[catch { exec $psql -U $user -d $dbname -h $host -p $port -c $cmd } results]} {
    $ui_vars(cmdStatus) insert end [append results "\n"] red
  } else {
  $ui_vars(code) insert end $results
  $ui_vars(code) see end
  }
 }
    
    
proc insertMessage {mesg} {
  global ui_vars
  $ui_vars(cmdStatus) insert end $mesg magenta
}

proc BuildScriptMenu { amenu adir } {
   set old_dir [pwd]
   cd $adir
   set file_list [lsort -dictionary [glob -nocomplain *]]
   #puts $file_list
   foreach item $file_list {
      if { [file isdirectory $item ]} {
          $amenu add cascade -label $item -menu [menu $amenu.[string tolower $item]]
          BuildScriptMenu $amenu.[string tolower $item] $adir/$item/
          continue
      }
      if { [string  compare [string tolower [file extension $item]] ".sql" ]} { continue }
      #puts $item
      $amenu add command -label $item -command "loadSQL \"$adir$item\""
   }
   cd $old_dir
}

proc loadSQL { fileName } {
  global ui_vars
  if { $fileName != "" } {
   $ui_vars(code) delete 1.0 end
   set f [open $fileName r]
   set fileContents [ read $f ]
   $ui_vars(code) insert 1.0 $fileContents
   close $f
  }
}

proc build_menus {conn} {
global ui_vars
global tcl_platform
global macosx
global windows
global linux
global psql
global displayNULL
global sendSingle
global longField
global hasImg
global basedir
global hasHtml

set longField 0

# try to be platform independent
if {[string equal [tk windowingsystem] "classic"] 
	|| [string equal [tk windowingsystem] "aqua"]} {
    set modifier Command
} elseif {$tcl_platform(platform) == "windows"} {
    set modifier Control
} else {
    set modifier Control
}
# Create a "menu bar"
menu .menubar
# make it the menu for the application window
.  config -menu .menubar
# create the File menu
 menu .menubar.file -tearoff 0
# add this menu to the menubar
.menubar  add cascade -label "File"  -menu .menubar.file
# add the menu items with actions
.menubar.file add command -label "Load SQL File..." -accelerator $modifier-O -command { openFile}
.menubar.file add command -label "Save SQL Window..." -command saveSqlWindow
.menubar.file add separator
.menubar.file add command -label "Save SQL Results As CSV File..." -accelerator $modifier-S -command { saveFile }
.menubar.file add command -label "Save SQL Results As Formatted File..."  -command { saveFormattedFile }
.menubar.file add separator 
.menubar.file add command -label "Table Editor & Information..." -command "showTableInfo $conn"
.menubar.file add check -label "Display null as <NULL>" -variable displayNULL
.menubar.file add check -label "Send Single Statements" -variable sendSingle
.menubar.file add check -label "Show Long Fields" -variable longField
.menubar.file add separator
.menubar.file add command -label "Run Editor Window" -accelerator $modifier-R \
    -command "getStringAndProcess $conn $ui_vars(table) 0 "
.menubar.file add command -label "Run Selection" \
    -command "getStringAndProcess $conn $ui_vars(table) 1 "
 if { $psql != "" } {
    .menubar.file add command -label "Send Selection To Psql" \
        -command "sendSelectionToPsql"
}
.menubar.file add separator
.menubar.file add command -label "Quit" -accelerator $modifier-Q \
          -command {save_history ; exit }
# create the help menu
 menu .menubar.help -tearoff 0
.menubar add cascade -label "Help" -menu .menubar.help
.menubar.help add command -label "Help" -accelerator $modifier-H -command Help
.menubar.help add command -label "Show Readme" -command Readme
if {$hasHtml } {
.menubar.help add separator
.menubar.help add command -label "Postgresql Documentation" \
    -command [list showPgDoc [file join $basedir Support pgdoc index.html]]
}
#create a "Scripts" menu
# add a scripts menu
 menu .menubar.scripts -tearoff 0
.menubar add cascade -label "Scripts" -menu .menubar.scripts
.menubar.scripts add command -label "Refresh Scripts Menu"  -command RebuildScriptsMenu
if { $macosx && [file isdirectory "~/SQLScripts" ] } {
  .menubar.scripts add command -label "Open Scripts Folder" -command OpenScriptsFolder
}

if { $windows && [file isdirectory "~/SQLScripts" ] } {
  .menubar.scripts add command -label "Open Scripts Folder" -command OpenScriptsFolder
}

if {$linux && [file isdirectory "~/SQLScripts" ] } {
  .menubar.scripts add command -label "Open Scripts Folder" -command OpenScriptsFolder
}  
.menubar.scripts add separator

# Add the menu items
if { [file isdirectory "~/SQLScripts" ]} {
    BuildScriptMenu .menubar.scripts "~/SQLScripts/"
 }

# Some global bindings
bind all  <$modifier-q> {save_history ; exit}
bind all  <$modifier-o> {openFile}
bind all  <$modifier-s> {saveFile}
bind all  <$modifier-h> {Help}

# build the popup menu
 menu $ui_vars(table).menu 
 $ui_vars(table).menu add command -label "View As Text" -command showText
 $ui_vars(table).menu add command -label "View As Bytea Text" -command showByteaText
 $ui_vars(table).menu add command -label "View As Large Object Text" \
        -command showLOBJText
 $ui_vars(table).menu add separator
 
 if { $hasImg } {
 $ui_vars(table).menu add command -label "View As Bytea Image" -command showByteaImage
 $ui_vars(table).menu add command -label "View As Large Object Image" \
       -command showLOBJImage
 $ui_vars(table).menu add separator
 } else { insertMessage \
            "Warning Img package missing. Images cannot be viewed."
 }
 
 $ui_vars(table).menu add command -label "Export Text Field..."\
              -command exportTextField
 $ui_vars(table).menu add command -label "Export Bytea Field..."\
              -command exportByteaField
 $ui_vars(table).menu add command -label "Export Large Object Field..." \
              -command exportLargeObjectField

 bind $ui_vars(table) <Control-Button-1> {
     #tk_popup $table(table).menu  %X %Y 
     #puts "x=%x, y=%y\nX=%X, Y=%Y\n cell: [$table(table) get @%x,%y]\n @%x,%y\n"
      processTable %x %y %X %Y
     }

}

proc OpenScriptsFolder {} {
  global macosx
  global windows
  global linux
  
  if {$macosx} {
    exec open [glob ~/SQLScripts]
  }
  if {$windows} {
    catch { eval exec explorer {[file nativename ~/SQLScripts]} }
  }
  if { $linux } {
    exec xdg-open [glob ~/SQLScripts] &
  }
}
proc RebuildScriptsMenu {} {
  global macosx
  global windows
  global linux
  foreach w [winfo children .menubar.scripts ] { destroy $w }
  .menubar.scripts delete 0 end
  .menubar.scripts add command -label "Refresh Scripts Menu" -command RebuildScriptsMenu
  if {  $macosx || $windows || $linux} {
     if { [file isdirectory "~/SQLScripts" ] } {
        .menubar.scripts add command -label "Open Scripts Folder" -command OpenScriptsFolder
     }
  }
  .menubar.scripts add separator
  # Add the menu items
  if { [file isdirectory "~/SQLScripts" ]} {
    BuildScriptMenu .menubar.scripts "~/SQLScripts/"
   }
  # workaround for menu bug in the Aqua distribution
  if { [tk windowingsystem] eq "aqua" } {
    toplevel .tiny -height 1 -width 1
    update idletasks
    destroy .tiny
    }
}

proc processTable { x y globalx globaly } {
   global ui_vars
   global lastTag
   set lastTag @$x,$y
   $ui_vars(table) activate @$x,$y
   tk_popup $ui_vars(table).menu  $globalx $globaly
}

proc exportTextField {} {
    global ui_vars
    global lastResult
    global lastTag
    
    set theRow [$ui_vars(table) index $lastTag row]
    set theCol [$ui_vars(table) index $lastTag col]
   
    set rowValues [pg_result $lastResult -getTuple $theRow]
    set val [lindex $rowValues $theCol]
    
    set theDir [tk_getSaveFile ]
    
    if { $theDir != "" } {
      if { [catch {
        set fd [open $theDir w]
        puts $fd $val
        close $fd } result]
      } {
        tk_messageBox -message "Write failed : $result" -type ok
      } else {
        tk_messageBox -message "File $theDir OK" -type ok
      }
    } 
}

proc exportByteaField {} {
    global ui_vars
    global lastResult
    global lastTag
    
    set theRow [$ui_vars(table) index $lastTag row]
    set theCol [$ui_vars(table) index $lastTag col]
   
    set rowValues [pg_result $lastResult -getTuple $theRow]
    #set val [lindex $rowValues $theCol]
    set val [subst -nocommands -novariables [lindex $rowValues $theCol]]
    
    set theDir [tk_getSaveFile ]

    if { $theDir != "" } {
      if { [catch {
        set fd [open $theDir w]
        fconfigure $fd -translation binary
        puts -nonewline $fd $val
        close $fd } result ]
      } {
        tk_messageBox -message "Write failed : $result" -type ok
      } else {
        tk_messageBox -message "File $theDir OK" -type ok
      }
        
    }
  
}

proc exportLargeObjectField {} {
    global ui_vars
    global lastResult
    global lastTag
    
    set theRow [$ui_vars(table) index $lastTag row]
    set theCol [$ui_vars(table) index $lastTag col]
    set theStr ""
    set rowValues [pg_result $lastResult -getTuple $theRow]
    set val [lindex $rowValues $theCol]
    # here we have the large object oid...
    set res [pg_exec $ui_vars(conn) "begin"]
    pg_result $res -clear
    set lfd [pg_lo_open $ui_vars(conn) $val r]
    set size [pg_lo_lseek $ui_vars(conn) $lfd 0 SEEK_END]
    set tmp  [pg_lo_lseek $ui_vars(conn) $lfd 0 SEEK_SET]
    pg_lo_read $ui_vars(conn) $lfd theStr $size
    set res [pg_lo_close $ui_vars(conn) $lfd]
    set res [pg_exec $ui_vars(conn) "end"]
    pg_result $res -clear

    set theDir [tk_getSaveFile ]

    if { $theDir != "" } {
      if { [catch {
      set fd [open $theDir w]
      fconfigure $fd -translation binary
      puts -nonewline $fd $theStr
      close $fd } result]
      } {
        tk_messageBox -message "Write failed : $result" -type ok
      } else {
        tk_messageBox -message "File $theDir OK" -type ok
      }

    } 
 
}

proc showText {} {
    global ui_vars
    global lastResult
    global lastTag
    
    set theRow [$ui_vars(table) index $lastTag row]
    set theCol [$ui_vars(table) index $lastTag col]
   
    set rowValues [pg_result $lastResult -getTuple $theRow]
    set val [lindex $rowValues $theCol]
    #set val [$ui_vars(table) get active]
    showAsText $val   
    
}

proc showByteaText {} {
    global ui_vars
    global lastResult
    global lastTag
    
    set theRow [$ui_vars(table) index $lastTag row]
    set theCol [$ui_vars(table) index $lastTag col]

    set rowValues [pg_result $lastResult -getTuple $theRow]
    #puts [lindex $rowValues $theCol]
    #set val [PQunescapeBytea [lindex $rowValues $theCol] ] 
    set val [subst -nocommands -novariables [lindex $rowValues $theCol]]
 
    showAsText $val   
}

proc showLOBJText {} {
    global ui_vars
    global lastResult
    global lastTag
    
    set theRow [$ui_vars(table) index $lastTag row]
    set theCol [$ui_vars(table) index $lastTag col]
    set theStr ""
    set rowValues [pg_result $lastResult -getTuple $theRow]
    set val [lindex $rowValues $theCol]
    # here we have the large object oid...
    set res [pg_exec $ui_vars(conn) "begin"]
    pg_result $res -clear
    set lfd [pg_lo_open $ui_vars(conn) $val r]
    set size [pg_lo_lseek $ui_vars(conn) $lfd 0 SEEK_END]
    set tmp  [pg_lo_lseek $ui_vars(conn) $lfd 0 SEEK_SET]
    pg_lo_read $ui_vars(conn) $lfd theStr $size
    set res [pg_lo_close $ui_vars(conn) $lfd]
    set res [pg_exec $ui_vars(conn) "end"]
    pg_result $res -clear
    showAsText $theStr
    
    
}

proc showByteaImage {} {
    global ui_vars
    global lastResult
    global lastTag
    
    set theRow [$ui_vars(table) index $lastTag row]
    set theCol [$ui_vars(table) index $lastTag col]

    set rowValues [pg_result $lastResult -getTuple $theRow]
    #puts [lindex $rowValues $theCol]
    #set val [PQunescapeBytea [lindex $rowValues $theCol] ] 
    set val [subst -nocommands -novariables [lindex $rowValues $theCol]]
    showAsImage $val   
}

proc showLOBJImage {} {
    global ui_vars
    global lastResult
    global lastTag
    
    set theRow [$ui_vars(table) index $lastTag row]
    set theCol [$ui_vars(table) index $lastTag col]
    set theStr ""
    set rowValues [pg_result $lastResult -getTuple $theRow]
    set val [lindex $rowValues $theCol]
    # here we have the large object oid...
    set res [pg_exec $ui_vars(conn) "begin"]
    pg_result $res -clear
    set lfd [pg_lo_open $ui_vars(conn) $val r]
    set size [pg_lo_lseek $ui_vars(conn) $lfd 0 SEEK_END]
    set tmp  [pg_lo_lseek $ui_vars(conn) $lfd 0 SEEK_SET]
    pg_lo_read $ui_vars(conn) $lfd theStr $size
    set res [pg_lo_close $ui_vars(conn) $lfd]
    set res [pg_exec $ui_vars(conn) "end"]
    pg_result $res -clear
    showAsImage $theStr
    
    
}

proc openFile {} {
  global ui_vars
  set fileName [tk_getOpenFile]
  if { $fileName != "" } {
   $ui_vars(code) delete 1.0 end
   set f [open $fileName r]
   set fileContents [ read $f ]
   $ui_vars(code) insert 1.0 $fileContents
   close $f
  }
}

proc saveFile {} {
   global lastResult
   set sep "|"
   set fname [tk_getSaveFile]
   if {$fname !=""} {
   set f [open $fname "w"]
   set col_cnt   [pg_result $lastResult -numAttrs]
   set col_names [pg_result $lastResult -attributes]
   #write the column names
   set line ""
   for {set i 0} {$i < $col_cnt } { incr i} {
     append line [lindex $col_names $i] $sep
   }
   set line [string range $line 0 end-1]
   # write the header line
   puts $f $line
   # write the rest of the result set
   set row_cnt [pg_result $lastResult -numTuples ]
   for { set row 0} { $row < $row_cnt } { incr row } {
    set tuple [pg_result $lastResult -getTuple $row]
    set line ""
    for { set i 0} {$i <$col_cnt} { incr i} {
      append line [lindex $tuple $i] $sep
    }
    set line [string range $line 0 end-1]
    puts $f $line
   }
   close $f
   tk_messageBox -title PgBrowse \
                    -message "Save File Completed"  \
                    -type  ok

  }
}

proc saveSqlWindow {} {
 global ui_vars
 set fname [tk_getSaveFile -initialdir "~/SQLScripts" \
            -defaultextension ".sql"]
 if { $fname != "" } {
     set f [open $fname "w"]
     set content [$ui_vars(code) get 1.0 end ]
     puts $f $content
     close $f
     tk_messageBox -message "Write Completed" -icon info
 }
}

proc saveFormattedFile {} {
  global lastResult 
  global col_widths
  set sep "|"
  set fname [tk_getSaveFile]
  if {$fname != "" } {
	  set f [open $fname "w"]
	  set col_cnt   [pg_result $lastResult -numAttrs]
	  set col_names [pg_result $lastResult -attributes]
          set col_attrs [pg_result $lastResult -lAttributes]         
	  set strheader ""
	  for {set col 0} { $col < $col_cnt } {incr col } {
            set thisColAttr [lindex $col_attrs $col]
            if { [isNumeric [lindex $thisColAttr 1] ] } {
             append strheader " %$col_widths($col)s |"
            } else {
             append strheader " %-$col_widths($col)s |"
            }
	  }
	  set strheader [string range $strheader 0 end-1]
	  set line [eval "format \"$strheader\" $col_names"]
	  puts $f  "$line"
	  set lineLen [string length $line ]
	  set borderline ""
          for { set i 0} {$i < $col_cnt} { incr i} {
            for {set j 0 } { $j < $col_widths($i) } { incr j} {
               append borderline "-"
            }
            append borderline "--+"
          }
          set borderline [string range $borderline 0 end-1 ]
	   puts $f  "$borderline"
	     # write the rest of the result set
	   set row_cnt [pg_result $lastResult -numTuples ]
	   for { set row 0} { $row < $row_cnt } { incr row } {
	    set tuple [pg_result $lastResult -getTuple $row]
	    set line [eval "format \"$strheader\" $tuple"]
	    puts $f  "$line"
           }
    close $f
   tk_messageBox -title PgBrowse \
                   -message "Save File Completed."  \
                   -type  ok

   }
}

proc build_ui { conn } {
  global VERSION
  global tcl_platform
  global ui_vars
  global connect_parms
  
  panedwindow .top -orient vertical -showhandle 1 -bg white
  pack .top -expand yes -fill both

  if { [catch {
  wm title . \
  "PgBrowse Postgresql Client ($VERSION) - \
   user: $connect_parms(user) host: $connect_parms(host) dbname: $connect_parms(dbname)"
  } result ] } {
    wm title . "PgBrowse PostgreSQL Client ($VERION)"
  }
  

if {[string equal [tk windowingsystem] "classic"] 
	|| [string equal [tk windowingsystem] "aqua"]} {
    set modifier Command
} elseif {$tcl_platform(platform) == "windows"} {
    set modifier Control
} else {
    set modifier Control
}
#####
# Create 2 labelframe widgets, each containing a
# gridded text and scrollbar assembly.
#-font system 
foreach {w label} {code "[SQL]" cmdStatus  "[Status]"} {
	set f [labelframe .top.$w -text $label -fg blue -bg white]
	text $f.t -height 15 -width 80 \
		-wrap none \
		-relief groove \
		-borderwidth 3 \
		-xscrollcommand [list $f.xbar set] \
		-yscrollcommand [list $f.ybar set]
	scrollbar $f.xbar -orient horizontal \
		-command [list $f.t xview]
	scrollbar $f.ybar -orient vertical \
		-command [list $f.t yview]

	grid $f.t -row 0 -column 0 -sticky news -padx 2 -pady 2
	grid $f.ybar -row 0 -column 1 -sticky ns -padx 2 -pady 2
	grid $f.xbar -row 1 -column 0 -sticky ew -padx 2 -pady 2
	grid columnconfigure $f 0 -weight 1
	grid rowconfigure $f 0 -weight 1

	# Add the frame assembly to the panedwindow

	.top add $f -minsize 1i -padx 4 -pady 6
	set ui_vars($w) $f.t
 }
  # cut down on the size of the status window
  $ui_vars(cmdStatus) configure -height 5
  $ui_vars(cmdStatus) configure -bg lightgray
  $ui_vars(code) configure -bg white
  if { $tcl_platform(platform) == "unix" && $tcl_platform(os) != "Darwin"} {
     $ui_vars(code) configure -font {fixed}
     $ui_vars(cmdStatus) configure -font {fixed}
  }
  # build and configure the table to show the selection results
  set f [labelframe .top.resFrame -text {[Selection Results]} -fg blue -bg white]
  set table [make_table $f]
  
  scrollbar $f.sx -orient horizontal -command [list $table xview]
  scrollbar $f.sy -command " $table yview"
  grid $table -row 0 -column 0 -sticky news -padx 2 -pady 2
  grid $f.sx  -row 1 -column 0 -sticky ew -padx 2 -pady 2
  grid $f.sy  -row 0 -column 1 -sticky ns -padx 2 -pady 2
 
  grid $f -row 0 -column 0 -sticky news -padx 2 -pady 2
  grid columnconfigure $f 0 -weight 1
  grid rowconfigure $f 0 -weight 1
  .top add $f -minsize 1i -padx 4 -pady 6
  
  set ui_vars(table) $table
  
  # set up some important bindings...
  
  # Scrolling in the Displayed table
  bind $ui_vars(table) <KeyPress-space> {
    $ui_vars(table) yview scroll +1 pages
  }
  
  bind $ui_vars(table) <Shift-space> {
    $ui_vars(table) yview scroll -1 pages
  }
  
  #Support the MouseWheel

    bind $ui_vars(table) <Button-4> { $ui_vars(table) yview scroll -5 units }
    bind $ui_vars(table) <Button-5> { $ui_vars(table) yview scroll +5 units }
    bind $ui_vars(code)  <Button-4> { $ui_vars(code)  yview scroll -5 units }
    bind $ui_vars(code)  <Button-5> { $ui_vars(code)  yview scroll +5 units }
  
  
    bind $ui_vars(table) <MouseWheel> {
      if { %D < 0} {
          $ui_vars(table) yview scroll +5 units
         } else {
          $ui_vars(table) yview scroll -5 units
         }
    }
  
  
  # Process the whole sql window contents
  bind $ui_vars(code) <$modifier-r> \
      "getStringAndProcess $conn $table 0 ; break"
      
 # Process the selection or the line containing the insertion point
  bind $ui_vars(code) <Shift_L><Return> \
      "getStringAndProcess $conn $table 1 ; break"

# set up copy
   bind $ui_vars(code) <$modifier-c> "tk_textCopy $ui_vars(code) ; break"
 
 # Set up paste
  bind $ui_vars(code) <$modifier-v> "tk_textPaste $ui_vars(code) ; break"
  
 #Set up the history retrieval bindings
  bind $ui_vars(code) <$modifier-Up> "next_history ; break"
  bind $ui_vars(code) <$modifier-Down> "prev_history ; break"
 
 # Set up the colors for printing status messages
  $ui_vars(cmdStatus) tag configure red -foreground red
  $ui_vars(cmdStatus) tag configure blue -foreground blue
  $ui_vars(cmdStatus)  tag configure magenta -foreground magenta
  
 # Set up mouse wheel for the code window
  
  focus -force $ui_vars(code)
 	
}
#    -font system 

proc make_table { parent } {
  table $parent.table \
    -variable table_data \
    -yscrollcommand "$parent.sy set" \
    -xscrollcommand "$parent.sx set" \
    -selecttype row \
    -titlerows 1 \
    -titlecols 1 \
    -roworigin -1 \
    -colorigin -1 \
    -colstretchmode last \
    -padx 4 \
    -coltagcommand colproc \
    -rowtagcommand rowproc
    
   $parent.table tag config anchorcenter -anchor c
   $parent.table tag config anchorwest -anchor w
   $parent.table tag config anchoreast -anchor e
   $parent.table tag config rowColor -bg "lightcyan1"
   $parent.table tag config title -bg lightblue
   $parent.table tag config title -fg black 
   
   $parent.table tag col anchoreast -1
   $parent.table tag row anchorcenter -1
   $parent.table config -bg white
   
  return $parent.table  
  
} 

proc colproc col { if { $col >= 0 } { return "anchorwest" } }
proc rowproc row { if { $row >= 0 && $row%2 } { return "rowColor" } }

# a very simple parser, we assume a semicolon is
# a statement separator if it is preceeded by an
# even number of single quotes

proc parse {workingStr} {
  set theLength [string length $workingStr]
  set inQuote 0
  set start 0
  set theList {}
  
  for { set i 0 } { $i < $theLength } { incr i } {
   set nextch [string index $workingStr  $i]
   if { $nextch  == ";" && !$inQuote } {
      lappend theList [string range $workingStr $start [expr {$i -1}]]
      set start [ expr  {$i + 1}]
   }
   if { $nextch == "\'" } {
     set inQuote [expr {$inQuote?0:1 }]
     }
  }
  lappend theList [string range $workingStr $start [expr {$i -1}]]
  return $theList
}

proc getStringAndProcess { conn table flag } {
  global ui_vars
  global sendSingle
  
  if { $flag } {
   if { [$ui_vars(code) tag ranges sel ] != "" } {
    set commands [$ui_vars(code) get sel.first sel.last ]
   } else {
    set commands [$ui_vars(code) get "insert linestart" "insert lineend"]
   }
  } else {
    set commands [$ui_vars(code) get 1.0 end ]
  }
   $ui_vars(cmdStatus) delete 1.0 end
#   set commandList [split $commands ";"]
    set startTime [clock clicks -milliseconds]
    if { $sendSingle } {
       set commandList [parse $commands]
       foreach command $commandList {
         if { $command != "" } { process_command $conn $table $command }
       }   
    } else { process_command $conn $table $commands }
    set finishTime [clock clicks -milliseconds ]
    set lapsedTime [expr {abs( $finishTime - $startTime) }]
    $ui_vars(cmdStatus) insert end "Done in $lapsedTime milliseconds.\n"
}

proc saveSelection {res} {
    global lastResult
    catch {pg_result lastResult -clear}
    set lastResult $res
}

proc process_command { conn table command } { 
  
  global ui_vars
  
  add_history $command
  
  insertMessage "Working...\n"
  update idletasks
  
  if { [string index $command 0] == "\\" } {
     sendToPsql $command
     return
   }
   
  $ui_vars(code) config -cursor watch
  update idletasks
  set result_set [pg_exec $conn $command]
  $ui_vars(code) config -cursor xterm
  switch [pg_result $result_set -status] {

    "PGRES_EMPTY_QUERY" {
      $ui_vars(cmdStatus) insert end "Empty query...Ok\n"
    }

    "PGRES_TUPLES_OK" { 

       set col_cnt   [pg_result $result_set -numAttrs]
       set row_cnt   [pg_result $result_set -numTuples]
       $ui_vars(cmdStatus) insert end "$row_cnt rows, $col_cnt columns.\n" blue
       #$ui_vars(cmdStatus) insert end "Done.\n"
       load_table $table $result_set 
       saveSelection $result_set
       return
    }

    "PGRES_COMMAND_OK" { 
      # -cmdStatus not implemented yet in Pgtcl 1.5 set a trap
      
      catch {
      set str1 [ pg_result $result_set -cmdStatus]
      if { [string length $str1] > 0 } {
         $ui_vars(cmdStatus) insert end "$str1\n" blue
       }
      }
      
      set str2 [pg_result $result_set -cmdTuples ]
      if { [string length $str2] > 0 } {  
      $ui_vars(cmdStatus) insert end "$str2 rows affected\n" blue
      }
      #$ui_vars(cmdStatus) insert end "Done.\n" 
    }

    default
    {
      $ui_vars(cmdStatus) insert end [pg_result $result_set -status] red
      $ui_vars(cmdStatus) insert end "\n"
      $ui_vars(cmdStatus) insert end [pg_result $result_set -error]  red
      $ui_vars(cmdStatus) insert end "\n"

    }
  }
      pg_result $result_set -clear
}

proc load_table { table result_set } {

  size_table $table $result_set

  set_column_headers $table $result_set

  fill_table $table $result_set
    
  size_columns $table $result_set
}

proc size_table { table result_set } {

  set col_cnt   [pg_result $result_set -numAttrs]
  set row_cnt   [pg_result $result_set -numTuples]

  $table configure \
    -rows [expr {$row_cnt + 1 }] \
    -cols [expr {$col_cnt + 1 }] 
}

proc isNumeric { aType } {
  if { [lsearch { 20 21 23 26 700 701 190 1700 } $aType] == -1} {
    return 0
   } else {
    return 1
    }
}

proc set_column_headers { table result_set } {
  
  global col_widths

  set col_cnt   [pg_result $result_set -numAttrs]
  set col_names [pg_result $result_set -attributes]
  set col_attrs [pg_result $result_set -lAttributes]

  for {set col 0} {$col < $col_cnt} {incr col} {
    set col_name [lindex $col_names $col]
    $table set -1,$col $col_name
    set col_widths($col) [string length $col_name]
    set thisColAttr [lindex $col_attrs $col]
    if { [isNumeric [lindex $thisColAttr 1] ] } {
       $table tag col anchoreast $col
    } else { $table tag col anchorwest $col }
  }
}

proc fill_table { table result_set } {

  global col_widths
  global displayNULL
  global longField

  set col_cnt   [pg_result $result_set -numAttrs]
  set row_cnt   [pg_result $result_set -numTuples]

  for {set row 0} {$row < $row_cnt} {incr row} {
    set tuple [pg_result $result_set -getTuple $row]
    set nullCols [pg_result $result_set -getNull $row]

    $table set $row,-1 [expr {$row + 1}]

    for {set col 0} {$col < $col_cnt} {incr col} {
    
     if { [lindex $nullCols $col] } {
        if {$displayNULL} {
                set val "<NULL>"
        } else { set val "" }
      }  else {
      if  { $longField} {
           set val [lindex $tuple $col]
           } else {
              set val [lindex $tuple $col]
              set strlen [string length $val]
              if { $strlen > 200 } {
                set val "LoNgFiElD:$strlen"}
            }
      }

      if { $col_widths($col) < [string length $val] } {
        set col_widths($col) [string length $val]
      }
      $table set $row,$col $val
    }
  }
}

proc size_columns { table result_set } {

  global col_widths

  set col_cnt   [pg_result $result_set -numAttrs]

  for {set col 0} {$col < $col_cnt} {incr col} {
    $table width $col $col_widths($col)
  }

  $table width -1 5

}

#
#  Mainline code follows
# 
package require Tktable

set basedir [file dirname [info script]]

# try to load the "fast" package first, fallback to pure tcl

if { [catch { package require Pgtcl 1.5 } ] } {
   bell
   source [file join $basedir Support pgin.tcl]
}

if { [catch { package require Img } result] } {
  set hasImg 0
} else { set hasImg 1 }

if { [catch { package require Tkhtml } result] } {
  set hasHtml 0
} else { set hasHtml 1 }


source [file join $basedir Support pgconnect.tcl]
source [file join $basedir Support Help.tcl]
source [file join $basedir Support readme.tcl]
source [file join $basedir Support tableInfo.tcl]
source [file join $basedir Support textWindow.tcl]
#source [file join $basedir Support OptPQunescapeBytea.tcl]
source [file join $basedir Support imageSupport.tcl]
source [file join $basedir Support history.tcl]
source [file join $basedir Support tableView.tcl]
if { $hasHtml == 1} {
  source [file join $basedir Support docViewer.tcl]
}
main
exit
