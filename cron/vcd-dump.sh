#!/bin/sh

$VCDKIT/script/vcd-dump.rb \
  -l$VCDKIT/log/vcd-dump.log \
  -t -m $VCDKIT/config/mailer.xml  >/dev/null

