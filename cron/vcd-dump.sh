#!/bin/sh

run() {
  $VCDKIT/script/vcd-dump.rb \
      -l$VCDKIT/log/vcd-dump.log \
      -t -m $VCDKIT/config/mailer.xml 
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi


