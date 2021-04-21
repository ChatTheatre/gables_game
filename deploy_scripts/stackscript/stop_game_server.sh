#!/bin/bash

set -e
set -x

DGD_PID=$(pgrep -f "/var/dgd/bin/dgd dgd.config")
if [ -z "$DGD_PID" ]
then
    echo "DGD does not appear to be running. Good."
else
    echo "DGD is running with PID ${DGD_PID}. Stopping."
    kill "$DGD_PID"
fi

cat <<EndOfMessage
Remember that DGD may be configured to automatically restart via Cron or similar!
If you want to prevent the start script from restarting DGD, you may want to
touch the file no_restart.txt in the appropriate application directory.
EndOfMessage
