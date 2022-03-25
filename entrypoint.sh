#!/bin/bash

mongod -f /etc/mongodb.conf &
wlua start
tail -F log/wlua.log

