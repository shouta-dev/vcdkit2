#!/bin/sh

$VCDKIT/vsp-datastore.rb -v2 -c2 \
  -l$VCDKIT/log/vsp-datastore.log \
  -C$VCDKIT/config/vsp-datastore.xml \
  -D -t -m $VCDKIT/config/mailer.xml > /dev/null

