#!/bin/bash

function announce {
    bold=$(tput bold)
    normal=$(tput sgr0)

    echo
    echo "${bold}${1}${normal}"
    echo
}

function command_exists {
    command -v $1 >/dev/null 2>&1
    return $?
}

# Linux-specific
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    if command_exists apt; then
        announce "🔮 Upgrading Apt"

        sudo apt update
        sudo apt upgrade
        sudo apt autoremove
    elif command_exists apt-get; then
        announce "🔮 Upgrading Apt Get"

        sudo apt-get update
        sudo apt-get upgrade
        sudo apt-get autoremove
    fi
fi

# Homebrew (macOS)
if command_exists brew; then
    announce "🍺 Upgrading Homebrew"

    brew update
    brew upgrade
    brew cask upgrade
    brew cleanup
fi

# Ruby Gems
if command_exists gem; then
    announce "💎 Upgrading Ruby Gems"

    gem update --system
    gem update
fi

# Rust
if command_exists rustup; then
    announce "🔨 Upgrading Rust"

    rustup self update
    rustup update
fi

