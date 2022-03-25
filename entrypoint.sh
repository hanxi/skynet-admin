#!/bin/bash

mongod -f /etc/mongodb.conf &
sleep 5
wlua start
tail -F log/wlua.log

