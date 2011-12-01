#!/bin/sh

$VCDKIT/vcd-dump.rb -v2 -c2 \
  -l$VCDKIT/log/vcd-dump.log \
  -t -m $VCDKIT/conf/mailer.xml >/dev/null

