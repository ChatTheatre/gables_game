#!/bin/bash

set -e
set -x

# cd to the Gables root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $SCRIPT_DIR
cd ../..
export GAME_ROOT="$(pwd)"
SKOTOS_DIR="$HOME/.dgd-tools/git/https:__github.com_ChatTheatre_SkotOS.git"

# You know what's easy to do accidentally? Not update.
dgd-manifest update

"$SKOTOS_DIR/deploy_scripts/mac_setup/prestart_no_server.sh"

DGD_PID=$(pgrep -f "dgd ./dgd.config") || echo "DGD not yet running, which is fine"
if [ -z "$DGD_PID" ]
then
    if [ -f skotos.database ]
    then
        echo "Hot-booting DGD from existing statedump..."
        dgd/bin/dgd ./dgd.config skotos.database >log/dgd_server.out 2>&1 &
    else
        echo "Cold-booting DGD with no statedump..."
        dgd/bin/dgd ./dgd.config >log/dgd_server.out 2>&1 &
    fi
else
    echo "DGD is already running! We'll let it keep doing that."
fi

# Open iTerm/terminal window showing DGD process log
$SKOTOS_DIR/deploy_scripts/mac/new_terminal.sh "$GAME_ROOT/deploy_scripts/mac/show_dgd_logs.sh"

# Wait until SkotOS is booted and responsive, start auth server
"$SKOTOS_DIR/deploy_scripts/mac_setup/poststart_no_server.sh"

# For now just show the SkotOS post-install instructions."
cat "$SKOTOS_DIR/deploy_scripts/mac_setup/post_install_instructions.txt"

open -a "Google Chrome" "http://localhost:2072/"

# If uncommented, this will open an iTerm/Terminal window to the Wiztool
#open -a Terminal -n "telnet localhost 10098"
