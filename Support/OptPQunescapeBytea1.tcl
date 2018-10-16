#!/usr/bin/tclsh
#filename PQunescapeBytea.tcl

proc isFirstOctal { ch } {
   if { "0" <= $ch && $ch <= "3"} {
      return 1
    } else { return 0}
}

proc isOctal { ch } {
   return { "0" <= $ch && $ch <= "7"}
}

proc octalValue {ch } {
  
  return [expr $ch - "0"]
}

proc toChar {intVal} {
   return [format %c $intVal]
}
   
proc PQunescapeBytea {str } {

  set buffer ""
  set strtextlen [string length $str]
  
  set i 0
  
while { $i < $strtextlen } {
 if {[string index $str $i ] =="\\"} {
         incr i
	     if { [string index $str $i] == "\\" } { 
			append buffer "\\" ; incr i 
		  } else {
			   if { [isFirstOctal [string index $str $i] ] && \
				    [isOctal [string index $str [expr $i + 1]] ]&& \
				    [isOctal [string index $str [expr $i + 2]] ]
				   } {
					  set byte [expr [string index $str $i] - "0"]
					  incr i
					  set byte [expr ( $byte << 3) +[expr [string index $str $i]-"0"]]
					  incr i
					  set byte [expr ( $byte << 3) +[expr [string index $str $i]-"0"]]
					  incr i
					  append buffer [format %c $byte ]
				     }		
                   }
     } else {
         append buffer [string index $str $i]
         incr i
       }
  }   
   return $buffer
 }
 
 #set jack [ PQunescapeBytea "What is\\012using\\012whatever"]
 #puts $jack
