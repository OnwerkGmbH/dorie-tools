#!/usr/bin/env bash

h="\n"
h+="`basename "$0"`: Pulls a docker image from docker registry and saves the image into a zipped file\n"
h+="\n"
h+="Command line parameters:\n"
h+="--image:   The image to pull and pack, i.e. dockerregistry:5000/customername/awesomeproject:20160917_build48_develop\n"
h+="--zip:     The archive file name to create\n"
h+="--skippull: Skips the pulling of an image before packing, i.g. if no docker registry is used\n"
h+="           Image must exist locally"
h+="\n"
h+="Sample:\n"
h+="./DockerPackImage.sh --image dockerregistry:5000/customername/awesomeproject:20160917_build48_develop --zip awesomeproject.tar.gz\n"

source "`dirname $0`/includes.sh"

showVersion

loadDefaults

function showHelp() {
    echo -e "$h"
}

imagename=''
zipfilename=''
skip_pull=false

# get argument data
while([ $# -gt 0 ])
do
    key="$1"
    case $key in
        --image)
        imagename="$2"
        shift
        ;;
        --zip)
        zipfilename="$2"
        shift
        ;;
        --skippull)
        skip_pull=true
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

if [ -z $imagename ]
then
  echo "No image name, quitting"

  exit -1
fi

if [ -z $zipfilename ]
then
  echo "No zip file name, quitting"

  exit -1
fi

if [ $skip_pull = true ];
then
    echo "Skipping pull from docker registry, image must exist locally"
else
    echo "Pulling image $imagename"
    docker pull $imagename
fi

if [ ! $? -eq 0 ]
then
    exit -1
fi

echo "Saving image $imagename to $zipfilename"
docker save $imagename | gzip > $zipfilename

if [ ! $? -eq 0 ]
then
    exit -1
fi
