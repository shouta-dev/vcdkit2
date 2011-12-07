#!/bin/sh

run() {
  $VCDKIT/script/vcd-trend.rb \
    -l$VCDKIT/log/vcd-trend.log \
    -m $VCDKIT/config/mailer.xml $*
}

if [ "$SILENT" == "yes" ]; then
    run $* > /dev/null 2>&1
else
    run $*
fi


