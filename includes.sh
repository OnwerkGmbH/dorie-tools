#!/usr/bin/env bash

# Use like this:
# isHgRepo
# hgThere=$?
function isHgRepo() {
    if [ ! -z `hg branch 2> /dev/null` ]
    then
        return 1;
    else
        return 0;
    fi
}

function isGitRepo() {
    if [ ! -z `git rev-parse --is-inside-work-tree 2> /dev/null` ]
    then
        return 1;
    else
        return 0;
    fi
}

# revision=$(getRevisionNumber) or revision=`getRevisionNumber`
# echo $revision
function getRevisionNumber() {
    pushd "`dirname $0`" > /dev/null

    isHgRepo
    hgThere=$?

    isGitRepo
    gitThere=$?

    if [ $hgThere = 1 ]
    then
        echo "`hg log -l 1 -r . --template "{rev}\n"`"
    else
        if [ $gitThere = 1 ]
        then
            echo "`git log --pretty=format:%h -n 1`"
        fi
    fi

    popd > /dev/null
}

# branchName=$(getBranchName) or branchName=`getBranchName`
# echo $branchName
function getBranchName() {
    isHgRepo
    hgThere=$?

    isGitRepo
    gitThere=$?

    if [ $hgThere = 1 ]
    then
        echo "`hg branch`"
    else
        if [ $gitThere = 1 ]
        then
            echo "`git rev-parse --abbrev-ref HEAD 2>/dev/null`"
        fi
    fi
}

function showVersion() {
    versionInfo=$(getRevisionNumber)

    if [ -n "$versionInfo" ]
    then
        versionInfo=" revision $versionInfo"
    fi

    echo "`basename "$0"`, Dorie Tools$versionInfo"
}

function loadDefaults() {
    defaultFileName="dorie.default"

    defaultsFile="$HOME/$defaultFileName"
    if [ -e $defaultsFile ]
    then
        echo "Using defaults from $defaultsFile"
        source $defaultsFile
    fi

    # include any existing local file, overriding the previous defaults
    defaultsFile="./$defaultFileName"
    if [ -e $defaultsFile ]
    then
        echo "Using defaults from $defaultsFile"
        source $defaultsFile
    fi
}

prefix=""
registry=""
ssh_login=""
profile=""

deployitemsdir="deployment_items"
