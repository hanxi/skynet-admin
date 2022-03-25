#!/bin/bash

cd /skynet-admin
wlua start
tail -F log/wlua.log

