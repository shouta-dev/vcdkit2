#!/bin/sh

$VCDKIT/vsp-datastore.rb -v2 -c2 \
  -l$VCDKIT/log/vsp-datastore.log \
  -C$VCDKIT/conf/vsp-datastore.xml \
  -D -t -m $VCDKIT/conf/mailer.xml > /dev/null

