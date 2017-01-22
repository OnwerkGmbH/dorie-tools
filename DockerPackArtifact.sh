#!/usr/bin/env bash

h="\n"
h+="`basename "$0"`: Collects all deployment items and saves them into into a zipped file.\n"
h+="\n"
h+="Command line parameters:\n"
h+="--profile:    The profile to use, specifies the subdirectory under deployment_items to copy\n"
h+="              Default can be set via dorie.default file\n"
h+="--deployitemsdir: The directory that is copied to the remote server\n"
h+="              Default: 'deployment_items'\n"
h+="--copy:       one or more directories to be included into the archive as well\n"
h+="--targetdir   The directory the artifact is saved to\n"
h+="              Default: './'\n"
h+="--tmpdir      Temporary directory used to collect deployment items\n"
h+="              Default: './tmp/'\n"
h+="--zip         The archive file name to create\n"
h+="              Default: 'deploy_{profile}.zip'\n"
h+="\n"
h+="Sample:\n"
h+="./DockerPackArtifact .sh --profile testserver --targetdir ./myArtifact s --zip testserver-deployment.zip\n"


source "`dirname $0`/includes.sh"

showVersion

loadDefaults

function showHelp() {
    echo -e "$h"
}

targetdir='./'
tmpdir='./tmp/'
zipfilename=""
additionalcopydirs=()

# get argument data
while([ $# -gt 0 ])
do
    key="$1"
    case $key in
        --profile)
        profile="$2"
        shift
        ;;
        --deployitemsdir)
        deployitemsdir="$2"
        shift
        ;;
        --copy)
        additionalcopydirs+=($2)
        shift
        ;;
        --targetdir)
        targetdir="$2"
        shift
        ;;
        --tmpdir)
        tmpdir="$2"
        shift
        ;;
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

if [ -z $profile ]
then
    echo "No profile set, quitting"

    exit -1
fi

if [ -z $zipfilename ]
then
    zipfilename="deploy_$profile.zip"
fi

if [ ! -d "deployment_items/$profile" ]
then
    echo "No matching directory for \"$profile\" found in deployment_items, quitting"

    exit -1
fi

mkdir -p "$tmpdir"

if [ -d "$deployitemsdir/all" ]; then
    cp -R $deployitemsdir/all/. $tmpdir
    if [ ! $? -eq 0 ]
    then
        echo "Failed" >&2

        exit -1
    fi
fi

if [ -d "$deployitemsdir/$profile" ]; then
    echo "Adding deployment items from $deployitemsdir/$profile"
    cp -R $deployitemsdir/$profile/. $tmpdir
    if [ ! $? -eq 0 ]
    then
        echo "Failed" >&2

        exit -1
    fi
fi

for additionalcopydir in ${additionalcopydirs[@]}; do
    echo "Adding additional deployment items from $additionalcopydir"
    cp -R $additionalcopydir/. $tmpdir
    if [ ! $? -eq 0 ]
    then
        echo "Failed" >&2

        exit -1
    fi
done

if [ ! $? -eq 0 ]; then
    echo "Failed to copy deployment items. Removing temporary folder."
    rm -r "$tmpdir"

    exit -1
fi

echo "Creating artifact file"

# create artifact in tmpdir to prevent unwanted subfolders in zip
pushd "$tmpdir"
zip -r "$zipfilename" .

if [ ! $? -eq 0 ]; then
    echo "Failed to zip temp folder, leaving folder for inspection."

    exit -1
fi

popd

mkdir -p "$targetdir"
mv "$tmpdir/$zipfilename" "$targetdir"

rm -r "$tmpdir"

echo "Artifact file $zipfilename created"