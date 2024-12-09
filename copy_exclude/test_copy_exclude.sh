#!/bin/bash

# test_copy_exclude.sh

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

function usage {
  echo "Usage: test_copy_exclude.sh [-c | -C | -p]"
  echo "Create test files and directories for copy_exclude.sh"
  echo
  echo "-c: create test files and directories"
  echo "-C: colorize test filenames read from stdin"
  echo "-p: print test files and directories"
  echo "-h: help"
  echo
  echo "Examples:"
  echo "test_copy_exclude.sh -c"
  echo "test_copy_exclude.sh -p"
  echo "test_copy_exclude.sh -C < <(copy_exclude.sh -x "*.exclude*" testd/srcd testd/destd)"
}

function doCreateTestDir {
  echo "Create test data in $testdir"
  mkdir -p $testdir

  if [[ -n $(ls -A $testdir) ]]; then
    echo >&2 "error: test directory $testdir is not empty, please delete and recreate"
    exit 1
  fi

  mkdir -p $srcdir $destdir

  touch $srcdir/file_1.txt
  touch $srcdir/file_2.exclude.txt

  mkdir -p $srcdir/dir_1
  touch $srcdir/dir_1/file_3.txt
  touch $srcdir/dir_1/file_4.exclude.txt

  mkdir -p $srcdir/dir_1/dir_2.exclude
  touch $srcdir/dir_1/dir_2.exclude/file_5.txt

# create some empty directories
  mkdir -p $srcdir/dir_3
  mkdir -p $srcdir/dir_4.exclude

# write a byte to each file
  find $srcdir -type f -empty -exec bash -c "echo '.' > {}" \;
}

function doPrintTestDir {
  if [[ ! -d $testdir || -z $(ls -A $testdir) ]]; then
    echo "Test directory $testdir is empty or doesn't exist"
    exit 0
  fi
  echo "Test directory tree $testdir"
# passthru ls colors
# exclude pattern bold red \e[1;31m
# \e[m is reset, \x1b is \e for sed
  ls -lAR --color=always $testdir |
  sed -E "
    /(dir|file)_[0-9]+\.exclude.*/s//\x1b[m\x1b[1;31m&\x1b[m/
  "
  echo

}

# colorize test filenames read on stdin
function doColorizeInput {
  sed -E "
    /(dir|file)_[0-9]+\.exclude[a-z0-9_.]*/s//\x1b[m\x1b[1;31m&\x1b[m/g
  "
}

function doCheckCopy {
  echo "Destination directory tree $destdir"
  echo
  ls -lAR --color=always $destdir
  echo

  echo "Diff source and destination directories"
  echo
  diff -rq $srcdir $destdir
  echo
}

testdir=testd
srcdir=$testdir/srcd
destdir=$testdir/destd

while getopts "cChp" opt; do
  case $opt in
    c)
      createTestDir=true
      ;;
    C)
      checkCopy=true
      ;;
    p)
      printTestDir=true
      ;;
    h) usage; exit 0
      ;;
    *) usage; exit 1
  esac
done
shift $((OPTIND - 1))

: ${createTestDir:=false}
: ${printTestDir:=false}
: ${checkCopy:=false}

if $checkCopy; then
  doCheckCopy |
  doColorizeInput

  exit
fi

if $createTestDir; then
  doCreateTestDir
fi

doPrintTestDir

