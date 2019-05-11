#!/bin/sh
#
# (C) 2019 Andrey Tabakov <komdosh@yandex.ru> 
# Script for download, unpack and build MPICH CH4 for developing purposes
##

################################
## Constants
################################

LOG_PREFIX="[InstallMPICH]:"
INSTALLATION_PATH_PREFIX="/opt/mpich/"
MPICH_DIR_NAME="mpich-3.3"


HELP="Usage: installMpich.sh [Build Option] [Ad Options]
Build MPICH option:
  -g - global critical sections
	-t - algorithm for per-vni critical section - trylock
	-f - algorithm for per-vni critical section - handoff
	-d - only download and unpack mpich-3.3
	
Additional Options:
	-s - skip manual input [auto launching of: remove previous build and configure dirs, make && make install] 
	-r - replace sources from dev directory
	-h - show this message"

DEBUG_FLAGS="-g3 -gdwarf-2"
MPICH_CONFIGURE_CFLAGS="$DEBUG_FLAGS"
MPICH_CONFIGURE_CXXFLAGS="$DEBUG_FLAGS"

################################
## Functions
################################

restoreMPICH()  {
  removeOldInstallation "$MPICH_DIR_NAME"
}

downloadAndUnpackMPICH()  {
		if test ! -f "$MPICH_DIR_NAME.tar.gz"; then
		  echo $LOG_PREFIX "Download mpich sources..."
		  wget http://www.mpich.org/static/downloads/3.3/mpich-3.3.tar.gz
		else 
		  echo $LOG_PREFIX "Sources already downloaded"
		fi
		echo $LOG_PREFIX "Unpack sources to $MPICH_DIR_NAME"
		tar -xzf mpich-3.3.tar.gz
}

getMPICHSources() {
	if test ! -d "$MPICH_DIR_NAME"; then
		echo $LOG_PREFIX "There is no installed MPICH. Download and unpacking.."
    downloadAndUnpackMPICH
	else
	  echo $LOG_PREFIX "MPICH already downloaded and unpacked"
	  
	  local reinstallMPICH
	  if test $auto = false; then
      read -p "Do you want to delete current mpich directory, download it (if not downloaded) and unpack it again? [y/N]: " reinstallMPICH
    else
      reinstallMPICH = "y"
    fi
    
    if test "$reinstallMPICH" != "y" && test "$reinstallMPICH" != "Y"; then
      return 0
    fi
     
    eval "rm -rf "$MPICH_DIR_NAME""
   
    downloadAndUnpackMPICH
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
  local prefix=$INSTALLATION_PATH_PREFIX
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
      
  esac
  
  removeOldInstallation "$prefix"
  
  MPICH_CONFIGURE_OPTS="CFLAGS=\"$MPICH_CONFIGURE_CFLAGS\" \
CXXFLAGS=\"$MPICH_CONFIGURE_CXXFLAGS\" \
--silent \
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
 echo "Configure MPICH: $MPICH_CONFIGURE_OPTS"
}

makeAndInstall() {
	echo $LOG_PREFIX "Make and install MPICH sources"
	make clean;
	make && make install
}

removeOldInstallation() {
  if test ! -d "$1"; then
    return 0
  fi
  
  local removeAndContinue=""
  
  if test $auto = false; then
    read -p "Do you want to remove this directory and continue installation? [y/N]: " removeAndContinue
  else
    removeAndContinue = "y"
  fi
  
  if test "$removeAndContinue" != "y" && test "$removeAndContinue" != "Y"; then
    return 0
  fi
  
  eval "rm -rf $1"
}

installation()  {
  echo $LOG_PREFIX "MPICH installation started..."
  
  createMPICHDir
  getMPICHSources
  
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
      
      if test $auto = false; then
        read -p "Do you want to make and install? [y/N]: " makeInstall
      else
        removeAndContinue = "y"
      fi
  
      if test $auto = true || test "$makeInstall" = "y" || test "$makeInstall" = "Y"; then
        echo $LOG_PREFIX
        eval "date"
        makeAndInstall
        echo $LOG_PREFIX
        eval "date"
      fi
      ;;
  esac
  
  echo $LOG_PREFIX "MPICH installation finished!"
}

################################
## Entry point
################################

#skip user manual input:
# - auto make and install
# - auto remove previous build directory
auto=false 

#replace mpich source files from @dev directory
replaceSources=false

if test $# = 0; then
	echo "No args passed to programm, you should pass at least one of those:
	$HELP"
	exit 1
fi

while getopts ":sr" opt; do
  case $opt in
    s)
      auto=true
      ;;
    r)
      replaceSources=true
      ;;
  esac
done

OPTIND=1

while getopts ":gtfdh" opt; do
	case $opt in
		g) #global critical section
			installation "global"
			;;
		t) #per-vni trtylock
			installation "trylock"
			;;
		f) #per-vni handoff
			installation "handoff"
			;;
		d) #download and unpack only
			echo $LOG_PREFIX "Download and unpacking mpich"
			installation "downloadUnpack"
			;;
		h) #help message
			echo "	$HELP"
			;;
		\?) #end of line
			exit 1
			;;
		:) #empty or unknown arg
			#do nothing
			;;
    esac
done

exit 0







