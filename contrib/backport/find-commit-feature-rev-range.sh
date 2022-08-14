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


merge_commit=$(git rev-list --merges --ancestry-path $commit..$ref | tail -n 1)
[ $DEBUG = "yes" ] && echo "initial merge_commit: $merge_commit"

if [ "x$merge_commit" = "x" ]; then
	merge_commit=$next_tag
fi
[ $DEBUG = "yes" ] && echo "merge_commit: $merge_commit"


commit_list=$(git rev-list --ancestry-path $commit..$merge_commit)
commit_count=$(echo $commit_list | tr ' ' '\n' | wc -l)
if [ $DEBUG = "yes" ]; then
	echo "commit_count: $commit_count"
	echo "commit_list: $commit_list"
fi
if [ $commit_count -eq 1 ]; then
	last_commit_before_merge=$commit
else
	last_commit_before_merge=$(echo $commit_list | tr ' ' '\n' | head -n 2 | tail -n 1)
fi
[ $DEBUG = "yes" ] && echo "last_commit_before_merge: $last_commit_before_merge"

merge_commit_parents=$(git log --pretty=format:%P -n 1 $merge_commit)
parents_array=($(echo $merge_commit_parents | tr ' ' '\n'))
[ $DEBUG = "yes" ] && echo "merge_commit_parents: $merge_commit_parents"

merge_base="$commit"
for i in ${parents_array[@]}; do
	if [ "$i" != "$last_commit_before_merge" ]; then
		merge_base=$(git merge-base $commit $i)
		break
	fi
done
[ $DEBUG = "yes" ] && echo "merge_base: $merge_base"

nearest_merge_base=$(git rev-list --merges --ancestry-path ${merge_base}..${last_commit_before_merge} | head -n 1)
if [ "x$nearest_merge_base" = "x" ]; then
	nearest_merge_base=$merge_base
fi
[ $DEBUG = "yes" ] && echo "nearest_merge_base: $nearest_merge_base"


prev_tag=$(git describe --tags --abbrev=0 $commit)
if [ $? -ne 0 ]; then
	prev_tag=$nearest_merge_base
else
	prev_tag=$(git log -n 1 --format=%H $prev_tag)
fi
[ $DEBUG = "yes" ] && echo "prev_tag: $prev_tag"


if [ $nearest_merge_base = $commit ]; then
	nearest_merge_base=$prev_tag
fi
[ $DEBUG = "yes" ] && echo "nearest_merge_base after prev_tag: $nearest_merge_base"


stop_commit=$last_commit_before_merge
if $(git merge-base --is-ancestor $next_tag $last_commit_before_merge) ; then
	stop_commit=$next_tag
fi
start_commit=$nearest_merge_base
if $(git merge-base --is-ancestor $nearest_merge_base $prev_tag) ; then
	start_commit=$prev_tag
fi

# echo "${start_commit}..${stop_commit}"
git rev-list "${start_commit}..${stop_commit}"
