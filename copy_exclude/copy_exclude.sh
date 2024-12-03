#!/bin/bash

# copy_exclude.sh

function usage {
  echo "Usage: copy_exclude.sh [-f copy_function] [-t] [-h] [-x glob_pattern] src dest"
  echo "Copy directory with option to exclude files and directories by pattern"
  echo
  echo "-f copy_function: use copy_function to perform copy"
  echo "-l: list copy_function names"
  echo "-x glob_pattern: exclude files and directories that match glob pattern"
  echo "-t: create test files and directories to copy"
  echo "-h | --help: help"
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

function doCreateTestData {
  local testdir=testd
  local srcdir=$testdir/srcd
  local destdir=$testdir/destd

  echo "Create test data in directory $testdir"
  mkdir -p $testdir

  echo "Create source directory $srcdir, destination directory $destdir"
  mkdir -p $srcdir $destdir
  echo

  touch $srcdir/file_{1..3}.txt
  touch $srcdir/file_4.nocopy.txt

  mkdir -p $srcdir/dir_1
  touch $srcdir/dir_1/file_{5..7}.txt
  touch $srcdir/dir_1/file_8.nocopy.txt

  mkdir -p $srcdir/dir_1/dir_2.nocopy
  touch $srcdir/dir_1/dir_2.nocopy/file_9.txt

  mkdir -p $srcdir/dir_3

  mkdir -p $srcdir/dir_4.nocopy

  echo "Source directory tree $srcdir"
  ls -lAR --color=always $srcdir |
  grep -E --color=always "|(dir|file)_[0-9]+\.nocopy.*"
  echo

}

function rsync_exclude {
  echo "Copy with rsync exclude option"
  echo "rsync -a --exclude \"$excludePattern\" $srcdir/ $destdir"
  rsync -a --exclude "$excludePattern" $srcdir/ $destdir
  echo
}

function rsync_filter {
  echo "Copy with rsync filter option"
  echo "rsync -a --filter \"- $excludePattern\" $srcdir/ $destdir"
  rsync -a --filter "- $excludePattern" $srcdir/ $destdir
  echo
}

function tar_exclude {
  echo "Copy with tar exclude option"
  echo "tar -C $srcdir -c --exclude \"$excludePattern\" . |"
  echo "tar -C $destdir -x"
  tar -C $srcdir -c --exclude "$excludePattern" . |
  tar -C $destdir -x
  echo
}

function find_cp {
  echo "Copy with find and cp"
  find $srcdir -mindepth 1 -name "$excludePattern" \( -type d -prune -o -true \) -o -exec bash -c '
    srcdir=$1
    srcpath=$2
    destdir=$3
    relsrc=${srcpath#$srcdir/}
# create empty directory in destination tree or copy files creating intermediate directories as needed
    if [[ -d $srcpath ]]; then
      shopt -s nullglob
      declare -a contents=($srcpath/*)
      [[ -z $contents ]] && mkdir $destdir/$relsrc
    else
      cd $srcdir &&
      cp --parents $relsrc $destdir
    fi
  ' find-bash $srcdir {} $(realpath $destdir) \;
  echo
}

function find_tar {
  echo "Copy with find and tar"
  find $srcdir -mindepth 1 -name "$excludePattern" \( -type d -prune -o -true \) -o -printf "%P\n" |
  tar -c -C $srcdir --no-recursion -T- |
  tar -x -C $destdir
  echo
}

declare -a copyFuncs=(
  rsync_exclude
  rsync_filter
  tar_exclude
  find_cp
  find_tar
)

function checkCopy {
echo "Destination directory tree $destdir"
echo
ls -lAR --color=always $destdir |
grep -E --color=always "|(dir|file)_[0-9]+\.nocopy.*"
echo

echo "Diff source and destination directories"
echo
diff -rq $srcdir $destdir
echo
}

while getopts "f:hltx:" opt; do
  case $opt in
    f)
      copyFunc=$OPTARG
      ;;
    l)
      listCopyFuncs=true
      ;;
    t)
      createTestData=true
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

: ${createTestData:=false}
: ${copyFunc:=rsync_exclude}
: ${listCopyFuncs:=false}

if $listCopyFuncs; then
  doListCopyFuncs
  exit
fi

if $createTestData; then
  doCreateTestData
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

checkCopy
