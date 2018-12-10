AC_INIT(pgBrowse, 1.9)
AM_INIT_AUTOMAKE
AC_CONFIG_SRCDIR([Support/pgin.tcl])
echo 'supportdir_files =\' > supportfiles.mk
find Support -type f -print | sed 's/^/\t/;$q;s/$/ \\/' >> supportfiles.mk
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
