#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
#exec wish "$0" ${1+"$@"}


proc make_table1 { parent } {
    global table_data1
    table $parent.table \
    -variable table_data1 \
    -yscrollcommand "$parent.sy set" \
    -xscrollcommand "$parent.sx set" \
    -selecttype row \
    -autoclear  1 \
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
   ttk::scrollbar $parent.sx -orient horizontal -command [list $parent.table xview]
   ttk::scrollbar $parent.sy -command " $parent.table yview"
   
   
  return $parent.table  
  
}

proc colproc col { if { $col >= 0 } { return "anchorwest" } }
proc rowproc row { if { $row >= 0 && $row%2 } { return "rowColor" } }

proc buildUI {} {
    global table_data1
    global theTable
    global dbTable
    
    toplevel .viewer
    wm title .viewer "$dbTable Editor"
    ttk::frame .viewer.tabframe

   
    set theTable [ make_table1 .viewer.tabframe]
 
       
    #bind $theTable <Control-Tab> { event generate $theTable <KeyPress-Left> ; break }
    #bind $theTable <Tab> { event generate $theTable <KeyPress-Right> ;break }
    bind $theTable <Tab> {  ::tk::table::MoveCell %W  0 1 ; break}
    bind $theTable <Control-Tab> { ::tk::table::MoveCell %W  0 -1 ; break}
  #Support the MouseWheel
    bind $theTable <Button-4> { $theTable yview scroll -5 units }
    bind $theTable <Button-5> { $theTable yview scroll +5 units }
    bind $theTable <Button-4> { $theTable  yview scroll -5 units }
    bind $theTable <Button-5> { $theTable  yview scroll +5 units }
  
  
    bind $theTable <MouseWheel> {
      if { %D < 0} {
          $theTable yview scroll +5 units
         } else {
          $theTable yview scroll -5 units
         }
    }
     
    pack .viewer.tabframe -fill both -expand yes
    
    pack .viewer.tabframe.sx -side bottom -fill x
    pack .viewer.tabframe.sy -side right -fill y
    pack $theTable -side top -fill both -expand yes
   
    ttk::frame .viewer.buttonFrame
    ttk::button .viewer.buttonFrame.goback -text " < " -command "goback"
    pack .viewer.buttonFrame.goback -side left 
    ttk::button .viewer.buttonFrame.gofwd -text " > " -command "gofwd"
    pack .viewer.buttonFrame.gofwd -side left
    ttk::entry .viewer.buttonFrame.rowcnt -textvariable stepSize -justify right
    pack .viewer.buttonFrame.rowcnt -side left
    
    ttk::menubutton .viewer.buttonFrame.mb \
      -text Move -menu .viewer.buttonFrame.mb.menu
    pack .viewer.buttonFrame.mb -side left
    set m [menu .viewer.buttonFrame.mb.menu -tearoff 0]
    $m add command -label "Move cursor absolute" -command "moveCursor absolute"
    $m add command -label "Move cursor relative" -command "moveCursor relative"
    ttk::entry .viewer.buttonFrame.pos -textvariable moveSize -justify right
    pack .viewer.buttonFrame.pos -side left
    
    ttk::button .viewer.buttonFrame.cancel -text "Close" -command "cancelCmd"
    pack .viewer.buttonFrame.cancel -side right 
    ttk::button .viewer.buttonFrame.insert -text "Insert" -command "insertRecord"
    pack .viewer.buttonFrame.insert -side right 
    ttk::button .viewer.buttonFrame.del -text "Delete" -command "delete_rec"
    pack .viewer.buttonFrame.del -side right
    ttk::button .viewer.buttonFrame.updt -text "Update" -command "update_rec"
    pack .viewer.buttonFrame.updt -side right    
    
    pack .viewer.buttonFrame -expand no -fill x
    
    ttk::frame .viewer.filterFrame 
    ttk::label .viewer.filterFrame.filterLabel -text "Filter by:"
    entry .viewer.filterFrame.filter -textvariable filterText -width 45
    ttk::button .viewer.filterFrame.button -text "Use Filter" -command "filterTable"
    pack .viewer.filterFrame.filterLabel -side left
    pack .viewer.filterFrame.filter -side left
    pack .viewer.filterFrame.button -side left
    pack .viewer.filterFrame -expand no -fill x -padx 5 -pady 5
} 

proc update_rec {} {
    global table_data1
    global viewConn
    global dbTable
    global theTable
    global colNames
    global colTypes

    set theRow [expr {[$theTable cget -rows] -2 }]
    set colCnt [expr {[$theTable cget -cols] -2 }]
    set theData {}
    set dataOk 0
    
    set indexes [$theTable curselection]
    #puts "$indexes"
    if { [llength $indexes] == 0 } {
        tk_messageBox \
          -parent $theTable -message "No row is selected for UPDATE." -type ok -icon info
        return
    }
    # the user might have only the last row selected by mistake
    set selRow [lindex [split [lindex $indexes 0] ","] 0]
    if {$selRow == $theRow } {
        tk_messageBox \
        -parent $theTable -message "Please Select a row in the table." -type ok -icon info
        return
    }
    # Since we are potentially dealing with large objects
    # we will start a transaction.
    
    set res [pg_exec $viewConn "begin" ]
    pg_result $res -clear
   
    for {set i 0 } {$i <= $colCnt } { incr i} {
        if {[string trim $table_data1($theRow,$i)] != "*" } { set dataOk 1 }
        if { [string trim $table_data1($theRow,$i)] == "NULL" } {
          lappend theData NULL
        } elseif { [string trim $table_data1($theRow,$i)] == "DEFAULT" } {
          lappend theData DEFAULT
        } elseif { [string trim $table_data1($theRow,$i)] == "BYTEA" } {
          if { [catch { lappend theData [getByteaString $colNames($i)]} ] } { rollback ; return }
        } elseif { [string trim $table_data1($theRow,$i)] == "LOBJ"} {
          if { [catch { lappend theData [getLOBJ $colNames($i)]} ] }  {
             rollback
             return
          }
        } else {
          lappend theData [pg_quote $table_data1($theRow,$i)]
        }
    }
    # if the update is all stars balk, they probably accidently hit update...
    if {$dataOk == 0} {
       set ans [tk_messageBox -parent $theTable -message \
        "Do you want to UPDATE with all *'s? "\
         -default "no" -type yesno -icon question]
       if { $ans == "no" } { rollback ; return }
    }

    #get the data in the record to update
    set colInfo {}
    foreach item $indexes {
        if { [string trim $table_data1($item)] == "NULL" } {
             lappend colInfo NULL
        } else {            
        lappend colInfo [pg_quote $table_data1($item)]
        #if {$colTypes([lindex [split $item ","] 1]) == "bytea"} {
        #lappend colInfo [pg_quote  $table_data1($item)]
        #} else { lappend colInfo [pg_quote $table_data1($item)] }
        }
    }
    
    # Start building the command (within a transaction)
    set theCmd "update $dbTable set "
    
    #build the list of desired new values
    set setList {}
    set setCnd {}
    for {set i 0 } {$i <= $colCnt } {incr i} {
      if { [lindex $colInfo $i] == "NULL" } {
        set opr "is" } else { set opr "=" }
                        
      if {$i == $colCnt} {
        set setCnd "$setCnd \"$colNames($i)\" $opr [lindex $colInfo $i]"
        set setList "$setList \"$colNames($i)\" = [lindex $theData $i] "
      } else { 
       set setCnd "$setCnd \"$colNames($i)\" $opr [lindex $colInfo $i] and "
       set setList "$setList \"$colNames($i)\" = [lindex $theData $i], "
      }
      
    }
    set theCmd "$theCmd $setList where $setCnd"
    #puts "$theCmd"
    set result [pg_exec $viewConn $theCmd]
    set cmdStatus [pg_result $result -status]
    set ans "no"
    if { $cmdStatus == "PGRES_COMMAND_OK" } {
     set msg "UPDATE Succeeded.\n"
     catch {
      set str1 [ pg_result $result -cmdStatus]
      if { [string length $str1] > 0 } {
        set msg "$msg $str1"
       }
      }
    set ans [tk_messageBox \
        -parent $theTable -message "$msg \n Commit UPDATE?" -type yesno -icon question ]
   } else {
      tk_messageBox \
      -parent $theTable -message "UPDATE Failed.\n [pg_result $result -error]" -type ok -icon error
   }
   
   if { $ans == "yes" } {
      set comres [pg_exec $viewConn "commit"]
   } else {
       set comres [pg_exec $viewConn "rollback"]
   }
   pg_result $comres -clear
   pg_result $result -clear
   
   resetCursor $viewConn $dbTable
}

proc delete_rec {} {
    global theTable
    global dbTable
    global table_data1
    global colNames
    global viewConn
    
    set colCnt [expr {[$theTable cget -cols] -2 }]
    set theRow [expr {[$theTable cget -rows] -2 }]
    
    set indexes [$theTable curselection]
    if { [llength $indexes] == 0 } {
        tk_messageBox \
        -parent $theTable -message "No row is selected for DELETE." -type ok -icon info
        return
    }
    # check to see if the input buffer is selected
    set selRow [lindex [split [lindex $indexes 0] ","] 0]
    if {$selRow == $theRow } {
        tk_messageBox \
        -parent $theTable -message "Please Select a row in the table." -type ok -icon info
        return
    }
    set colInfo {}
    foreach item $indexes {
        if { [string trim $table_data1($item)] == "NULL" } {
             lappend colInfo NULL
        } else {            
        lappend colInfo [pg_quote $table_data1($item)]
        }
    }
    #build the delete command
    set theCmd "begin ; delete from $dbTable where "
    # build the parameter list for the delete command

    for {set i 0 } {$i <= $colCnt } { incr i} {
        
     if { [lindex $colInfo $i] == "NULL" } {
             set opr "is" } else { set opr "=" }
                        
      if {$i == $colCnt} {
        set theCmd "$theCmd \"$colNames($i)\" $opr [lindex $colInfo $i]"
      } else { 
       set theCmd "$theCmd \"$colNames($i)\" $opr [lindex $colInfo $i] and "
      }
    }
   #puts "$theCmd"
   #execute the delete command
   set result [pg_exec $viewConn $theCmd]
   set cmdStatus [pg_result $result -status]
   set ans "no"
   if { $cmdStatus == "PGRES_COMMAND_OK" } {
     set msg "Delete Succeeded.\n"
     catch {
      set str1 [ pg_result $result -cmdStatus]
      if { [string length $str1] > 0 } {
        set msg "$msg $str1"
       }
      }
     set ans [tk_messageBox \
        -parent $theTable -message "$msg\nCommit Delete?" -type yesno -icon question]
   } else {
      tk_messageBox \
       -parent $theTable -message "Delete Failed.\n [pg_result $result -error]" -type ok -icon error
   }
 
   if { $ans == "yes" } {
      set comres [pg_exec $viewConn "commit"]
   } else {
       set comres [pg_exec $viewConn "rollback"]
   }
   
   pg_result $comres -clear
   pg_result $result -clear
   
   resetCursor $viewConn $dbTable
   
}
proc filterTable {} {
    global viewConn
    global dbTable
    global filterText
    global theTable

    set result [pg_exec  $viewConn "select * from $dbTable where $filterText"]
    set cmdStatus [pg_result $result -status]
    if { $cmdStatus != "PGRES_TUPLES_OK" } {
     tk_messageBox \
       -parent $theTable -message "Select Failed.\n [pg_result $result -error]" -type ok -icon error
    } else {
      load_table1 $theTable $result
    }
    pg_result $result -clear

}

proc getByteaString {theCol} {
  set fileName [tk_getOpenFile -title "Select File for Bytea Column '$theCol'"]
  if { $fileName != "" } {
    if { [ catch {
    set f [open $fileName r]
    fconfigure $f -translation binary
    set fileContents [ read $f ]
    close $f } res ] } {
     tk_messageBox \
        -parent .viewer  -message $res -type ok   
    return -code error
    }
    #return [format "%s%s%s" "\'" [pg_escape_bytea $fileContents] "\'" ]
    return '[pg_escape_bytea $fileContents]'
  }
  tk_messageBox \
        -parent .viewer  -message "Action Cancelled by User." -type ok  -icon info 
  return -code error
}

proc getLOBJ { theCol } {
    global viewConn
    set fileName [tk_getOpenFile -title "Select File for Large Object Column '$theCol'" ]
    if {$fileName != "" } {
         if { [ catch {
              set theOid [pg_lo_import $viewConn $fileName] } res ]} {
              tk_messageBox \
                -parent .viewer  -message $res -type ok -icon error 
         return -code error
         }
         return $theOid
    }
   tk_messageBox \
        -parent .viewer  -message "Action Cancelled by User." -type ok -icon info  
   return -code error
 }
 
proc insertRecordOld {} {
    global table_data1
    global viewConn
    global dbTable
    global theTable

    set theRow [expr {[$theTable cget -rows] -2 }]
    set colCnt [expr {[$theTable cget -cols] -2 }]
    set theData {}
    for {set i 0 } {$i <= $colCnt } { incr i} {
        lappend theData $table_data1($theRow,$i)
    }
    # build the sqlstring...
    set paramCnt [expr { $colCnt + 1 } ]
    set insertCmd "insert into $dbTable values ("
   for {set ctr 1 } { $ctr <= $paramCnt } { incr ctr } {
    if { $ctr < $paramCnt } {
     set insertCmd "$insertCmd \$$ctr ,"
    } else {
     set insertCmd "$insertCmd \$$ctr )"
    }
   }
#   puts "[concat pg_exec_params [list $viewConn $insertCmd {} {} {} ] $theData ]"
   set res [eval pg_exec_params [list $viewConn $insertCmd {} {} {} ] $theData ]
   set cmdStatus [pg_result $res -status]
   if { $cmdStatus == "PGRES_COMMAND_OK" } {
     tk_messageBox -message "Insert Succeeded." -icon info
   } else {
      tk_messageBox -message "Insert Failed.\n [pg_result $res -error]" -type ok -icon error
   }
   pg_result $res -clear
}

proc rollback {} {
    global viewConn
    set res [ pg_exec $viewConn "rollback" ]
    pg_result $res -clear
}

proc insertRecord {} {
    global table_data1
    global viewConn
    global dbTable
    global theTable
    global colNames
    global colTypes

    set theRow [expr {[$theTable cget -rows] -2 }]
    set colCnt [expr {[$theTable cget -cols] -2 }]
    set theData {}
    set dataOk 0
    # since we will potentially deal with lobj we
    # need to start a transaction
    
    set res [pg_exec $viewConn "begin" ]
    pg_result $res -clear
    
    for {set i 0 } {$i <= $colCnt } { incr i} {
        if {[string trim $table_data1($theRow,$i)] !="*" } {set dataOk 1}
        if { [string trim $table_data1($theRow,$i)] == "NULL" } {
          lappend theData NULL
        } elseif { [string trim $table_data1($theRow,$i)] == "DEFAULT"} {
          lappend theData DEFAULT
        } elseif { [string trim $table_data1($theRow,$i)] == "BYTEA"} {
          if { [catch { lappend theData [getByteaString $colNames($i)]} ] } { rollback ; return }
        } elseif { [string trim $table_data1($theRow,$i)] == "LOBJ"} {
          if { [catch { lappend theData [getLOBJ $colNames($i)]} ] }  {
             rollback
             return
          }
        } else {
          lappend theData [pg_quote $table_data1($theRow,$i)]
        }
    }
    #Balk at inserting all *'s
    if {$dataOk == 0} {
       set ans [tk_messageBox -parent $theTable -message \
        "Do you want to INSERT all *'s "\
         -default "no" -type yesno -icon question]
       if { $ans == "no" } { rollback ; return }
    }
    
    # build the sqlstring...
   
    set insertCmd "insert into $dbTable values ("
   for {set ctr 0 } { $ctr <= $colCnt } { incr ctr } {
    if { $ctr < $colCnt } {
     set insertCmd "$insertCmd [lindex $theData $ctr] ,"
    } else {
     set insertCmd "$insertCmd [lindex $theData $ctr] )"
    }
   }
   #puts "[concat pg_exec [list $viewConn $insertCmd  ] ]"
   #set res [eval pg_exec [list $viewConn $insertCmd ]]
   set res [pg_exec $viewConn $insertCmd]
   
   set cmdStatus [pg_result $res -status]
   set ans "no"
   
   if { $cmdStatus == "PGRES_COMMAND_OK" } {
    set ans [tk_messageBox \
        -parent $theTable -message "Insert Succeeded.\nCommit Insert?" -type yesno -icon question]
   } else {
      tk_messageBox \
        -parent $theTable -message "Insert Failed.\n [pg_result $res -error]" -type ok -icon error
   }
   
   if { $ans == "yes" } {
      set comres [pg_exec $viewConn "commit"]
   } else {
       set comres [pg_exec $viewConn "rollback"]
   }
   
   pg_result $comres -clear
   pg_result $res -clear
   
   resetCursor $viewConn $dbTable
}

proc moveCursor { mode } {
    global viewConn
    global moveSize
    set res [pg_exec $viewConn "move $mode $moveSize from aCursor"]
    pg_result $res -clear
}

proc goback {} {
    global viewConn
    global dbTable
    global stepSize
    global theTable
    set bckRes [pg_exec $viewConn "Fetch backward $stepSize from aCursor"]
    load_table1 $theTable $bckRes
    pg_result $bckRes -clear
}

proc gofwd {} {
    global viewConn
    global dbTable
    global stepSize
    global theTable
    set fwdRes [pg_exec $viewConn "Fetch forward $stepSize from aCursor"]
    load_table1 $theTable $fwdRes
    pg_result $fwdRes -clear
}

proc cancelCmd {} {
   global viewConn
   destroy .viewer
   pg_exec $viewConn "close aCursor"
}

proc load_table1 { table result_set } {
  global table_data1   
  unset table_data1
  size_table1 $table $result_set

  set_column_headers1 $table $result_set

  fill_table1 $table $result_set
    
  size_columns $table $result_set
}

proc size_table1 { table result_set } {

  set col_cnt   [pg_result $result_set -numAttrs]
  set row_cnt   [pg_result $result_set -numTuples]

  $table configure \
    -rows [expr {$row_cnt + 2 }] \
    -cols [expr {$col_cnt + 1 }] 
}


proc set_column_headers1 { table result_set } {
  
  global col_widths
  global colNames
  global colTypes

  set col_cnt   [pg_result $result_set -numAttrs]
  set col_names [pg_result $result_set -attributes]
  set col_attrs [pg_result $result_set -lxAttributes]
  set conn [pg_result $result_set -conn]

  for {set col 0} {$col < $col_cnt} {incr col} {
    set col_name [lindex $col_names $col]
    
    set colnamelist [lindex $col_attrs $col]
    set colname [lindex $colnamelist 0]
    set coltype [lindex $colnamelist 1]
    set colmod  [lindex $colnamelist 3]
    set colNames($col) $colname
    set typeRes 0
  
    set typeRes [pg_exec $conn "select format_type( $coltype,$colmod)" ]
    #puts [pg_result $typeRes -status]
    set typeName [pg_result $typeRes -list ] 
    #puts "type name = $typeName"
    #puts "$colname $coltype $colmod $typeName"
    pg_result $typeRes -clear
    set col_name "$col_name/$typeName"
    set colTypes($col) $typeName
    $table set -1,$col $col_name
    set col_widths($col) [string length $col_name]
    set thisColAttr [lindex $col_attrs $col]
    if { [isNumeric [lindex $thisColAttr 1] ] } {
       $table tag col anchoreast $col
    } else { $table tag col anchorwest $col }
  }
}

proc fill_table1 { table result_set } {

  global col_widths
  #global displayNULL
  global longField
  set displayNULL 1
  
  set col_cnt   [pg_result $result_set -numAttrs]
  set row_cnt   [pg_result $result_set -numTuples]

  for {set row 0} {$row < $row_cnt} {incr row} {
    set tuple [pg_result $result_set -getTuple $row]
    set nullCols [pg_result $result_set -getNull $row]

    $table set $row,-1 [expr {$row + 1}]

    for {set col 0} {$col < $col_cnt} {incr col} {
     if { [lindex $nullCols $col] } {
        if {$displayNULL} {
                set val "NULL"
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
    for {set col 0} {$col < $col_cnt} { incr col } {
        $table set $row,$col "*"
    }
    
    $table set $row,-1 "Buff:"
  
}


proc set_globals {} {
    global displayNULL
    global longField
    #set longField 0
    set displayNULL 0
}

proc resetCursor { conn table } {
  set res [pg_exec $conn "close aCursor; declare aCursor scroll cursor with hold for \
             select * from $table " ]
  set res1 [pg_result $res -status]
  if { $res1 != "PGRES_COMMAND_OK"}  {
    tk_messageBox -message "Failed to reset cursor." -type ok -icon error
  }
  pg_result  $res -clear
}

proc isView { conn table } {
  set returnVal 0
  # split the table name into schema and name
  set res [split $table "." ]
  set schema [lindex $res 0]
  set name [lindex $res 1]
  set cmd "select table_type from information_schema.tables \
     where table_schema = '$schema' and table_name = '$name' "
  set result [pg_exec $conn $cmd ]
  set theType [pg_result $result -getTuple 0]
  if { $theType == "VIEW" } {set returnVal 1}
  pg_result $result -clear
  return $returnVal

}                        
proc showTheEditWindow { table conn } {
  set_globals
  global theTable
  global dbTable
  global viewConn
  global stepSize
  global moveSize
  global filterText
  
  set viewConn $conn
  set stepSize 1
  set moveSize 0
  set dbTable $table
  
  buildUI
  set filterText ""
  #if the user picked a view we will disable the
  # editing buttons
  if { [isView  $viewConn $dbTable  ] } {
     .viewer.buttonFrame.insert config -state disabled
     .viewer.buttonFrame.del config -state disabled
     .viewer.buttonFrame.updt config -state disabled
  } else {
     .viewer.buttonFrame.insert config -state normal
     .viewer.buttonFrame.del config -state normal
     .viewer.buttonFrame.updt config -state normal
  } 
  # if the window is closed via the window manager
  # we still have to destroy the cursor
  wm protocol .viewer WM_DELETE_WINDOW cancelCmd
  # create a cursor for traversing the table
  set curResult \
  [pg_exec $conn "declare aCursor scroll cursor with hold for \
    select * from $table "]
  #puts "create cursor status [pg_result $curResult -status]"
  pg_result $curResult -clear
  
  # load the initial page
  gofwd
    
}

