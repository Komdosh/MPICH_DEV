#!/bin/sh

echo "mpiexec:"
find $(pwd)/mpich/compiled -name mpiexec
echo ""
echo "mpicc:"
find $(pwd)/mpich/compiled -name mpicc
echo ""
echo "mpic++:"
find $(pwd)/mpich/compiled -name mpic++