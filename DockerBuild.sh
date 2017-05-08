#!/bin/bash

h="\n"
h+="`basename "$0"`: Builds a docker image, tags it automatically based on (Jenkins) job information and pushes it to the docker registry\n"
h+="\n"
h+="Command line parameters\n"
h+="--prefix:  The prefix to use in the registry url, i.e. dockerregistry:5000/<prefix>/nameofimage\n"
h+="           Default can be set via dorie.default file\n"
h+="--name:    The name to use in the registry url, i.e. dockerregistry:5000/<prefix>/<name>\n"
h+="           Default: Env variable JOBNAME or directory\n"
h+="--dockerfile: The dockerfile to build\n"
h+="           Default: .\n"
h+="--dockercomposefile: create a docker compose override file, use docker-compose.override.yml for automatic use by docker-compose, otherwise use docker-compose with -f.\n"
h+="           --dockercomposeservicename must also be specified\n"
h+="--tag:     Additional tag for the new image, can be used more than once\n"
h+="--dockercomposeservicename: the service name to extend. Must be given when dockercomposefile is used\n"
h+="--skippush: Skips the pushing of a newly generated image, i.g. if no docker registry is used\n"
h+="\n"
h+="Example:\n"
h+="./DockerBuild.sh --name awesomeproject --tag additionaltag1 --dockercomposefile build/docker-compose.override.yml --dockercomposeservicename webapp\n"
h+="\n"
h+="Later DockerPullRun.sh can be used to start the container:\n"
h+="./DockerPullRun.sh --login core@testserver --profile testserver --copy build\n"

source "`dirname $0`/includes.sh"

showVersion

loadDefaults

function showHelp() {
    echo -e "$h"
}

######################################################################
# get/generate data
######################################################################

# using from loaded config
# prefix=
# registry=

name="$JOB_NAME"
dockerfile=.
dockercomposefile=''
dockercomposeservicename=''

default_image_tag=""
image_tags=()
skip_push=false

# get argument data
while([ $# -gt 0 ])
do
    key="$1"
    case $key in
        --prefix)
        prefix="$2"
        shift
        ;;
        --name)
        name="$2"
        shift
        ;;
        --dockerfile)
        dockerfile="$2"
        shift
        ;;
        --tag)
        image_tags+=($2)
        shift
        ;;
        --dockercomposefile)
        dockercomposefile=$2
        shift
        ;;
        --dockercomposeservicename)
        dockercomposeservicename=$2
        shift
        ;;
        --skippush)
        skip_push=true       
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

if [ -z $name ]
then
    name=${PWD##*/}
    echo "No name given or in JOB_NAME env variable, creating from directory: $name"
fi

if [ -z $name ]
then
    echo "No name, quitting."

    exit -1
fi

if [[ $name =~ ^.*[_].*$ ]]; then
    echo "Invalid characters in name detected, Docker doesn't like this...: $name"

    exit -1
fi

# generate docker registry url

if [ $skip_push = true ]; then
   dockerimageurl="$name"
else
    if [ -z $registry ]; then
        echo "No registry url given, quitting."

        exit -1
    fi

    if [ -z $prefix ] || [ "$prefix" == "" ]; then
        dockerimageurl="$registry/$name"
    else
        echo "prefix"
        dockerimageurl="$registry/$prefix/$name"
    fi
fi

# lowercase everything, docker does not like uppercase image names/urls
dockerimageurl="${dockerimageurl,,}"
echo "Creating image: $dockerimageurl"

# retrieve current branch name
branchName=$(getBranchName)
if [ "$?" -eq 0 ]
  then
    echo "Working on branch: '$branchName'"
  else
    echo "ERROR: There was an error getting branch name from VCS"

    exit -1
fi

# create build version tag
if [ -z $BUILD_NUMBER ]
then
    echo "No build info: BUILD_NUMBER not set"
else
    build="build$BUILD_NUMBER"
    date=`date +%Y%m%d`

    # Bash String manipulation
    # Substring Replacement
    # http://tldp.org/LDP/abs/html/string-manipulation.html
    # replace / with -
    branchName=${branchName/"/"/"-"}
    # replace _ with -
    branchName=${branchName/"_"/"-"}
    # replace # with -
    branchName=${branchName/"#"/"-"}

    branchName=${branchName/"--"/"-"}

    buildversion_tag="$date"_"$build"

    if [ ! -z $branchName ] && [ ! "$branchName" == "" ]; then
        buildversion_tag=$buildversion_tag"_$branchName"
    fi

    image_tags+=($buildversion_tag)
    default_image_tag=$buildversion_tag

    echo "Using tag generated from build version: $buildversion_tag"
fi

case "$branchName" in
    *develop*)
    echo "\"Develop\" branch detected, using additional tags \"develop\""
    image_tags+=('develop')
    ;;
    *default*)
    echo "\"Default\" branch detected, using additional tag \"default\""
    image_tags+=('default')
    ;;
    *master*)
    echo "\"master\" branch detected, using additional tag \"master\""
    image_tags+=('master')
    ;;
    *)
    echo "No develop or default/master branch detected ('$branchName'), no additional tags"
    ;;
esac

build_args=""

for image_tag in ${image_tags[@]}; do
    echo "Using tag: ${image_tag}"
    build_args="$build_args -t $dockerimageurl:${image_tag}"
    if [ -z $default_image_tag ]
    then
        default_image_tag=${image_tag}
    fi
done

# building docker image
if [ -z "$build_args" ]
then
    echo "Could not auto-determine any tags for image, use --tag to specify a tag manually"

    exit -1
fi

echo "Using default image tag: $default_image_tag"

# get old image tags with :develop and :default
echo 'Untag old images with the develop or default tag'
old_images=$(docker images $dockerimageurl | awk -v image="$dockerimageurl" 'NR > 1{print image":"$2}' | awk '$1 !~ /develop|default/')
if ([ ! -z "$old_images" ]);then
    docker rmi $old_images
else
    echo 'No old images with default tag found'
fi

echo 'Removing dangling images'
dangling=$(docker images -f "dangling=true" -q)
if ([ ! -z "$dangling" ]);then
    docker rmi $dangling
else
    echo 'No dangling images found'
fi

echo

echo "Building docker image from dockerfile \"$dockerfile\" with arguments: \"$build_args\""
echo "docker build $build_args $dockerfile"
docker build $build_args $dockerfile

if [ $? -eq 0 ]
then
    echo "Docker build successfully"
else
    echo "Docker build failed" >&2

    exit -1
fi

echo

# display layer size
echo "Layer overview:"
docker history $dockerimageurl:$default_image_tag

echo

if [ $skip_push = true ];
then
    echo "Skipping push to docker registry"
else
    # pushing to registry
    echo "Pushing new docker image to repository $registry"
    docker push $dockerimageurl:$default_image_tag

    if [ $? -eq 0 ]
    then
        echo "Image successfully pushed"
    else
        echo "Pushing of image failed" >&2

        exit -1
    fi
fi

echo

if [ ! -z "$dockercomposefile" ]
then
    if [ -z $dockercomposeservicename ]
    then
        echo "Docker-Compose file should be created but dockercomposeservicename is not given, failing"

        exit -1
    fi

    echo "Creating docker-compose file $dockercomposefile:"

    rm -f $dockercomposefile

    if [ ! $? -eq 0 ]
    then
        exit -1
    fi

    dir=$(dirname "${dockercomposefile}")

    if [ ! -z "$dir" ]
    then
        mkdir -p $dir
    fi

    rm -rf $dockercomposefile

    versionString=$(showVersion)

    echo "# " >> $dockercomposefile
    echo "# Created by $versionString" >> $dockercomposefile
    echo "# " >> $dockercomposefile
    echo "# DORIETOOLS_CREATED_TAG:$default_image_tag" >> $dockercomposefile
    echo "# DORIETOOLS_CREATED_IMAGE:$dockerimageurl:$default_image_tag" >> $dockercomposefile
    echo "# " >> $dockercomposefile
    echo "" >> $dockercomposefile
    echo "version: '2'" >> $dockercomposefile
    echo "services:" >> $dockercomposefile
    if [ ! $? -eq 0 ]
    then
        exit -1
    fi

    echo "    $dockercomposeservicename:" >> $dockercomposefile
    echo "        image: $dockerimageurl:$default_image_tag" >> $dockercomposefile
    echo ">>>>"
    cat $dockercomposefile
    if [ ! $? -eq 0 ]
    then
        exit -1
    fi

    echo "<<<<"

    echo
fi

echo "Docker image created, use $dockerimageurl:$default_image_tag to reference it"

export DORIETOOLS_CREATED_TAG=$default_image_tag
export DORIETOOLS_CREATED_IMAGE=$dockerimageurl:$default_image_tag
