
#!/bin/bash

#set -x

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

next_tag=$(git describe --tags --abbrev=0 --contains $commit)
if [ $? -ne 0 ]; then
	next_tag=$ref
else
	next_tag=$(echo $next_tag | cut -d~ -f1)
fi
next_tag=$(git log -n 1 --format=%H $next_tag)
[ $DEBUG = "yes" ] && echo "next_tag: $next_tag"

echo $next_tag
