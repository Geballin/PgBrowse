REM BATCH script to generate windows Starpack of PgBrowse
REM sdx.kit must be in ../ as well as your tclkit

mkdir PgBrowse.vfs
copy pgBrowse.tcl PgBrowse.vfs\main.tcl
copy README.md PgBrowse.vfs\
mkdir PgBrowse.vfs\Support
xcopy Support PgBrowse.vfs\Support\ /s
move PgBrowse.vfs\icone.ico PgBrowse.vfs\tclkit.ico
move PgBrowse.vfs\tclkit.inf PgBrowse.vfs\tclkit.inf

tclsh ../sdx.kit wrap PgBrowse.exe -runtime ../kbsvq8.6-bi-0.4.7.exe
