# Efficient Backporting Using Customized Tig

## Table of Contents
1. [Overview](#p-overview)
2. [Installation](#p-install)
3. [Quick-view and bplist](#p-quick)
4. [Multiple Commit Selection](#p-multi-select)
5. [Import Bplist from External Script](#p-import-bplist)
6. [Sort Commits in Quick-view by Topo-order](#p-sort-commit)
7. [Action Flag for Multiple Selection](#p-action-flag)
8. [Customize Commit Message When Cherry-pick](#p-commit-message)
	1. [Preparation Script for Cherry-pick](#p-prep-script)
	2. [Customize git hook prepare-commit-msg](#p-git-hook-pcm)
9. [Specify Start Commit in Main View](#p-start-commit)
10. [Find out Feature Branch Commits](#p-feature-branch)
11. [Find Release Tag and Come Back](#p-release-tag)

## Overview <a name="p-overview"></a>
The itig branch of this repo is a hack of tig for efficient backporting work.

It introduces a quick-view to show and do actions on selected commits from main-view.

It also has some enhancements such as multiple commit selection, flag for user-defined commands on multiple selections.

This branch is based on some upstream pull requests ([registers](https://github.com/jonas/tig/pull/708) and [bplist](https://github.com/jonas/tig/pull/915))  

The original README is at [README.adoc](https://github.com/x48Jason/tig/blob/itig/README.adoc).

## Installation <a name="p-install"></a>

```
git clone https://github.com/x48Jason/tig.git
git checkout itig
make
make install
```
There are also some scripts under contrib/backport/, do following to install:
```
cd contrib/backport
./install.sh
```
This install.sh script is a simple bash script that just copy some scripts to ~/bin. Please note some scripts may need to be customized for your needs.

## Quick-view and bplist <a name="p-quick"></a>
Sometimes the commits that need to backport are scattered at large distance within the commit history, especially some later bug fix commits. It is hard to manage these commits.

Quick-view is introduced to gather these commits together. Meanwhile, a bplist is introduced to contain all the related commits. Quick view will show these commits in bplist in one view window when launched. Quick-view is very much the same as Main-view.

Use following setting in .tigrc to toggle a commit into/from bplist
```
bind generic    <C-b>   toggle-bp-mark
```
Use following setting to launch quick-view.
```
bind main       <C-q>   view_quick
bind blame      <C-q>   view_quick
```
Bplist can be saved into file by following tig prompt command:
```
:write-bplist bplistfile
```
And it can be read back by:
```
:read-bplist bplistfile
```

## Multiple Commit Selection <a name="p-multi-select"></a>
Picking up commits one by one into bplist is low efficient.

A select-range is introduced to select multiple commits.

Use following setting in .tigrc to specify the start and end of the select-range from main-view.
```
bind generic    <C-s>   toggle-select-mark
```
And then use following setting to import the commits in select-range into bplist.
```
bind generic    V   select-add-bplist
```

## Import Bplist from External Script <a name="p-import-bplist"></a>
Bplist can also be imported from output of external script.

For example, the following setting can be used to search and import all bug fix commits for all commits in bplist.
```
bind quick      <C-f>   %=(bplist)~/bin/find-fix-commit.sh %(commit)
```
Here '=(bplist)' specifies to import the output of script '~/bin/find-fix-commit.sh' into bplist.

It is required that the output of the script must be list of SHA1 hashes. 

And following is the find-fix-commit.sh
```
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
```

## Sort Commits in Quick-view by Topo-order <a name="p-sort-commit"></a>
After frequent import of commits into bplist, the commit order in the bplist may be wrong, which will cause issue when we want to do actions on these commits.

Use following tig prompt command to sort the commmits into topo-order in repo history.
```
:bplist-sort
```

## Action Flag for Multiple Selection <a name="p-action-flag"></a>
Sometimes it is convenient to do action on multiple commits.

A flag '%' is introduced to act on commits in select-range.

For example, use following setting to cherry-pick all the commits in select-range.
```
bind quick      C       ?%git cherry-pick %(commit)
```

In Quick-view, if no select-range is specified, the action will act on all commits in Quick-view (ie, commits in bplist)

## Customize Commit Message When Cherry-pick <a name="p-commit-message"></a>
Usually backport may have commit message requirements, for example, the original upstream commit SHA1 and the corresponding upstream release may need to be logged.

We can leverage the git hooks and the tig script mechanism to generate automatically the commit message.

### Preparation Script for Cherry-pick <a name="p-prep-script"></a>
Use following to specify running a preparation script for cherry-pick
```
bind main       B       ?~/bin/tig-backport-cherry-pick.sh %(commit) %(ref)
bind quick      B       ?~/bin/tig-backport-cherry-pick.sh %(commit) %(ref)

bind main       <C-a>   ?%~/bin/tig-backport-cherry-pick.sh %(commit) %(ref)
bind quick      <C-a>   ?%~/bin/tig-backport-cherry-pick.sh %(commit) %(ref)
```
The tig-backport-cherry-pick.sh
```
#!/bin/bash

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
bugzilla: https://xxx.org/xxx-kernel/issues/$issue
CVE: N/A
Reference: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/
commit/?id=$full_commit

xxx-SIG: commit $short_commit ("$title")

-------------------------------------

EOF

/usr/bin/git cherry-pick $commit
```
This script will import some variables from '.git/backport/backport-variables.sh', for example, feature-name, issue-number, etc.

Then it generates a commit message template in .git/backport/backport-commit-msg.txt

### Customize git hook prepare-commit-msg <a name="p-git-hook-pcm"></a>
Here we also need to customize the .git/hooks/prepare-commit-msg script to complete the workflow.
```
#!/bin/sh

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2
SHA1=$3

if [ -e .git/backport/backport-commit-msg.txt ]; then
        /usr/bin/cat "$COMMIT_MSG_FILE" >> .git/backport/backport-commit-msg.txt
        /usr/bin/mv .git/backport/backport-commit-msg.txt "$COMMIT_MSG_FILE"
fi


SOB=$(git var GIT_COMMITTER_IDENT | sed -n 's/^\(.*>\).*$/Signed-off-by: \1/p')
git interpret-trailers --in-place --trailer "$SOB" "$COMMIT_MSG_FILE"
```
This script will check if there is a commit message template file '.git/backport/backport-commit-msg.txt'. If so, it will append the original commit message to the template, and then add 'Signed-off-by:' at the end of the commit message.

## Specify Start Commit in Main View <a name="p-start-commit"></a>
Linux kernel repo is a very large repo which will take a long time to load in Main-view. It is desirable to be able to specify which commit to start display in the main-view.

The following setting can be used in .tigrc to specify start commit.
```
set main-options = %(register:b) %(ref)
```
The main-options will be append to git command to modify the behavior of what commits will be shown in main-view.

The basic idea is to use main-options to specify the commit range that will be shown in main-view, %(register:b) will specify the start commit, and until the current %(ref).

Here we can use tig init-script to assign value to register b.
```
export TIG_SCRIPT=/home/xxx/bin/tig-init.script
```
The tig-init.script is as follows:
```
:exec =(b)~/bin/get-repo-commit-list-base.sh
```
And the get-repo-commit-list-base.sh
```#!/bin/bash

if pwd|grep -q qemu; then
        echo "^v6.0.0"
        exit 0
fi

if pwd|grep -q linux; then
        echo "^v5.10"
        exit 0
fi

if pwd|grep -q tig; then
        echo "^tig-2.5.0"
        exit 0
fi

echo ""
```

## Find out Feature Branch Commits <a name="p-feature-branch"></a>
Sometimes when we are browsing in the main/blame view, we may be interested in a line of code change. Further, we may be interested which feature introduced this line of code change. We may want to find out all the commits of that feature.

The following setting can be used to import that feature commits into bplist. The basic idea is that we assume the maintainer usually merges a feature branch, so we can find out the merge base and merge point to derive all the commits.
```
bind main       x       =(bplist)~/bin/find-commit-feature-rev-range.sh %(commit) %(ref)
bind blame      x       =(bplist)~/bin/find-commit-feature-rev-range.sh %(commit) %(ref)
```
The find-commit-feature-rev-range.sh
```
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
```

## Find Release Tag and Come Back <a name="p-release-tag"></a>
Sometimes when we browse the repo history, we may want to see which release tag this commit is introduced.

The following setting can be used for this.
```
bind main       T       :script ~/bin/next-tag.script
bind main       <C-t>   :goto %(register:d)
```
The next-tag.script:
```
:set-register d %(commit)
:exec =(c)~/bin/find-next-tag.sh %(commit) %(ref)
:goto %(register:c)
```
Here we firstly save current commit into register:d, then trigger find-next-tag.sh to find the release tag and put it in register:c, finally goto the release tag.

After checking, <Ctrl-t> can be used to go back to the original commit, since we saved it in register:d.

The find-next-tag.sh:
```
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

next_tag=$(git describe --tags --abbrev=0 --contains $commit)
if [ $? -ne 0 ]; then
	next_tag=$ref
else
	next_tag=$(echo $next_tag | cut -d~ -f1)
fi
next_tag=$(git log -n 1 --format=%H $next_tag)
[ $DEBUG = "yes" ] && echo "next_tag: $next_tag"

echo $next_tag
```

