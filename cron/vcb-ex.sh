#!/bin/sh

run() {
  $VCDKIT/script/vcb-ex.rb \
    --vcddc CB-02,CB-03 \
    -l$VCDKIT/log/vcb-ex.log \
    -t -m $VCDKIT/config/mailer.xml
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi


