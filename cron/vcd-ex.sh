#!/bin/sh

$VCDKIT/vcd-ex.rb -v2 \
  -l$VCDKIT/log/vcd-ex.log \
  -t -m $VCDKIT/conf/mailer.xml > /dev/null

