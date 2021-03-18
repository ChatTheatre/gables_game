#!/bin/bash

set -e
set -x

cd /var/game

if [ -f no_restart.txt ]
then
	echo "File no_restart.txt found - not starting DGD server."
	exit
fi

if [ -f skotos.database ]
then
    SKOTOS_CMD="/var/dgd/bin/dgd dgd.config skotos.database"
else
    SKOTOS_CMD="/var/dgd/bin/dgd dgd.config"
fi

if ps aux | grep "/var/dgd/bin/dgd dgd.config" | grep -v grep
then
	echo "DGD server is already running"
else
	echo "DGD server is not running - restarting"
	$SKOTOS_CMD >>/var/log/dgd/server.out 2>&1 &
fi
