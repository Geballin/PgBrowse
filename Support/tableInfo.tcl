proc showOneTable { table conn } {
    global ui_vars
    # Get the selected item
    set tabIndex [$table curselection]
    if { $tabIndex == ""} {
         tk_messageBox -title PgBrowser \
                    -message "No Table Selected."  \
                    -type  ok \
                    -icon error
         return
    }
    set tableName [$table get $tabIndex]
    ### JHL divert to newer table viewer to prevent overflow
    showTheEditWindow $tableName $conn
    return
    #####################
    # set the selection query
    set queryStr "select * from $tableName"
    # clean out the sql window
    $ui_vars(code) delete 1.0 end
    # stick in the new query
    $ui_vars(code) insert end $queryStr
    # clean out the status window
    $ui_vars(cmdStatus) delete 1.0 end
    # execute the query
    process_command $conn $ui_vars(table) $queryStr
   }

proc describetable { table conn } {
     global ui_vars
     # Get the selected item
    set tabIndex [$table curselection]
    if { $tabIndex == ""} {
       tk_messageBox -title PgBrowser \
                    -message "No Table Selected."  \
                    -type  ok
       return
    }
    set tableName [$table get $tabIndex]    
    # set the selection query
    set theName [lindex [split $tableName "."] 1]
    set queryStr ""
    append queryStr  \
    "SELECT a.attname, format_type(a.atttypid, a.atttypmod), a.attnotnull\n" \
    "FROM pg_class c, pg_attribute a WHERE c.relname = \'" $theName\
    "\'\nAND a.attnum > 0 AND a.attrelid = c.oid\n ORDER BY a.attnum"
    # clean out the sql window
    $ui_vars(code) delete 1.0 end
    # stick in the new query
    $ui_vars(code) insert end $queryStr
    # clean out the status window
    $ui_vars(cmdStatus) delete 1.0 end
    # execute the query
    process_command $conn $ui_vars(table) $queryStr
   }
    
proc showTableInfo { conn } {

global ui_vars

toplevel .showtable

 listbox .showtable.tables -width 30 -height 10  \
      -borderwidth 3 \
      -relief groove \
      -yscrollcommand {.showtable.sy set } 
  ttk::scrollbar .showtable.sy -command [list .showtable.tables yview]
  
  ttk::frame .showtable.bframe
  
  pack .showtable.bframe -side bottom
  
  ttk::button .showtable.bframe.showtab -text "Edit Table" \
     -command [list showOneTable .showtable.tables $conn ]
     
  ttk::button .showtable.bframe.describetab -text "Describe Table" \
      -command [list describetable .showtable.tables $conn]
  
  ttk::button .showtable.bframe.exit -text "Exit Show Tables" -command {destroy .showtable }

  pack .showtable.bframe.showtab -side left
  pack .showtable.bframe.describetab -side left
  pack .showtable.bframe.exit -side left
  pack .showtable.tables -side left -expand true -fill both -padx 4 -pady 4
  pack .showtable.sy -side right -fill y -padx 4
  bind .showtable.tables <Double-1> [list showOneTable .showtable.tables $conn ]
  # load the listbox
  
  # step 1 set the query string
  set queryStr "select table_schema, table_name,table_type from \
    information_schema.tables where table_schema = 'public' order by table_schema desc, table_type asc"
    
  # do the query
  set result_set [pg_exec $conn $queryStr] 
 
  # check the results
  if { [pg_result $result_set -status] != "PGRES_TUPLES_OK" } {
       tk_messageBox -title PgBrowser \
                   -message "Cannot Build Table List."  \
                   -type  ok \
                   -icon error
       return
   }
   
   # Start adding items to the listbox, we will use the 
   # fully qualified name.
   set row_cnt [pg_result $result_set -numTuples]
   for { set i 0} { $i < $row_cnt } { incr i } {
     set tuple [pg_result $result_set -getTuple $i]
     .showtable.tables insert end [lindex $tuple 1]
    }
    
   # return memory
   pg_result $result_set -clear
}
