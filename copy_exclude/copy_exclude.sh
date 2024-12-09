#!/bin/bash

# copy_exclude.sh

################################################################################
# MIT License
#
# Copyright (c) 2024-2025 Zartaj Majeed
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
################################################################################

set -o noglob

function usage {
  echo "Usage: copy_exclude.sh [-f copy_function] [-l] [-t] [-x exclude_glob_pattern] [-h] src dest"
  echo "Copy directory with option to exclude files and directories by pattern, file and directory paths cannot have spaces or special characters, use [[:space:]] in patterns"
  echo
  echo "-f copy_function: use copy_function to perform copy, default rsync_exclude"
  echo "-l: list copy_function names"
  echo "-x glob_pattern: exclude files and directories that match glob pattern"
  echo "-h: help"
  echo "src: source directory"
  echo "dest: destination directory"
  echo
  echo "Examples:"
  echo "copy_exclude.sh -x \"*.nocopy*\" srcdir destdir"
}

function doListCopyFuncs {
  IFS=$'\n'
  echo "${copyFuncs[*]}"
}

function rsync_exclude {
  echo "Copy with rsync exclude option"

  rsync -a --exclude "$excludePattern" $srcdir/ $destdir
  echo
}

function rsync_filter {
  echo "Copy with rsync filter option"

  rsync -a --filter "- $excludePattern" $srcdir/ $destdir
  echo
}

function tar_exclude {
  echo "Copy with tar exclude option"

  tar -C $srcdir -c --exclude "$excludePattern" . |
  tar -C $destdir -x
  echo
}

function find_tar {
  echo "Copy with find and tar"
# print source paths stripped of source tree root
  find $srcdir -mindepth 1 -name "$excludePattern" -prune -o -printf "%P\n" |
# tar --no-recursion because all paths are explicitly provided on stdin
  tar -c -C $srcdir --no-recursion -T- |
  tar -x -C $destdir
  echo
}

function find_cp {
  echo "Copy with find and cp on each file and directory"
# no find action taken for directories and files that match exclude pattern
# non-excluded files and directories are copied with inline script in find
# inline script takes 3 arguments, source tree to copy from, source path to copy, destination tree to copy to
# cannot use find -execdir instead of -exec because {} for -execdir is just file or directory name without path from source root needed to create same structure in destination tree
  find $srcdir -mindepth 1 -name "$excludePattern" -prune -o -exec bash -c '
# inline script to copy each file and directory from source tree to destination tree
    srcroot=$1
    srcpath=$2
# need absolute path to destination tree for copy to work from different directory
    destroot=$(realpath $3)
# strip source root from source path to get relative path to copy to destination tree
    relsrc=${srcpath#$srcroot/}

    if [[ -d $srcpath ]]; then
# create empty directory in destination tree
      shopt -s nullglob
      declare -a contents=($srcpath/*)
      [[ -z $contents ]] && mkdir $destroot/$relsrc
    else
# copy files creating intermediate directories in destination tree
      cd $srcroot &&
      cp --parents $relsrc $destroot
    fi
  ' findexec $srcdir {} $destdir \;
  echo
}

function find_cp_collect {
  echo "Copy with find and cp on collected files and directories"
# no find action taken for directories and files that match exclude pattern
# non-excluded files and directories are copied with separate inline scripts in find
# inline scripts take 3 arguments, source tree to copy from, destination tree to copy to, source path to copy
  find $srcdir -mindepth 1 -name "$excludePattern" -prune -o -type d -empty -exec bash -c '
# inline script to create all empty directories in destination tree
    srcroot=$1
    destroot=$2
    declare -a srcdirs=(${@:3})
# replace source root with destination root in each source path
    declare -a destdirs=(${srcdirs[*]/#$srcroot/$destroot})

# create all empty directories with single mkdir
    mkdir ${destdirs[*]}

  ' findexecplus $srcdir $destdir {} + -o -type f -exec bash -c '
# inline script to copy all files from source tree to destination tree
    srcroot=$1
# need absolute path to destination tree for copy to work from different directory
    destroot=$(realpath $2)
    declare -a srcfiles=(${@:3})
# strip source root from source path to get relative path to copy to destination tree
    declare -a relsrcs=(${srcfiles[*]/#$srcroot\//})

    cd $srcroot
# copy all files with single cp
    cp --parents ${relsrcs[*]} $destroot

  ' findexecplus $srcdir $destdir {} +
  echo
}

declare -a copyFuncs=(
  rsync_exclude
  rsync_filter
  tar_exclude
  find_tar
  find_cp
  find_cp_collect
)

while getopts "f:hlx:" opt; do
  case $opt in
    f)
      copyFunc=$OPTARG
      ;;
    l)
      listCopyFuncs=true
      ;;
    x)
      excludePattern=$OPTARG
      ;;
    h) usage; exit 0
      ;;
    *) usage; exit 1
  esac
done
shift $((OPTIND - 1))

: ${copyFunc:=rsync_exclude}
: ${listCopyFuncs:=false}

if $listCopyFuncs; then
  doListCopyFuncs
  exit
fi

if (($# != 2)); then
  usage
  exit 1
fi

srcdir=$1
destdir=$2

if [[ ! -d $srcdir || ! -d $destdir ]]; then
  echo >&2 "Source directory $srcdir or destination directory $destdir does not exist"
  exit 1
fi

if [[ -n $(find $destdir -maxdepth 0 ! -empty) ]]; then
  echo >&2 "Error: Destination directory $destdir is not empty"
  exit 1
fi

echo "Copy source directory tree $srcdir to destination directory $destdir, exclude files that match pattern \"$excludePattern\""

$copyFunc

