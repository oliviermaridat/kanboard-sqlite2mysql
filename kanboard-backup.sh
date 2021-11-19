#!/usr/bin/env bash

readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARGS="$@"

usage()
{
	cat <<- EOF
	usage: $PROGNAME <Kanboard instance physical path> [ --help ]

	 -h, --help	Display this help
	 -v, --version	Display the Kanboard backup version

	Example: $PROGNAME /usr/local/share/www/kanboard
	EOF
}

version()
{
	cat <<- EOF
	Kanboard backup 1.1.2
	Backup your Kanboard in one go! By Olivier.
	EOF
}

cmdline() {
  KANBOARD_PATH=
  if [ "$#" -lt "1" ]; then
    echo 'error: missing arguments'
    usage
    exit -1
  fi
  while [ "$1" != "" ]; do
  case $1 in
    -h | --help )
      usage
      exit 0
      ;;
    -v | --version )
      version
      exit 0
      ;;
    *)
      if [ "$KANBOARD_PATH" == ""  ]; then
        if [ ! -d "$1" ]; then
          echo "error: unknown path '$1'"
          usage
          exit -1
        fi
        KANBOARD_PATH=$1
        shift
      else
        echo "error: unknwon argument '$1'"
        usage
        exit -1
      fi
      ;;
  esac
  done
  return 0
}

backup()
{
  local kanboardPath=$1
  local backupFile=`date +"%Y-%m-%d"`_kanboard.zip
  local logFile=`date +"%Y-%m-%d"`_kanboard-backup.log
  if [ -f "$backupFile" ]; then
      rm $backupFile
  fi

  zip $backupFile -r ${kanboardPath} -x *vendor* -x *.git* \
    > ${logFile} 2>&1
    
}

main() {
    cmdline $ARGS
    echo '# Kanboard backup in progress...'
    backup $KANBOARD_PATH \
      && echo 'done' \
      || echo 'FAILLURE'
}
main
