#!/bin/sh
#
# (C) 2019 Andrey Tabakov <komdosh@yandex.ru> 
# Script for download, unpack and build MPICH CH4 for developing purposes
##

################################
## Constants
################################

LOG_PREFIX="[InstallMPICH]:"
INSTALLATION_PATH_PREFIX=""

HELP="-g - global critical sections
	-t - algorithm for per-vni critical section - trylock
	-f - algorithm for per-vni critical section - handoff
	-d - only downloading and unpacking mpich-3.3
	-h - show this message"

DEBUG_FLAGS="-g3 -gdwarf-2"
MPICH_CONFIGURE_CFLAGS="$DEBUG_FLAGS"
MPICH_CONFIGURE_CXXFLAGS="$DEBUG_FLAGS"

################################
## Functions
################################

downloadAndUnpackMPICH() {
	if test ! -d "mpich-3.3"; then
		echo $LOG_PREFIX "There is no installed MPICH. Download and unpacking.."
		if test ! -f "mpich-3.3.tar.gz"; then
		  wget http://www.mpich.org/static/downloads/3.3/mpich-3.3.tar.gz
		fi
		tar xvzf mpich-3.3.tar.gz
	else
		echo $LOG_PREFIX "MPICH already downloaded and upacked"
	fi
}

createMPICHDir() {
	if test ! -d "mpich"; then
		echo $LOG_PREFIX "Create MPICH directory"
		mkdir mpich
	else
		echo $LOG_PREFIX "MPICH directory already exists"
	fi
	cd mpich
}

initMPICHConfigureOpts() {
  local prefix="/opt/mpich/"
  local threadCS=""
  local izemConfig="" #izem necessary only for per-vni CS
  local ch4mt="" #multithread algorithm necessary only for per-vni CS
  
  case $1 in 
    global)
      prefix=$prefix"global"
      threadCS="global"
      ;;
    handoff|trylock)
       prefix=$prefix"per-vni-"$1
       threadCS="per-vni"
       izemConfig="--enable-izem=queue \
        --with-zm-prefix=embedded"
       ch4mt="--enable-ch4-mt=$1"
      ;;
  esac
  
  removeOldInstallation "$prefix"
  
  MPICH_CONFIGURE_OPTS="CFLAGS=\"$MPICH_CONFIGURE_CFLAGS\" \
CXXFLAGS=\"$MPICH_CONFIGURE_CXXFLAGS\" \
--prefix=$prefix \
--with-device=ch4:ofi \
--with-libfabric=/usr/lib64 \
--enable-threads=multiple \
--enable-thread-cs=$threadCS \
--enable-mutex-timing \
--enable-g=all \
--enable-fast=O0 \
--enable-timing=all \
$izemConfig \
$ch4mt \
--disable-fortran"
 echo "$MPICH_CONFIGURE_OPTS"
}

makeAndInstall() {
	echo $LOG_PREFIX "Make and install MPICH sources"
	make && make install
}

removeOldInstallation() {
  if test ! -d "$1"; then
    return 0
  fi
  
  read -p "Do you want to remove this folder and continue installation? [y/N]: " removeAndContinue

  if test "$removeAndContinue" != "y" && test "$removeAndContinue" != "Y"; then
    exit 0
  fi
  
  eval "rm -rf $1"
}

installation()  {
  echo $LOG_PREFIX "MPICH installation started..."
  
  createMPICHDir
  downloadAndUnpackMPICH
  
  cd mpich-3.3
  
  case $1 in 
    global)
     echo $LOG_PREFIX "Configure MPICH with global CS to /opt/mpich/global"
      initMPICHConfigureOpts "global"
      ;;
    handoff)
      echo $LOG_PREFIX "Configure MPICH with per-vni CS to /opt/mpich/per-vni-handoff"
      initMPICHConfigureOpts "handoff"
      ;;
    trylock)
      echo $LOG_PREFIX "Configure MPICH with per-vni CS to /opt/mpich/per-vni-trylock"
      initMPICHConfigureOpts "trylock"
      ;;
    downloadUnpack)
      # no action
      ;;
    *)
      echo $LOG_PREFIX "Wrong installation function ask developer for fix it"
  esac
  
  case $1 in
    global|handoff|trylock)
      eval "./configure $MPICH_CONFIGURE_OPTS"
      makeAndInstall
      ;;
  esac
  
  echo $LOG_PREFIX "MPICH installation finished!"
}

################################
## Entry point
################################

if test $# = 0; then
	echo "No args passed to programm, you should pass at least one of those:
	$HELP"
	exit 1
fi

while getopts ":gtfdh" opt; do
	case $opt in
		g) #global critical section
			installation "global"
			;;
		t) #per-vni handoff
			installation "trylock"
			;;
		f) #per-vni handoff
			installation "handoff"
			;;
		d) #downloading and unpacking
			echo $LOG_PREFIX "Download and unpacking mpich"
			installation "downloadUnpack"
			;;
		h) #help message
			echo "	$HELP"
			;;
		\?) #end of line
			exit 1
			;;
		:) #empty arg
			exit 2
			;;
    esac
done

exit 0







