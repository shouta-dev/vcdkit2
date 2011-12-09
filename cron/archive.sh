#!/bin/sh

export VCDDATA=$VCDKIT/data

archive() {
    tooldir=$1
    days=$2

    for t in `find $VCDDATA/$tooldir -maxdepth 1 -mindepth 1 -mtime +$days -type d`
    do
	file=`basename $t`
	dir=`dirname $t`
	echo "Creating tar archive: $t"
        tar zcf $dir/$file.tgz -C $dir $file && \
            rm -fr $t && \
            mv $dir/$file.tgz $VCDDATA/$tooldir/archive
    done
}

archive vcd-dump 0
archive vcd-report 2
