#! /usr/bin/env sh
# Shell script to generate windows Starpack of PgBrowse
# sdx.kit must be in ../ as well as your tclkit.exe

mkdir PgBrowse.vfs
cp pgBrowse.tcl PgBrowse.vfs/main.tcl
cp -r Support PgBrowse.vfs/
mv PgBrowse.vfs/Support/icone.ico PgBrowse.vfs/tclkit.ico

tclsh ../sdx.kit wrap PgBrowse -runtime ../tclkit.exe
mv PgBrowse PgBrowse.exe
