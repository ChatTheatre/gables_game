#!/bin/bash

set -e

# cd to the gables_game root directory and set it as GAME_ROOT
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $SCRIPT_DIR
cd ../..
export GAME_ROOT="$(pwd)"

tail -f $GAME_ROOT/log/dgd_server.out $GAME_ROOT/log/wafer_log.txt
