#!/bin/bash

set -o errexit

function weblate_django_shell() {
	if test -z "$(which weblate-ssh)" ; then
		echo "This command needs ssh access to l10n.opensuse.org server." >&2
		echo "Please install/create weblate-ssh script wrapper." >&2
		echo "It is not part of this repository because it contains sensitive data." >&2
		exit 1
	fi
	# For debugging, uncomment cat and comment out weblate-ssh
	#cat
	weblate-ssh 'su -l -s /usr/bin/python wwwrun /usr/share/weblate/manage.py shell'
}

# Warning: weblate_manage() does not escape arguments. Do not use spaces!
function weblate_manage() {
	if test -z "$(which weblate-ssh)" ; then
		echo "This command needs ssh access to l10n.opensuse.org server." >&2
		echo "Please install/create weblate-ssh script wrapper." >&2
		echo "It is not part of this repository because it contains sensitive data." >&2
		exit 1
	fi
	# For debugging, uncomment cat and comment out weblate-ssh
	#cat
	weblate-ssh "su wwwrun -s /bin/sh -c '/usr/bin/python /usr/share/weblate/manage.py $*'"
}

# weblate_create_project name slug_or_empty web
function weblate_create_project() {
	local NAME=$1
	local SLUG=$2
	local WEB=$3
	if test -z $2 ; then
		SLUG="$(echo $NAME | tr " "A-Z. -a-z-)"
	fi
	if test -n "$(echo $SLUG | sed 's/[-a-z0-9_]//g')" ; then
		echo "Project URL slug \"$SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi
	if ! curl -f -I "$WEB" >/dev/null 2>&1 ; then
		echo "Project web not found." >&2
		echo "Please add a web lookup." >&2
		exit 1
	fi

# Not yet implemented in Weblate API.
#	curl \
#		-H "Authorization: Token $(<.weblate-api-key)" \
#		-T- \
#		http://l10n.opensuse.org/api/projects/$NAME <<EOF
#	{
#		"name":"$NAME",
#		"slug":"$SLUG",
#		"web":"$WEB",
#		"push_on_commit":"true",
#	}
#EOF
#project = Project(name="$NAME",slug="$SLUG",web="$WEB",push_on_commit=True)
	weblate_django_shell <<EOF
from weblate.trans.models.project import Project
project = Project(name="$NAME",slug="$SLUG",web="$WEB")
project.save()
EOF
}

function weblate_create_component() {
	local PROJECT_NAME=$1
	local NAME=$2
	local SLUG=$3
	local REPO=$4
	local REPOWEB=$5
	local BRANCH_CHECK=$6
	local BRANCH=$7
	local POT_MASK=$8
	local PO_MASK=$9

	if test -z $3 ; then
		SLUG="$(echo $NAME | tr " "A-Z. -a-z-)"
	fi
	if test -n "$(echo $SLUG | sed 's/[-a-z0-9_]//g')" ; then
		echo "Component URL slug \"$SLUG\" should contain only lowercase letters, \"-\" and \"_\"." >&2
		echo "Please fix or add a name convertor." >&2
		exit 1
	fi

	if test -n "$BRANCH_CHECK" ; then
		if ! curl -f -I "$BRANCH_CHECK" >/dev/null 2>&1 ; then
			echo "Project branch not found." >&2
			echo "Please fix." >&2
			exit 1
		fi
	fi
	# FIXME: Can it reuse different branch? If yes, it should be:
	# if test "$1" = "base" -a "$3" = "master" ; then
	#	REPO=weblate://yast-base/master
	if test "${REPO#weblate://}" = "$REPO" ; then
		PUSH=",push=\"$REPO\""
	else
		PUSH=
	fi
	weblate_django_shell <<EOF
from weblate.trans.models.project import Project
from weblate.trans.models.subproject import SubProject
project = Project.objects.get(name="$PROJECT_NAME")
component = SubProject(name="$NAME",slug="$SLUG",project=project,vcs="git",repo="$REPO"$PUSH,repoweb="$REPOWEB",branch="$BRANCH",filemask="$PO_MASK",new_base="$POT_MASK",file_format="po",new_lang="add")
component.save()
EOF
}

# github_web user name
function github_web {
	echo "https://github.com/$1/$2"
}

function github_repoweb {
	echo "https://github.com/$1/$2/blob/%(branch)s/%(file)s#L%(line)s"
}

function github_branch_check {
	echo "https://github.com/$1/$2/tree/$3"
}

# github_repo user name
function github_repo {
	echo "git@github.com:$1/$2.git"
}

# weblate_link_repo project_slug subproject_slug
function weblatelink_repo {
	echo "weblate://$1/$2"
}

# weblate_upload_suggestion project component language file
function weblate_upload_suggestions() {
	cat $4 | weblate-ssh cat \>/tmp/weblate-upload-file.po
	weblate_manage add_suggestions --author=weblate-admin@opensuse.org $1 $2 $3 /tmp/weblate-upload-file.po
	weblate-ssh rm /tmp/weblate-upload-file.po
}

## This code is saved for use of Weblate API.
## API is incomplete and it can be used only for some tasks.
#
#if ! test -f ".weblate-api-key" ; then
#	echo "Please save Weblate admin API token from https://l10n.opensuse.org/accounts/profile/#api as .weblate-api-key" >&2
#	exit 1
#fi
#
#YAST_PROJECT_LIST=$(
#	cd ../po
#	for DIR in * ; do
#		if test -d "$DIR" ; then
#			echo $DIR
#		fi
#	done
#)
#
#WEBLATE_PROJECT_LIST=$(
#	curl \
#		-H "Authorization: Token $(<.weblate-api-key)" \
#		http://l10n.opensuse.org/api/projects/ |
#	json_pp -f json -t json |
#	sed -n 's/"//g;s/,//g;s/slug[[:space:]]*://p'
#)
#
#curl \
#    -H "Authorization: Token $(<.weblate-api-key)" \
#    "https://l10n.opensuse.org/api/translations/libgettextdemo/master/cs/file/?format=po" \
#    >file.po
#
## Works, but suggestions and other fine features are not yet implemented.
##Warning: skip unknown form field: method=suggest
#curl \
#    -H "Authorization: Token $(<.weblate-api-key)" \
#    -F "file=@file.po;method=suggest" \
#    "https://l10n.opensuse.org/api/translations/libgettextdemo/master/cs/file/"
