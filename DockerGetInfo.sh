#!/usr/bin/env bash

h="\n"
h+="`basename "$0"`: Extracts the docker image URL or the created tag from a docker-compose.override.yml file created by DockerBuild.sh\n"
h+="\n"
h+="Command line parameters:\n"
h+="--dockercomposefile: The docker-compose.override.yml file to extract the image URL from\n"
h+="--image:             Specifies that the image url should be retrieved, this is the default\n"
h+="--tag:               Specifies that the created tag should be retrieved\n"
h+="\n"
h+="Example:\n"
h+="./DockerGetImageUrl.sh --dockercomposefile build/docker-compose.override.yml\n"

source "`dirname $0`/includes.sh"

function showHelp() {
    showVersion

    echo -e "$h"
}

dockercomposefile=''
infotype='image'

# get argument data
while([ $# -gt 0 ])
do
    key="$1"
    case $key in
        --dockercomposefile)
        dockercomposefile=$2
        shift
        ;;
        --image)
        infotype='image'
        shift
        ;;
        --tag)
        infotype='tag'
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

if [ -z $dockercomposefile ]
then
    echo "No dockercomposefile given"

    exit -1
fi

if [ -z $infotype ]
then
    echo "Please specify which information you want: --image / --tag"

    exit -1
fi

if [ $infotype == "image" ]
then
    grep -Po "(?<=# DORIETOOLS_CREATED_IMAGE:).*" $dockercomposefile
else
    if [ $infotype == "tag" ]
    then
        grep -Po "(?<=# DORIETOOLS_CREATED_TAG:).*" $dockercomposefile
    else
        echo "Please specify which information you want: --image / --tag"

        exit -1
    fi
fi
