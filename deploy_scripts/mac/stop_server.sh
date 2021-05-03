#!/bin/bash

set -e
set -x

# This is the place to shut down any extra processes we start up for our specific
# SkotOS-based game. It will also call the shared startup script to shut down
# the SkotOS pieces like Wafer.

# cd to the SkotOS root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $SCRIPT_DIR
cd ../..
export GAME_ROOT="$(pwd)"

SKOTOS_DIR="$GAME_ROOT/.repos/SkotOS"

# This will stop all the non-DGD processes (e.g. relays, Wafer) and *might* stop
# DGD as well. However, to be sure we should shut down DGD ourselves.
$SKOTOS_DIR/deploy_scripts/mac_setup/stop_server.sh

DGD_PID=$(pgrep -f "dgd ./dgd.config") || echo "DGD not running, which is fine"
if [ -z "$DGD_PID" ]
then
    echo "DGD was not running."
else
    kill "$DGD_PID"
    echo "Waiting for DGD to die before killing with -9"
    sleep 5
    kill -9 "$DGD_PID" || echo "DGD had already stopped."
fi
