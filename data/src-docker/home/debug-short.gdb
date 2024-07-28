set pagination off
set logging file ~/build/.gdb-output
set logging on

run
thread apply all bt

set logging off
quit
