#!/bin/sh

run() {
    $VCDKIT/script/vcd-ex.rb \
	-l$VCDKIT/log/vcd-ex.log \
	-t -m $VCDKIT/config/mailer.xml
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi



