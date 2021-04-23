#!/bin/bash

set -e
set -x

DGD_PID=$(pgrep -f "dgd ./dgd.config") || echo "DGD not running, which is fine."
if [ -z "$DGD_PID" ]
then
    echo "DGD does not appear to be running. Good."
else
    echo "DGD appears to be running The Gables already with PID ${DGD_PID}. Shut down this copy of DGD with deploy_scripts/mac/stop_server.sh before messing with the install."
    exit -1
fi

# cd to the SkotOS root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $SCRIPT_DIR
cd ../..
export GAME_ROOT="$(pwd)"

RUBY=`which ruby`
if [ -z "$RUBY" ]
then
    echo "You don't seem to have Ruby installed! How odd. Usually MacOS installs Ruby by default."
    echo "You can fix this by installing Ruby with a package manager (e.g. https://brew.sh) or Ruby version manager (e.g. https://rvm.io)."
    exit -1
fi

GEM=`which gem`
if [ -z "$GEM" ]
then
    echo "You don't seem to have Ruby's 'gem' command installed! Usually MacOS installs Ruby and 'gem' by default."
    echo "You can fix this by installing Ruby with a package manager (e.g. https://brew.sh) or Ruby version manager (e.g. https://rvm.io)."
    exit -1
fi

BUNDLE=`which bundle`
if [ -z "$BUNDLE" ]
then
    echo "Installing Bundler for Ruby..."
    gem install bundler
fi

TOOLS=`gem list --local dgd-tools`
if [ -z "$TOOLS" ]
then
    echo "Installing dgd-tools Ruby gem, which can take a bit of time..."
    gem install dgd-tools
fi

# Make sure we've cloned the SkotOS repo via dgd-tools, and that the DGD root dir is
# built, and that there's a config file available. We do an 'update' in case there
# are local modifications we'd rather not lose. "dgd-manifest install" will usually
# blow those away.
dgd-manifest update

#SKOTOS_DIR="~/.dgd-tools/git/https\:__github.com_ChatTheatre_SkotOS.git"

# This assumes GAME_ROOT is set to clone all the appropriate repos locally.
#"$SKOTOS_DIR/deploy_scripts/mac_setup/setup_no_server.sh"
"$HOME/.dgd-tools/git/https:__github.com_ChatTheatre_SkotOS.git/deploy_scripts/mac_setup/setup_no_server.sh"

# We did setup. Now, for startup.
./deploy_scripts/mac/start_server.sh
