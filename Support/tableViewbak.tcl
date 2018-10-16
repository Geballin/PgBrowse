#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec wish "$0" ${1+"$@"}

package require Tk
package require Tktable
package require Pgtcl

proc make_table1 { parent } {
    global table_data1
    table $parent.table \
    -variable table_data1 \
    -yscrollcommand "$parent.sy set" \
    -xscrollcommand "$parent.sx set" \
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
   scrollbar $parent.sx -orient horizontal -command [list $parent.table xview]
   scrollbar $parent.sy -command " $parent.table yview"
   
   
  return $parent.table  
  
}

proc colproc col { if { $col >= 0 } { return "anchorwest" } }
proc rowproc row { if { $row >= 0 && $row%2 } { return "rowColor" } }

proc buildUI {} {
    global table_data
    global theTable
    
    toplevel .viewer
    
    frame .viewer.tabframe

   
    set theTable [ make_table1 .viewer.tabframe]
    pack .viewer.tabframe -fill both -expand yes
    
    pack .viewer.tabframe.sx -side bottom -fill x
    pack .viewer.tabframe.sy -side right -fill y
    pack $theTable -side top -fill both -expand yes
   
    frame .viewer.buttonFrame
    button .viewer.buttonFrame.goback -text " < " -command "goback"
    pack .viewer.buttonFrame.goback -side left
    button .viewer.buttonFrame.gofwd -text " > " -command "gofwd"
    pack .viewer.buttonFrame.gofwd -side left
    button .viewer.buttonFrame.cancel -text "Cancel" -command "cancelCmd"
    pack .viewer.buttonFrame.cancel -side right
    
    pack .viewer.buttonFrame -expand no

} 

proc goback {} {
    puts "goback called"
}

proc gofwd {} {
    puts "gofwd called"
}

proc cancelCmd {} {
   destroy .viewer
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
    -rows [expr {$row_cnt + 2 }] \
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
  set col_attrs [pg_result $result_set -lxAttributes]
  set conn [pg_result $result_set -conn]

  for {set col 0} {$col < $col_cnt} {incr col} {
    set col_name [lindex $col_names $col]
    
    set colnamelist [lindex $col_attrs $col]
    set colname [lindex $colnamelist 0]
    set coltype [lindex $colnamelist 1]
    set colmod  [lindex $colnamelist 3]
    set typeRes 0
  
    set typeRes [pg_exec $conn "select format_type( $coltype,$colmod)" ]
    #puts [pg_result $typeRes -status]
    set typeName [pg_result $typeRes -list ] 
    #puts "type name = $typeName"
    #puts "$colname $coltype $colmod $typeName"
    pg_result $typeRes -clear
    set col_name "$col_name / $typeName"
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
  #set displayNULL 1
  
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
    for {set col 0} {$col < $col_cnt} { incr col } {
        $table set $row,$col "*"
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

proc set_globals {} {
    global displayNULL
    global longField
    set longField 0
    set displayNULL 0
}
# main code starts here
# some simple testing here for a while

proc showTheEditWindow { table conn } {
  set_globals
  global theTable
  #set conn [pg_connect -conninfo ""]
  
  buildUI
   
  set result [pg_exec $conn "select * from $table limit 20"]
  set attr [pg_result $result -lxAttributes]
  
  set col_cnt [pg_result $result -numAttrs ]
  
  for {set col 0 } { $col < $col_cnt } { incr col } {
    set colnamelist [lindex $attr $col]
    set colname [lindex $colnamelist 0]
    set coltype [lindex $colnamelist 1]
    set colmod  [lindex $colnamelist 3]
    set typeRes 0
  
    set typeRes [pg_exec $conn "select format_type( $coltype,$colmod)" ]
    puts [pg_result $typeRes -status]
    set typeName [pg_result $typeRes -list ] 
    puts "type name = $typeName"
    puts "$colname $coltype $colmod $typeName"
    pg_result $typeRes -clear
  }  
  load_table $theTable $result
  #tkwait window .
  #pg_disconnect $conn
  
}

#showTheEditWindow { "hello" }