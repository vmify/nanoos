#!/bin/sh
test -n "$MODALIAS" && modprobe "$MODALIAS";
exec /sbin/mdev