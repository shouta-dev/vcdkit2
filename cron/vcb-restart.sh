#!/bin/sh

$VCDKIT/vcb-ex.rb --chargeback_db 2 -c5 \
  --restart_vcddc --vcddc CB-02,CB-03 \
  -l $VCDKIT/log/vcb-restart.log \
  -t -m $VCDKIT/config/mailer.xml > /dev/null

