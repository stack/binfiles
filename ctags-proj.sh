#!/bin/bash

if [ -x /usr/local/bin/ctags ]; then
  CTAGS=/usr/local/bin/ctags
else
  CTAGS=`which ctags`
fi

if [ "$CTAGS" = "" ]; then
  echo "Failed to find ctags, abort!"
fi

if [ -f ".gitignore" ]; then
  if [ -f ".srclist" ]; then
    $CTAGS -R --exclude='.git' -L .srclist
  else
    $CTAGS -R --exclude='.git'
  fi
else
  HERE=$PWD
  cd ..
  if [ "$PWD" = "$HERE" ]; then
    echo "Got to /, have not found your project root, abort!"
    exit 1
  fi

  exec "$0"
fi

