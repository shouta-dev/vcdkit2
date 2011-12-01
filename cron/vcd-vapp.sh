#!/bin/sh

$VCDKIT/vcd-vapp.rb -v2 \
  -D --vdc Admin,'Basic - Admin', -nCBMON \
  -l$VCDKIT/log/vcd-vapp-delete.log \
  -t -m $VCDKIT/conf/mailer.xml > /dev/null && \
\
$VCDKIT/vcd-vapp.rb -v2 \
  -A --vapptemplate Admin,'Basic - Admin',CBMON_TMPL -nCBMON  \
  -l$VCDKIT/log/vcd-vapp-create.log \
  -t -m $VCDKIT/conf/mailer.xml > /dev/null

