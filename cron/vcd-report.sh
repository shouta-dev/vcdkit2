#!/bin/sh

run() {
  $VCDKIT/script/vcd-report.rb \
    -l$VCDKIT/log/vcd-report.log
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi


