#!/bin/sh

$VCDKIT/vcd-trend.rb -v2 \
  -l$VCDKIT/log/vcd-trend.log \
  -m $VCDKIT/conf/mailer.xml > /dev/null

