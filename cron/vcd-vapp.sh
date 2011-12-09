#!/bin/sh

run() {
  $VCDKIT/script/vcd-vapp.rb \
    -D --vdc Admin,'Basic - Admin', -nCBMON \
    -l$VCDKIT/log/vcd-vapp-delete.log \
    -t -m $VCDKIT/config/mailer.xml && \
  $VCDKIT/script/vcd-vapp.rb \
    -A --vapptemplate Admin,'Basic - Admin',CBMON_TMPL -nCBMON  \
    -l$VCDKIT/log/vcd-vapp-create.log \
    -t -m $VCDKIT/config/mailer.xml
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi



