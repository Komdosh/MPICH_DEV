#!/bin/bash            
#
# (C) 2018 Alexey Paznikov <apaznikov@gmail.com> 
# Script for running of MPI program with debugging in GDB
##

export MPIR_CVAR_ASYNC_PROGRESS=1

EXEC_PATH=/home/parallels/mpich/projects/MPI/VerySimple/cmake-build-debug
EXEC=VerySimple
CUSTOM_BUILD_MPICH_FOLDER=/home/parallels/mpich/build
MPI_PER_VNI_TRYLOCK=$CUSTOM_BUILD_MPICH_FOLDER/mpich4-pervni-trylock/bin
MPI_PER_VNI_HANDOFF=$CUSTOM_BUILD_MPICH_FOLDER/mpich4-pervni-handoff/bin

CURRENT_MPI=$MPI_PER_VNI_HANDOFF

PROCNUM=2

# Height and width for a half of screen (in symbols)
NCOLS=100
NROWS=55

pkill $EXEC

$CURRENT_MPI/mpiexec -host localhost -n $PROCNUM $EXEC_PATH/$EXEC &

sleep 1

for ((proc = 1; proc <= PROCNUM; proc++)); do
    pid=`pgrep $EXEC | sed -n ${proc}p`
    if (( proc % 2 == 1)); then
        term_x=0
    else
        let term_x="`xdpyinfo | grep dimensions | \
                sed -r 's/^[^0-9]*([0-9]+).*$/\1/'` / 2"
    fi
    echo $pid
    gnome-terminal -q --hide-menubar --geometry=${NCOLS}x${NROWS}+${term_x}+0 \
        -e "sh -c \"sleep 1; gdb -tui -p $pid\""
done
