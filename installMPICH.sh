#!/bin/sh
logPrefix='[InstallMPICH]: '

if test "$1" != 'trylock' && test "$1" != 'handoff' && test "$1" != 'global'; then
  echo $logPrefix'You should pass trylock, handoff or global as first arg'
  return
fi

threadMode="$1"

if test ! -d "mpich"; then
  echo $logPrefix"Create mpich directory"
  mkdir mpich
fi

cd mpich

if test ! -d "mpich-3.3"; then
  echo $logPrefix"There is no installed mpich. Installing it."
  wget http://www.mpich.org/static/downloads/3.3/mpich-3.3.tar.gz
  tar xvzf mpich-3.3.tar.gz
fi

cd mpich-3.3

if test "$threadMode" = 'global'; then 
        echo $logPrefix"Configure global mode"
	./configure CFLAGS="-g3 -gdwarf-2" \
            CXXFLAGS="-g3 -gdwarf-2" \
            --prefix=/opt/mpich/mpich4-global \
            --with-device=ch4:ofi \
            --with-libfabric=/usr/lib64 \
	    --enable-threads=multiple \
	    --enable-thread-cs=global \
	    --enable-mutex-timing \
            --enable-g=all \
            --enable-fast=O0 \
	    --enable-timing=all \
            --disable-fortran
fi

echo  $threadMode
if test "$threadMode" = 'handoff' || test "$threadMode" = 'trylock'; then 
        echo $logPrefix"Configure "$threadMode" mode"
	./configure CFLAGS="-g3 -gdwarf-2" \
            CXXFLAGS="-g3 -gdwarf-2" \
            --prefix=/opt/mpich/mpich4-pervni-$threadMode \
            --with-device=ch4:ofi \
            --with-libfabric=/usr/lib64 \
            --enable-threads=multiple \
            --enable-thread-cs=per-vni \
            --enable-mutex-timing \
            --enable-g=all \
            --enable-fast=O0 \
            --enable-timing=all \
            --enable-ch4-mt=$threadMode \
            --enable-izem=queue \
            --with-zm-prefix=embedded \
            --disable-fortran
fi

echo $logPrefix"make sources"
make && make install




