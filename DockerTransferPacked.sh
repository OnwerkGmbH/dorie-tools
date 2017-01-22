#!/usr/bin/env bash

h="\n"
h+="`basename "$0"`: Transfers an archived docker image (created by DockerPackImage.sh) to a server, extracts it and loads it back into docker\n"
h+="\n"
h+="Command line parameters:\n"
h+="--zip:     The archived docker image file to transfer\n"
h+="--login:   The ssh login to use\n"
h+="           Default can be set via dorie.default file\n"
h+="--targetdir: The target directory on the server, must be given as seen from server (~ will be locally resolved!)\n"
h+="           Default: /containers/<JOBNAME>/\n"
h+="\n"
h+="Example:\n"
h+="./DockerTransferPacked.sh --zip awesomeproject.targ.gz --targetdir /srv/containers/awesomeproject/\n"

source "`dirname $0`/includes.sh"

showVersion

loadDefaults

function showHelp() {
    echo -e "$h"
}

# using from loaded config
# ssh_login=

zipfilename=''
targetdir=''

# get argument data
while([ $# -gt 0 ])
do
    key="$1"
    case $key in
        --zip)
        zipfilename="$2"
        shift
        ;;
        --login)
        ssh_login="$2"
        shift
        ;;
        --targetdir)
        targetdir="$2"
        shift
        ;;
        --help)
        showHelp

        exit 0
        shift
        ;;
        *)
        echo "Unknown argument: $key"

        exit -1
        ;;
    esac
    shift
done


if [ -z $zipfilename ]
then
    echo "No zip file name, quitting"

    exit -1
fi

if [ -z $targetdir ]
then
    if [ -z $JOBNAME ]
    then
      echo "Cannot determine target directory and it is not specified"

      exit -1
    fi

    targetdir="/containers/$JOBNAME/"
fi

if [ -z $ssh_login ]
then
    echo "SSH Login not given, quitting"

    exit -1
fi

echo "Creating target directory $targetdir"
ssh -t -t "$ssh_login" "mkdir -p $targetdir"

if [ ! $? -eq 0 ]
then
    exit -1
fi

echo "Copying zip file $zipfilename to target directory $targetdir"
scp $zipfilename $ssh_login:$targetdir

if [ ! $? -eq 0 ]
then
    exit -1
fi

zipBasename=`basename "$zipfilename"`

sshCommand="gunzip -c $targetdir/$zipBasename | docker load"

echo "SSH Connection to server: running command to load docker container: $sshCommand"
ssh -t -t "$ssh_login" "$sshCommand"

if [ ! $? -eq 0 ]
then
    exit -1
fi
