#!/bin/bash

rev=$1

short_rev=$(git rev-parse --short=12 $rev)
git log --oneline --grep="Fixes: $short_rev" -F v5.10..master > .tmp.fix_commit.$short_rev

while IFS="" read -r line || [ -n "$line" ]
do
	fix_rev=$(echo $line | cut -d' ' -f1)
	git rev-parse $fix_rev
done < .tmp.fix_commit.$short_rev

/usr/bin/rm .tmp.fix_commit.$short_rev 2>&1 > /dev/null
exit 0

