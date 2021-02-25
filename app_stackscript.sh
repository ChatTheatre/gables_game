#!/bin/bash

# <UDF name="subdomain" label="Subdomain to contain gables and gables-login" example="Example: game.my-domain.com"/>
# SUBDOMAIN=
# <UDF name="userpassword" label="Deployment User Password" example="Password for various accounts and infrastructure." />
# USERPASSWORD=
# <UDF name="game_git_url" label="The Game's Git URL" default="https://github.com/ChatTheatre/gables_game" example="Game Git URL to clone for your game." optional="false" />
# GAME_GIT_URL=
# <UDF name="game_git_branch" label="The Game's Git Branch" default="master" example="Game branch, tag or commit to clone for your game." optional="false" />
# GAME_GIT_BRANCH=
# <UDF name="skotos_stackscript_url" label="URL for the base stackscript to build on" default="https://raw.githubusercontent.com/noahgibbs/SkotOS/dgd_manifest/dev_scripts/stackscript/linode_stackscript.sh" example="SkotOS stackscript to build on top of." optional="false" />
# SKOTOS_STACKSCRIPT_URL=

set -e
set -x

# Output stdout and stderr to ~root files
exec > >(tee -a /root/game_standup.log) 2> >(tee -a /root/game_standup.log /root/game_standup.err >&2)

# e.g. clone_or_update "$SKOTOS_GIT_URL" "$SKOTOS_GIT_BRANCH" "/var/skotos"
function clone_or_update {
  if [ -d "$3" ]
  then
    pushd "$3"
    git fetch # Needed for "git checkout" if the branch has been added recently
    git checkout "$2"
    git pull
    popd
  else
    git clone "$1" "$3"
    pushd "$3"
    git checkout "$2"
    popd
  fi
  chgrp -R skotos "$3"
  chown -R skotos "$3"
  chmod -R g+w "$3"
}

# Parameters to pass to the SkotOS stackscript
export HOSTNAME="gables"
export FQDN_CLIENT=gables."$SUBDOMAIN"
export FQDN_LOGIN=gables-login."$SUBDOMAIN"
export SKOTOS_GIT_URL=https://github.com/noahgibbs/SkotOS
export SKOTOS_GIT_BRANCH=dgd_manifest
export DGD_GIT_URL=https://github.com/ChatTheatre/dgd
export DGD_GIT_BRANCH=master
export THINAUTH_GIT_URL=https://github.com/ChatTheatre/thin-auth
export THINAUTH_GIT_BRANCH=master
export TUNNEL_GIT_URL=https://github.com/ChatTheatre/websocket-to-tcp-tunnel
export TUNNEL_GIT_BRANCH=master

if [ -z "$SKIP_INNER" ]
then
    # Set up the node using the normal SkotOS Linode stackscript
    curl $SKOTOS_STACKSCRIPT_URL > ~root/skotos_stackscript.sh
    NO_DGD_SERVER=true . ~root/skotos_stackscript.sh
fi

clone_or_update "$GAME_GIT_URL" "$GAME_GIT_BRANCH" /var/game

# If we're running on an already-provisioned system, don't keep DGD running
touch /var/game/no_restart.txt
/var/game/scripts/stop_game_server.sh

# Reset the logfile and DGD database
rm -f /var/log/dgd_server.out /var/log/dgd/server.out /var/skotos/skotos.database /var/skotos/skotos.database.old

touch /var/log/start_game_server.sh
chown skotos /var/log/start_game_server.sh

# Replace Crontab with just the pieces we need - specifically, do NOT start the old SkotOS DGD server any more.
cat >>~skotos/crontab.txt <<EndOfMessage
* * * * *  /var/game/scripts/start_game_server.sh >>/var/log/start_game_server.sh
EndOfMessage

# In case we're re-running, don't keep statedump files around
rm -f /var/game/skotos.database*

cat >~skotos/dgd_pre_setup.sh <<EndOfMessage
#!/bin/bash

set -e
set -x

cd /var/game
bundle install
bundle exec dgd-manifest install
EndOfMessage
chmod +x ~skotos/dgd_pre_setup.sh
sudo -u skotos ~skotos/dgd_pre_setup.sh

# We modify files in /var/game/.root after dgd-manifest has created the initial app directory.
# But we also copy those files into /var/game/root (note: no dot) so that if the user later
# rebuilds with dgd-manifest, the modified files will be kept.

# May need this for logging in on telnet port and/or admin-only emergency port
DEVUSERD=/var/game/.root/usr/System/sys/devuserd.c
if grep -F "user_to_hash = ([ ])" $DEVUSERD
then
    # Unpatched - need to patch
    sed -i "s/user_to_hash = (\[ \]);/user_to_hash = ([ \"admin\": to_hex(hash_md5(\"admin\" + \"$USERPASSWORD\")), \"skott\": to_hex(hash_md5(\"skott\" + \"$USERPASSWORD\")) ]);/g" $DEVUSERD
else
    echo "/var/game DevUserD appears to be patched already. Moving on..."
fi
mkdir -p /var/game/root/usr/System/sys
cp $DEVUSERD /var/game/root/usr/System/sys/
chown skotos:skotos /var/game/root/usr/System/sys/devuserd.c

# Fix the login URL
HTTP_FILE=/var/game/.root/usr/HTTP/sys/httpd.c
if grep -F "www.skotos.net/user/login.php" $HTTP_FILE
then
    # Unpatched - need to patch
    sed -i "s_https://www.skotos.net/user/login.php_http://${FQDN_LOGIN}_" $HTTP_FILE
else
    echo "HTTPD appears to be patched already. Moving on..."
fi
mkdir -p /var/game/usr/HTTP/sys
cp $HTTP_FILE /var/game/usr/HTTP/sys/
chown skotos:skotos /var/game/usr/HTTP/sys/httpd.c

# Instance file
cat >/var/game/.root/usr/System/data/instance <<EndOfMessage
portbase 10000
hostname $FQDN_CLIENT
bootmods DevSys Theatre Jonkichi Tool Generic SMTP UserDB Gables
textport 443
real_textport 10443
webport 10803
real_webport 10080
url_protocol https
access gables
memory_high 128
memory_max 256
statedump_offset 600
freemote +emote
EndOfMessage
chown skotos:skotos /var/game/.root/usr/System/data/instance
cp /var/game/.root/usr/System/data/instance /var/game/root/usr/System/data/
chown skotos:skotos /var/game/root/usr/System/data/instance

cat >/var/game/.root/usr/System/data/userdb <<EndOfMessage
userdb-hostname 127.0.0.1
userdb-portbase 9900
EndOfMessage

# Add SkotOS config file
cat >/var/game/skotos.config <<EndOfMessage
telnet_port = ([ "*": 10098 ]); /* telnet port for low-level game admin access */
binary_port = ([ "*": 10099, /* admin-only emergency game access port */
             "*": 10017,     /* UserAPI::Broadcast port */
             "*": 10070,     /* UserDB Auth port - DO NOT EXPOSE THROUGH FIREWALL */
             "*": 10071,     /* UserDB Ctl port - DO NOT EXPOSE THROUGH FIREWALL */
             "*": 10080,     /* HTTP port */
             "*": 10089,     /* DevSys HTTP port */
             "*": 10090,     /* WOE port, relayed to by websockets */
             "*": 10091,     /* DevSys ExportD port */
             "*": 10443 ]);  /* TextIF port, relayed to by websockets */
directory   = "./.root";
users       = 100;
editors     = 0;
ed_tmpfile  = "../state/ed";
swap_file   = "../state/swap";
swap_size   = 1048576;      /* # sectors in swap file */
cache_size  = 8192;         /* # sectors in swap cache */
sector_size = 512;          /* swap sector size */
swap_fragment   = 4096;         /* fragment to swap out */
static_chunk    = 64512;        /* static memory chunk */
dynamic_chunk   = 261120;       /* dynamic memory chunk */
dump_interval   = 7200;         /* two hours between dumps */
dump_file   = "../skotos.database";

typechecking    = 2;            /* global typechecking */
include_file    = "/include/std.h"; /* standard include file */
include_dirs    = ({ "/include", "~/include" }); /* directories to search */
auto_object = "/kernel/lib/auto";   /* auto inherited object */
driver_object   = "/kernel/sys/driver"; /* driver object */
create      = "_F_create";      /* name of create function */

array_size  = 16384;        /* max array size */
objects     = 300000;       /* max # of objects */
call_outs   = 16384;        /* max # of call_outs */
EndOfMessage

cat >/var/game/root/usr/Gables/data/www/profiles.js <<EndOfMessage
"use strict";
// orchil/profiles.js
var profiles = {
        "portal_gables":{
                "method":   "websocket",
                "protocol": "wss",
                "web_protocol": "https",
                "server":   "$FQDN_CLIENT",
                "port":      10810,
                "woe_port":  10812,
                "http_port": 10803,
                "path":     "/gables",
                "extra":    "",
                "reports":   false,
                "chars":    true,
        }
};
EndOfMessage
chown skotos /var/game/root/usr/Gables/data/www/profiles.js
cp /var/game/root/usr/Gables/data/www/profiles.js /var/game/.root/usr/Gables/data/www/
chown skotos /var/game/.root/usr/Gables/data/www/profiles.js

cat >~skotos/dgd_final_setup.sh <<EndOfMessage
crontab ~/crontab.txt
rm -f /var/game/no_restart.txt  # Just in case
EndOfMessage
chmod +x ~skotos/dgd_final_setup.sh
sudo -u skotos ~skotos/dgd_final_setup.sh
rm ~skotos/dgd_final_setup.sh

touch ~/game_stackscript_finished_successfully.txt
