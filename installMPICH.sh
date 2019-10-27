#!/bin/bash
#
# (C) 2019 Andrey Tabakov <komdosh@yandex.ru> 
# Script for download, unpack and build MPICH CH4 for developing purposes
##

################################
## Constants
################################

LOG_PREFIX="[InstallMPICH]:"

MPICH_DIR_NAME="mpich"
INSTALLATION_PATH_PREFIX="/opt/$MPICH_DIR_NAME/"
MPICH_VERSION="3.3"
MPICH_NAME="mpich-$MPICH_VERSION"
MPICH_GITHUB_NAME="mpich"


CURRENT_MPICH_NAME=$MPICH_NAME

HELP="Usage: installMpich.sh [Build Option] [Ad Options]
Build MPICH option:
	-g - global critical sections
	-p [trylock, handoff] - per-vni critical section
	-d - only download and unpack $CURRENT_MPICH_NAME
	
Additional Options:
	-s - skip manual input [auto launching of: remove previous build,
	                        configure dirs, make && make install] 
	-r - replace sources from dev directory
	-f [branch] - clone mpich sources from github pmodels/mpich
	                        default branch is master
	-h - show this message"

DEBUG_FLAGS="-g3 -gdwarf-2"

if [[ "$OSTYPE" == "linux-gnu" ]]; then
  INSTALL="apt-get"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  INSTALL="brew"
else
  echo "$LOG_PREFIX Only Linux or MacOS is allowed for INSTALL"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "$LOG_PREFIX You should install gcc by your own"
  export CC=/usr/local/bin/gcc-9
fi
################################
## Functions
################################

restoreMPICH()  {
  removeOldInstallation "$CURRENT_MPICH_NAME"
  
  downloadAndUnpackMPICH
}

downloadAndUnpackMPICH()  {
    local tarExtension="tar.gz"
    if test github = false; then
      if test ! -f "$MPICH_NAME.$tarExtension";  then
        echo "$LOG_PREFIX Download mpich sources from http://www.mpich.org ..."
        eval "wget http://www.mpich.org/static/downloads/$MPICH_VERSION/$MPICH_NAME.$tarExtension"
      else 
        echo "$LOG_PREFIX Sources already downloaded"
      fi
      echo "$LOG_PREFIX Unpack sources to $MPICH_NAME"
      eval "tar -xzf $MPICH_NAME.$tarExtension"
    else
      cloneMpichGithub
    fi
}

cloneMpichGithub() {
    if test ! -f "$MPICH_GITHUB_NAME/README"*;  then
      echo "$LOG_PREFIX Clone mpich sources from github ..."
      eval "git clone git@github.com:pmodels/mpich.git"
    else 
      echo "$LOG_PREFIX Repo mpich already downloaded"
    fi
    if test ! -f "$MPICH_GITHUB_NAME/src/hwloc/README"*;  then
      eval "cd $MPICH_GITHUB_NAME/src"
      echo "$LOG_PREFIX Clone hwloc sources from github ..."
      eval "git clone git@github.com:pmodels/hwloc.git"
      eval "cd ../../"
    else 
      echo "$LOG_PREFIX Repo hwloc already downloaded"
    fi
    if test ! -f "$MPICH_GITHUB_NAME/src/izem/README"*;  then
      eval "cd $MPICH_GITHUB_NAME/src"
      echo "$LOG_PREFIX Clone izem sources from github ..."
      eval "git clone git@github.com:pmodels/izem.git"
      eval "cd ../../"
    else 
      echo "$LOG_PREFIX Repo izem already downloaded"
    fi
    if test ! -f "$MPICH_GITHUB_NAME/src/mpid/ch4/netmod/ucx/ucx/README"*;  then
      eval "cd $MPICH_GITHUB_NAME/src/mpid/ch4/netmod/ucx"
      echo "$LOG_PREFIX Clone ucx sources from github ..."
      eval "git clone git@github.com:pmodels/ucx.git"
      eval "cd ../../../../../../"
    else 
      echo "$LOG_PREFIX Repo ucx already downloaded"
    fi
    if test ! -f "$MPICH_GITHUB_NAME/src/mpid/ch4/netmod/ofi/libfabric/README"*;  then
      eval "cd $MPICH_GITHUB_NAME/src/mpid/ch4/netmod/ofi"
      echo "$LOG_PREFIX Clone libfabric sources from github ..."
      eval "git clone git@github.com:pmodels/libfabric.git"
      eval "cd ../../../../../../"
    else 
      echo "$LOG_PREFIX Repo libfabric already downloaded"
    fi
}


getMPICHSources() { 
  local reinstallMPICH=""

  if test ! -d "$CURRENT_MPICH_NAME"; then
	  echo "$LOG_PREFIX There is no installed MPICH. Download and unpack it.."
    downloadAndUnpackMPICH
  else
    if test github = false; then 
      echo "$LOG_PREFIX MPICH already downloaded and unpacked"
	  else
      cloneMpichGithub
    fi
	  if test "$auto" = false; then
      read -r -p "Do you want to delete current mpich directory, download and unpack it again? [y/N]: " reinstallMPICH
    else
      reinstallMPICH="n"
    fi
    
    if test "$reinstallMPICH" = "n" || test "$reinstallMPICH" != "N"; then
      return 0
    fi
    
    restoreMPICH
	fi
	
	if test "$replaceSources" = true; then
	  echo "$LOG_PREFIX Replace sources from dev directory"
	  
    eval "cd $CURRENT_MPICH_NAME"
	  eval "cp -a ../../dev/. ./"
	  eval "cd ../"
	fi
}

createMPICHDir() {
	if test ! -d "$MPICH_DIR_NAME"; then
		echo "$LOG_PREFIX Create MPICH directory"
		mkdir mpich
	else
		echo "$LOG_PREFIX MPICH directory already exists"
	fi
	eval "cd $MPICH_DIR_NAME"
}

initMPICHConfigureOpts() {
  if test $github = true; then
    git fetch
    sh ./autogen.sh
  fi
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
       if test github = false; then
        threadCS="per-vni"
       else
        threadCS="per-vci"
       fi
       izemConfig="--enable-izem=queue \
        --with-zm-prefix=embedded"
       ch4mt="--enable-ch4-mt=$1"
      
  esac
  echo $LOG_PREFIX "Configure MPICH with $threadCS CS to $prefix"
  
  removeOldInstallation "$prefix"
  
  if test $optimizedBuild; then
    CFlags="CFLAGS=-O3"
    CXXFLAGS="CXXFLAGS=-O3"
    performanceKeys="--enable-fast=O3,ndebug \
--disable-error-checking \
--without-timing \
--without-mpit-pvars \
--enable-g=none \
"
  else
    CFlags="CFLAGS=\"$DEBUG_FLAGS\""
    CXXFlags="CXXFLAGS=\"$DEBUG_FLAGS\""
    performanceKeys="--enable-fast=O0 \
    --enable-timing=all \
    --enable-mutex-timing \
    --enable-g=all \
    "
  fi
  
if [[ "$OSTYPE" == "linux-gnu" ]]; then
        LIBFABRIC="/usr/lib64"
elif [[ "$OSTYPE" == "darwin"* ]]; then
        LIBFABRIC="/usr/local/Cellar/libfabric/1.6.2"
fi

  MPICH_CONFIGURE_OPTS="$CFlags \
$CXXFlags \
--silent \
--prefix=$prefix \
--with-hwloc=/opt/hwloc \
--with-device=ch4:ofi \
--with-libfabric=$LIBFABRIC \
--enable-threads=multiple \
--enable-thread-cs=$threadCS \
$performanceKeys \
$izemConfig \
$ch4mt \
--disable-fortran"
 echo $LOG_PREFIX "Configure MPICH: $MPICH_CONFIGURE_OPTS"
}

makeAndInstall() {
	echo $LOG_PREFIX "Make and install MPICH sources"
	make clean;
	make -j 7 && make install
}

removeOldInstallation() {
  if test ! -d "$1"; then
    return 0
  fi
  
  local removeAndContinue=""
  
  if test $auto = false; then
    read -p "Do you want to remove this directory and continue installation? [y/N]: " removeAndContinue
  else
    removeAndContinue="y"
  fi
  
  if test "$removeAndContinue" != "y" && test "$removeAndContinue" != "Y"; then
    return 0
  fi
  
  eval "rm -rf $1"
}

installation()  {
  echo "$LOG_PREFIX MPICH installation started..."
  
  createMPICHDir
  getMPICHSources
  
  eval "cd $CURRENT_MPICH_NAME"
  
  case $1 in 
    global)
      initMPICHConfigureOpts "global"
      ;;
    handoff)
      initMPICHConfigureOpts "handoff"
      ;;
    trylock)
      initMPICHConfigureOpts "trylock"
      ;;
    downloadUnpack)
      # no action
      ;;
    *)
      echo "$LOG_PREFIX Wrong installation function ask developer for fix it"
  esac
  
  case $1 in
    global|handoff|trylock)
      eval "./configure $MPICH_CONFIGURE_OPTS"
      
      if test $auto = false; then
        read -p "Do you want to make and install? [y/N]: " makeInstall
      else
        makeInstall="y"
      fi
  
      if test $auto = true || test "$makeInstall" = "y" || test "$makeInstall" = "Y"; then
        echo "$LOG_PREFIX"
        eval "date"
        makeAndInstall
        echo "$LOG_PREFIX"
        eval "date"
      fi
      ;;
  esac
  
  echo "$LOG_PREFIX MPICH installation finished!"
}

installHwloc() {
      if test -d "/opt/hwloc"; then
       return 0
      fi

		  gitPath=$(command -v git)
		  if test "$gitPath" = ""; then 
		    eval "$INSTALL install git"
		  fi
		  
		  if test ! -d "hwloc"; then
		    git clone https://github.com/open-mpi/hwloc.git
		  fi
		  
		  cd hwloc || exit 1
		  
		  autoconfPath=$(command -v autoconf)
      if test "$autoconfPath" = ""; then
        eval "$INSTALL install autogen"
        eval "$INSTALL install autoconf"
        if [[ "$OSTYPE" != "darwin"* ]]; then
          eval "$INSTALL install xorg-dev"
        fi
		  fi
		  eval "$INSTALL install libtool"
		  ./autogen.sh
		  ./configure --prefix=/opt/hwloc
		  make && make install
		  make
		  make install
		  cd ../
}

################################
## Entry point
################################


if test $# = 0; then
	echo "No args passed to programm, you should pass at least one:
	$HELP"
	exit 1
fi

#skip user manual input:
# - auto make and install
# - auto remove previous build directory
auto=false 

#replace mpich source files from ./dev directory
replaceSources=false

#optimized build without debug info
optimizedBuild=false

#get sources from github repo
github=false

while getopts ":srp:f:o" opt; do
  case $opt in
    s) #skip user manual input
      echo "$LOG_PREFIX Skip manual input"
      auto=true
      ;;
    r) #replace mpich source files from ./dev directory
      replaceSources=true
      ;;
    f) #set mpich source to github
      branch=${OPTARG}
      github=true
      CURRENT_MPICH_NAME=$MPICH_GITHUB_NAME
      if test -z "$branch"; then
			  echo "$LOG_PREFIX Github branch set to master"
        branch="master"
      else
        echo "$LOG_PREFIX Github branch set to $branch"
			fi
      ;;
    p) #check per-vni
		  perVniType=${OPTARG}
      if test "$perVniType" != "trylock" && test "$perVniType" != "handoff"; then
			  echo "$LOG_PREFIX Wrong per-vni type, trylock or handoff only!"
			  exit 1
			fi
			;;
		o) #optimization of installation
		  optimizedBuild=true
		  ;;
  esac
done

OPTIND=1

# installHwloc

while getopts ":gdhp:" opt; do
	case $opt in
		g) #global critical section
      echo "$LOG_PREFIX Use global critical section"
			installation "global"
			;;
		p) #per-vni
		  perVniType=${OPTARG}
		  echo "$LOG_PREFIX per-vni type is $perVniType"
			installation "$perVniType"
			;;
		d) #download and unpack only
			echo "$LOG_PREFIX Download and unpacking mpich"
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
