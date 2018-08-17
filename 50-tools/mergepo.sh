#!/bin/bash
# use $0 lang1 lang2 .. -- domain1 domain2 ...
domains=()
languages=()
argtype=lang
for i in "$@"; do
    if [ "$i" = '--' ]; then
	argtype=domain
    fi
    if [ "$argtype" = "domain" ]; then
	domains+=($i)
    elif [ "$argtype" = "lang" ]; then
	languages+=($i)
    fi
done
if [ -z "$domains" ]; then
    domains=(50-pot/*.pot)
    domains=("${domains[@]##*/}")
    domains=("${domains[@]%.pot}")
fi
if [ -z "$languages" ]; then
    languages=(*/po)
    languages=("${languages[@]%/po}")
fi
for domain in "${domains[@]}"; do
    pot="50-pot/$domain.pot"
    for lang in "${languages[@]}"; do
	o="$lang/po/$domain.$lang.po"
	[ -e "$o" ] || continue
	if msgmerge -q --previous --lang="$lang" -o "$o".new "$o" "$pot"; then
	    mv "$o".new "$o"
	fi
    done
done
