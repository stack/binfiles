#!/bin/bash

function announce {
    bold=$(tput bold)
    normal=$(tput sgr0)

    echo
    echo "${bold}${1}${normal}"
    echo
}

function exists {
    command -v $1 >/dev/null 2>&1
    return $?
}

# Linux-specific
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    if [[ $(exists apt) -eq 0 ]]; then
        announce "🔮 Upgrading Apt"

        sudo apt update
        sudo apt upgrade
        sudo apt autoremove
    elif [[ $(exists apt-get) -eq 0 ]]; then
        announce "🔮 Upgrading Apt Get"

        sudo apt-get update
        sudo apt-get upgrade
        sudo apt-get autoremove
    fi
fi

# Homebrew (macOS)
if [[ $(exists brew) -eq 0 ]]; then
    announce "🍺 Upgrading Homebrew"

    brew update
    brew upgrade
    brew cask upgrade
    brew cleanup
fi

# Ruby Gems
if [[ $(exists gem) -eq 0 ]]; then
    announce "💎 Upgrading Ruby Gems"

    gem update --system
    gem update
fi

# Rust
if [[ $(exists rustup) -eq 0 ]]; then
    announce "🔨 Upgrading Rust"

    rustup self update
    rustup update
fi

