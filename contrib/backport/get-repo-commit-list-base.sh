#!/bin/bash

if pwd|grep -q qemu; then
	echo "^v6.0.0"
	exit 0
fi

if pwd|grep -q linux; then
	branch=$(git branch --show-current)
	if [ "$branch" = "openEuler-1.0-LTS" ]; then
		echo "^v4.19"
	else
		echo "^v5.10"
	fi
	exit 0
fi

if pwd|grep -q tig; then
	echo "^tig-2.5.0"
	exit 0
fi

echo ""
