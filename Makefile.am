include ./supportfiles.mk

bin_SCRIPTS = pgbrowse
pgbrowse:
	echo "#! /bin/sh" >$@
	echo 'tclsh `dirname $$0`/../share/pgbrowse/pgBrowse.tcl' >>$@
	chmod ugo+x $@
appdir = $(prefix)/share/applications
app_DATA = pgbrowse.desktop
pgbrowse.desktop:
	echo "[Desktop Entry]" >$@
	echo "Name=PgBrowse" >>$@
	echo "Comment=PostgreSQL data browser" >>$@
	echo "Exec=pgbrowse" >>$@
	echo  'Icon=$(pkgdatadir)/Support/icone.png' >>$@
	echo "Terminal=false" >>$@
	echo "Type=Application" >>$@
	echo "Categories=Development;Database;" >>$@
	echo "StartupNotify=true;" >>$@
	chmod 644 $@
CLEANFILES = pgbrowse pgbrowse.desktop
pkgdata_SCRIPTS = pgBrowse.tcl
dist_pkgdata_DATA = pgBrowse.tcl README
nobase_dist_pkgdata_DATA = $(supportdir_files)
UNINSTALLFILES =    pgBrowse.tcl README $(supportdir_files)
