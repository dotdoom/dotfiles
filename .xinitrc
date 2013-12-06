#!/bin/sh

LOGS_DIR=.cache/enlightenment
mkdir -p $LOGS_DIR
exec >$LOGS_DIR/stdout.log 2>$LOGS_DIR/stderr.log

xrdb -merge .Xresources
xset r rate 290 30

exec enlightenment_start
