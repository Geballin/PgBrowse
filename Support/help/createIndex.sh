#!/bin/sh
>cmds
psql -c'\h' | cut -c3-28 >> cmds
psql -c'\h' | cut -c29-54 >> cmds
psql -c'\h' | cut -c55-81 >> cmds
sed -e'1d' -e '/^ *$/d' cmds > allCmds
rm cmds
psql -c'\h *' > HelpFile
