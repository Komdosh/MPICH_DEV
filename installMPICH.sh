#!/bin/sh
#
# (C) 2019 Andrey Tabakov <komdosh@yandex.ru>
# Script for download, unpack and build MPICH CH4 for developing purposes
##

# shellcheck disable=SC2039

################################
## Constants
################################

LOG_PREFIX="[InstallMPICH]:"

ADDITIONAL_INSTALLATION_PATH_SUFFIX=""
MPICH_DIR_NAME="mpich"
INSTALLATION_PATH_PREFIX="/opt/$MPICH_DIR_NAME/$ADDITIONAL_INSTALLATION_PATH_SUFFIX"
MPICH_PATH=""
SCRIPT_OSTYPE=""
MPICH_VERSION="3.3.1"
MPICH_NAME="mpich-$MPICH_VERSION"
MPICH_GITHUB_NAME="mpich"
LOG_FILE_PATH="installationLogs.txt"

CURRENT_MPICH_NAME=$MPICH_NAME

USAGE_EXAMPLES="  1.  Install MPICH with global critical sections
    and avoid user prompt with default answers

      sh installMPICH.sh -g -s

  2.  Install MPICH with per-vci trylock critical sections from github master branch
    and avoid user prompt with default answers

      sh installMPICH.sh -p trylock -s -b

  3.  Install MPICH with per-vci handoff critical sections from github 3.3.x branch with
     source replace from ./dev directory

      sh installMPICH.sh -p handoff -b 3.3.x -r"
HELP="
Usage: sh installMpich.sh [Build Option] [Ad Options]

Build MPICH option:
	-g - global critical sections
	-p [trylock, handoff] - per-vci critical section
	-d - only download and unpack $CURRENT_MPICH_NAME from \"https://www.mpich.org/\"
	
Additional Options:
	-s - skip manual input [auto launching of: remove previous build,
	                        configure dirs, make && make install] 
	-r - replace sources from ./dev directory (sources must be in the same directory
	      path relative to ./dev as for MPICH)
	-b [branch] - clone mpich sources from github pmodels/mpich
	              default branch is master \"https://github.com/pmodels/mpich\"
	-i [yourPath] - additional installation path suffix to $INSTALLATION_PATH_PREFIX/{yourPath}/
	-o - optimized installation build
	-h - show this message
	-l [logfile path] - MPICH configure and install logs will be print into this file
	              it is installationLogs.txt by default

Usage examples:
$USAGE_EXAMPLES
"

DEBUG_FLAGS="-g3 -gdwarf-2"
OSTYPE="$OSTYPE"
SCRIPT_OSTYPE="$OSTYPE"

################################
## Functions
################################

setupOSDeps() {
  OSTYPE="$OSTYPE"
  if test -z "$OSTYPE"; then
    echo "Unknown operation system, script may not work properly"
  fi

  if test "$OSTYPE" == "linux-gnu"; then
    SCRIPT_OSTYPE="linux-gnu"
    INSTALL="apt-get"
  else
    local os
    os=$(echo "$OSTYPE" | cut -c1-6)
    if test "$os" == "darwin"; then
      SCRIPT_OSTYPE="darwin"
      INSTALL="brew"
    else
      echo "$LOG_PREFIX Unknown OS: $OSTYPE. Only GNU Linux or MacOS is allowed for INSTALL"
    fi
  fi

  if test "$OSTYPE" == "darwin"; then
    if test CC_PATH == ""; then
      CC_PATH=/usr/local/bin/gcc-9
    fi
    echo "$LOG_PREFIX You should install gcc by your own, and set CC_PATH environment variable, now path is $CC_PATH"
    export CC=CC_PATH
  fi
}

restoreMPICH() {
  removeOldInstallation "$CURRENT_MPICH_NAME"

  getMPICH
}

getMPICH() {
  SECONDS=0
  local tarExtension="tar.gz"
  if test "$github" = false; then
    if test ! -f "$MPICH_NAME.$tarExtension"; then
      echo "$LOG_PREFIX Download mpich sources from http://www.mpich.org ..."
      eval "wget http://www.mpich.org/static/downloads/$MPICH_VERSION/$MPICH_NAME.$tarExtension"
      showElapsedTime "MPICH downloaded"
    else
      echo "$LOG_PREFIX Sources already downloaded"
    fi
    echo "$LOG_PREFIX Unpack sources to $MPICH_NAME"
    eval "tar -xzf $MPICH_NAME.$tarExtension"
    showElapsedTime "MPICH downloaded"
  else
    cloneMpichGithub
  fi
}

cloneMpichGithub() {
  if test ! -f "$MPICH_GITHUB_NAME/README.vin"; then
    echo "$LOG_PREFIX Clone mpich sources from github ..."
    eval "git clone git@github.com:pmodels/mpich.git"
  else
    echo "$LOG_PREFIX Repo mpich already downloaded"
  fi
  if test ! -f "$MPICH_GITHUB_NAME/src/hwloc/README"; then
    eval "cd $MPICH_GITHUB_NAME/src"
    echo "$LOG_PREFIX Clone hwloc sources from github ..."
    eval "git clone git@github.com:pmodels/hwloc.git"
    eval "cd ../../"
  else
    echo "$LOG_PREFIX Repo hwloc already downloaded"
  fi
  if test ! -f "$MPICH_GITHUB_NAME/src/izem/README.md"; then
    eval "cd $MPICH_GITHUB_NAME/src"
    echo "$LOG_PREFIX Clone izem sources from github ..."
    eval "git clone git@github.com:pmodels/izem.git"
    eval "cd ../../"
  else
    echo "$LOG_PREFIX Repo izem already downloaded"
  fi
  if test ! -f "$MPICH_GITHUB_NAME/src/mpid/ch4/netmod/ucx/ucx/README.md"; then
    eval "cd $MPICH_GITHUB_NAME/src/mpid/ch4/netmod/ucx"
    echo "$LOG_PREFIX Clone ucx sources from github ..."
    eval "git clone git@github.com:pmodels/ucx.git"
    eval "cd ../../../../../../"
  else
    echo "$LOG_PREFIX Repo ucx already downloaded"
  fi
  if test ! -f "$MPICH_GITHUB_NAME/src/mpid/ch4/netmod/ofi/libfabric/README"; then
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
    getMPICH
  else
    if test "$github" = false; then
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

changeOwnershipToUser() {
  dir="$1"

  if ! [ "$(id -u)" -eq 0 ]; then
    echo "$LOG_PREFIX This script doesn't have enough rights
      to write to $dir directory. You should make it available"
    exit 0
  fi
  SCRIPT_USER=""
  if test -z "$SUDO_USER"; then
    SCRIPT_USER="$USER"
  else
    SCRIPT_USER="$SUDO_USER"
  fi

  chown -R "$SCRIPT_USER" "$dir"
}

initMPICHConfigureOpts() {
  if test "$github" = true; then
    git fetch &> $LOG_FILE_PATH
    sh ./autogen.sh &> $LOG_FILE_PATH
  fi

  local threadCS=""
  local izemConfig="" #izem necessary only for per-vci CS
  local ch4mt=""      #multithread algorithm necessary only for per-vci CS

  case $1 in
  global)
    MPICH_PATH=$INSTALLATION_PATH_PREFIX"global"
    threadCS="global"
    ;;
  handoff | trylock)
    MPICH_PATH=$INSTALLATION_PATH_PREFIX"per-vci-"$1
    if test "$github" = false; then
      threadCS="per-vni" #new mpich will use per-vci, instead of per-vni option
    else
      threadCS="per-vci"
    fi
    izemConfig="--enable-izem=queue \
        --with-zm-prefix=embedded"
    ch4mt="--enable-ch4-mt=$1"
    ;;
  esac

  if test ! -d "$MPICH_PATH"; then
    mkdir "$MPICH_PATH"
  fi
  changeOwnershipToUser "$MPICH_PATH"

  echo "$LOG_PREFIX Configure MPICH with $threadCS CS to $MPICH_PATH"

  removeOldInstallation "$MPICH_PATH"

  if test "$optimizedBuild" = true; then
    CFlags="CFLAGS=-O3"
    CXXFlags="CXXFLAGS=-O3"
    performanceKeys="--enable-fast=O3,ndebug \
    --disable-error-checking \
    --without-timing \
    --without-mpit-pvars \
    --enable-g=none"
  else
    CFlags="CFLAGS=\"$DEBUG_FLAGS\"" \
    CXXFlags="CXXFLAGS=\"$DEBUG_FLAGS\"" \
    performanceKeys="--enable-fast=O0 \
  --enable-timing=all \
  --enable-mutex-timing \
  --enable-g=all"
  fi

  if test "$SCRIPT_OSTYPE" == "linux-gnu"; then
    LIBFABRIC="/usr/lib64"
  elif test "$SCRIPT_OSTYPE" == "darwin"; then
    LIBFABRIC="/usr/local/Cellar/libfabric/1.6.2"
  fi

  MPICH_CONFIGURE_OPTS="$CFlags \
  $CXXFlags \
  --silent \
  --prefix=$MPICH_PATH \
  --with-hwloc=/opt/hwloc \
  --with-device=ch4:ofi \
  --with-libfabric=$LIBFABRIC \
  --enable-threads=multiple \
  --enable-thread-cs=$threadCS \
  --disable-fortran \
  $performanceKeys \
  $izemConfig \
  $ch4mt"
  echo "$LOG_PREFIX Configure MPICH: $MPICH_CONFIGURE_OPTS"
}

makeAndInstall() {
  SECONDS=0
  echo "$LOG_PREFIX Make and install MPICH sources"
  make clean &> $LOG_FILE_PATH
  make -j 7 &> $LOG_FILE_PATH
  make install &> $LOG_FILE_PATH
  showElapsedTime "MPICH installed"
}

removeOldInstallation() {
  if test ! -d "$1"; then
    return 0
  fi

  local removeAndContinue=""

  if test "$auto" = false; then
    read -r -p "Do you want to remove this directory and continue installation? [y/N]: " removeAndContinue
  else
    removeAndContinue="y"
  fi

  if test "$removeAndContinue" != "y" && test "$removeAndContinue" != "Y"; then
    return 0
  fi

  eval "rm -rf $1"
}

installation() {
  echo "$LOG_PREFIX MPICH installation started..."

  createMPICHDir
  getMPICHSources

  eval "cd $CURRENT_MPICH_NAME"

  installationType="$1"

  case $installationType in
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
    ;;
  esac

  case $installationType in
  global | handoff | trylock)
    SECONDS=0
    eval "./configure $MPICH_CONFIGURE_OPTS" &> $LOG_FILE_PATH
    showElapsedTime "MPICH configured"

    if test "$auto" = false; then
      read -r -p "Do you want to make and install? [y/N]: " makeInstall
    else
      makeInstall="y"
    fi

    if test "$auto" = true || test "$makeInstall" = "y" || test "$makeInstall" = "Y"; then
      makeAndInstall
    fi
    ;;
  esac

  changeOwnershipToUser $INSTALLATION_PATH_PREFIX
  echo "$LOG_PREFIX MPICH installation finished! MPICH directory: $INSTALLATION_PATH_PREFIX"
}

installHwloc() {
  SECONDS=0
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
    if test "$SCRIPT_OSTYPE" != "darwin"; then
      eval "$INSTALL install xorg-dev"
    fi
  fi
  eval "$INSTALL install libtool"
  ./autogen.sh &> $LOG_FILE_PATH
  ./configure --prefix=/opt/hwloc &> $LOG_FILE_PATH
  make &> $LOG_FILE_PATH
  make install &> $LOG_FILE_PATH
  cd ../
  showElapsedTime "hwloc installed"
}

initDefaultOptions() {
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

  #github branch
  branch="master"

  setupOSDeps
}

showElapsedTime(){
  message=$1
  duration=$SECONDS
  echo "$LOG_PREFIX $message in $(($duration / 60)) min and $(($duration % 60)) sec"
}

################################
## Entry point
################################

if test $# = 0; then
  echo "No args passed to programm, you should pass at least one:
	$HELP"
  exit 1
fi

initDefaultOptions

while getopts ":srp:b:i:ol:" opt; do
  case $opt in
  s) #skip user manual input
    echo "$LOG_PREFIX Skip manual input"
    auto=true
    ;;
  r) #replace mpich source files from ./dev directory
    replaceSources=true
    ;;
  b) #set mpich source to github
    github=true
    CURRENT_MPICH_NAME=$MPICH_GITHUB_NAME
    if test -n "$OPTARG"; then
      branch=${OPTARG}
    fi
    echo "$LOG_PREFIX Github branch set to $branch"
    ;;
  p) #check per-vci
    perVciType=${OPTARG}
    if test "$perVciType" != "trylock" && test "$perVciType" != "handoff"; then
      echo "$LOG_PREFIX Wrong per-vci type, trylock or handoff only!"
      exit 1
    fi
    ;;
  o) #optimized installation build
    optimizedBuild=true
    ;;
  i)
    ADDITIONAL_INSTALLATION_PATH_SUFFIX=${OPTARG}
    echo "$LOG_PREFIX Additional installation path suffix is set to $ADDITIONAL_INSTALLATION_PATH_SUFFIX"
    ;;
  l)
    LOG_FILE_PATH="../../${OPTARG}"
    rm -rf "$LOG_FILE_PATH"
    echo "$LOG_PREFIX logfile path set to $LOG_FILE_PATH"
    ;;
  \?) #end of line
    #do nothing
    ;;
  :) #empty or unknown arg
    #do nothing
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
  p) #per-vci
    perVciType=${OPTARG}
    echo "$LOG_PREFIX per-vci type is $perVciType"
    installation "$perVciType"
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
