#!/bin/bash

# Globals & Constants
REPOSITORY_PATH=/tmp/vim.git

# Ensure all dependencies exist
sudo apt-get build-dep vim-gtk3 -y

# Clean up any existing downloads
if [ -d ${REPOSITORY_PATH} ]; then
    echo "Removing existing repository"
    rm -rf ${REPOSITORY_PATH}
fi

# Check out a clean repository
git clone https://github.com/vim/vim.git ${REPOSITORY_PATH}

if [ $? -ne 0 ]; then
    echo "Failed to clone vim repository"
    exit 1
fi

# Enter the repository
pushd ${REPOSITORY_PATH}

# Find the latest tag
LATEST_TAG=`git tag | grep ^v | sort | tail -n1`

echo "Building ${LATEST_TAG}"
git checkout ${LATEST_TAG}

# If rbenv is installed, make it use the system ruby for compile
type rbenv

if [ $? -eq 0 ]; then
    echo "Setting local rbenv to system"
    rbenv local system
fi

# Conigure the build
./configure --prefix=/usr/local \
    --with-features=huge        \
    --enable-multibyte          \
    --enable-gui=gtk3           \
    --enable-luainterp          \
    --enable-perlinterp         \
    --enable-pythoninterp       \
    --enable-python3interp      \
    --enable-tclinterp          \
    --enable-rubyinterp

if [ $? -ne 0 ]; then
    echo "Failed to configure the build"
    exit 1
fi

# Get the number of processors available for the compile
NUMBER_OF_PROCESSORS=`getconf _NPROCESSORS_ONLN`

if [ $? -ne 0 ]; then
    NUMBER_OF_PROCESSORS=1
fi

echo "Using ${NUMBER_OF_PROCESSORS} processor(s)"

# Make and install
make -j${NUMBER_OF_PROCESSORS}

if [ $? -ne 0 ]; then
    echo "Failed to make vim"
    exit 1
fi

sudo make install

if [ $? -ne 0 ]; then
    echo "Failed to install vim"
    exit 1
fi

# TODO: Add this version of vim to the alternatives system

# Leave the repository
popd
