#!/bin/bash

DEBUG="no"
while getopts d flag
do
	case "${flag}" in
		d) DEBUG="yes";;
	esac
done
shift "$((OPTIND-1))"

commit=$1
ref=$2

full_commit=$(git rev-parse $commit)
short_commit=$(git rev-parse --short=12 $commit)
title=$(git show --pretty=format:%s -s $commit)

next_tag=$(git describe --tags --abbrev=0 --contains $commit)
if [ $? -ne 0 ]; then
	next_tag=$ref
else
	next_tag=$(echo $next_tag | cut -d~ -f1)
fi

mkdir -p .git/backport
category="feature"
feature="<feature-name>"
issue="<issue-number>"

if [ -e .git/backport/backport-variables.sh ]; then
	source .git/backport/backport-variables.sh
	[ "x$CATEGORY" != "x" ] && category=$CATEGORY
	[ "x$FEATURE" != "x" ] && feature=$FEATURE
	[ "x$ISSUE" != "x" ] && issue=$ISSUE
fi

cat <<EOF > .git/backport/backport-commit-msg.txt
$title

mainline inclusion
from mainline-$next_tag
commit $full_commit
category: $category
feature: $feature
bugzilla: https://xxx.org/xxxxxx/kernel/issues/$issue
CVE: N/A
Reference: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/
commit/?id=$full_commit

Intel-SIG: commit $short_commit ("$title")

-------------------------------------

EOF

/usr/bin/git cherry-pick $commit
