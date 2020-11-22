# MPICH_DEV

`installMPICH.sh` - Script for download, unpack and build MPICH CH4 for developing purposes

1.  Install MPICH with global critical sections and avoid user prompt with default answers
   
   `sh installMPICH.sh -g -s`
   
2.  Install MPICH with per-vci trylock critical sections from github master branch and avoid user prompt with default answers
   
   `sh installMPICH.sh -p trylock -s -b`
   
3.  Install MPICH with per-vci handoff critical sections from github 3.3.x branch with source replace from `./dev` directory
  
  `sh installMPICH.sh -p handoff -b 3.3.x -r`
  

Usage: `sh installMpich.sh [Build Option] [Ad Options]`

Build MPICH option:

	-g - global critical sections
	-p [trylock, handoff] - per-vci critical section
	-d - only download and unpack $CURRENT_MPICH_NAME from \"https://www.mpich.org/\"
	
Additional Options:

	-s - skip manual input [auto launching of: remove previous build, configure dirs, `make && make install`] 
	-r - replace sources from `./dev` directory (sources must be in the same directory path relative to `./dev` as for MPICH)
	-b [branch] - clone mpich sources from github pmodels/mpich default branch is master "https://github.com/pmodels/mpich"
	-i [yourPath] - additional installation path suffix to `$INSTALLATION_PATH_PREFIX/{yourPath}/`
	-o - optimized installation build
	-h - show this message
	-l [logfile path] - MPICH configure and install logs will be print into this file it is installationLogs.txt by default
