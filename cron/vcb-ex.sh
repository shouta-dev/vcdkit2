#!/bin/sh

$VCDKIT/vcb-ex.rb --chargeback_db 2 \
  --vcddc CB-02,CB-03 \
  -l$VCDKIT/log/vcb-ex.log \
  -t -m $VCDKIT/conf/mailer.xml > /dev/null

