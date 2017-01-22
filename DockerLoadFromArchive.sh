#!/usr/bin/env bash

h="\n"
h+="`basename "$0"`: Extracts an archived docker image (created by DockerPackImage.sh) and loads it back into docker\n"
h+="\n"
h+="Command line parameters:\n"
h+="--zip:     The archive file name to load the docker image from\n"
h+="\n"
h+="Sample:\n"
h+="./DockerLoadFromArchive.sh --zip project.tar.gz\n"

source "`dirname $0`/includes.sh"

showVersion

loadDefaults

function showHelp() {
    echo -e "$h"
}

zipfilename=''

# get argument data
while([ $# -gt 0 ])
do
    key="$1"
    case $key in
        --zip)
        zipfilename="$2"
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

echo "Loading $zipfilename into Docker..."

gunzip -c $zipfilename | docker load

if [ ! $? -eq 0 ]
then
    echo "Failed"

    exit -1
else
    echo "Done."
fi
