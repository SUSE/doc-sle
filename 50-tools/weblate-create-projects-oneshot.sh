#!/bin/bash

# This script generates initial projects import script. It was used only once
# and it could be called never more. Once regular projects maintenance will be
# implemented, it could be deleted. This is just a source of needed code.

BRANCH_ON_GITHUB=master
BRANCH_ON_WEBLATE=$BRANCH_ON_GITHUB
BRANCH_SLUT=master

set -o errexit

# generate textdomain
function generate() {
	#echo "weblate_create_project packages-i18n" >&3
	if test "$1" = a ; then
		echo "weblate_create_component packages-i18n \"$1 $BRANCH_ON_WEBLATE\" \"$1-$BRANCH_SLUT\" \"$(github_repo openSUSE packages-i18n)\" \"\" \"$(github_branch_check openSUSE packages-i18n $BRANCH_ON_GITHUB)\" $BRANCH_ON_GITHUB \"50-pot/$1.pot\" \"*/po/$1.*.po\"" >&3
	else
		echo "weblate_create_component packages-i18n \"$1 $BRANCH_ON_WEBLATE\" \"$1-$BRANCH_SLUT\" \"$(weblatelink_repo packages-i18n a-$BRANCH_SLUT)\" \"\" \"\" $BRANCH_ON_GITHUB \"50-pot/$1.pot\" \"*/po/$1.*.po\"" >&3
	fi
}

if test -f "weblate-create-projects-oneshot.sh" ; then
	cd ..
fi
if ! test -f "50-tools/weblate-create-projects-oneshot.sh" ; then
	echo "Please call this script from yast-translations top directory."
	exit 1
fi
WORKDIR=$PWD

. 50-tools/weblate-functions.inc

exec 3>50-tools/weblate-create-projects-oneshot-run.sh
cat >&3 <<EOF
#!/bin/bash
echo "This script was already executed. If cannot be started any more." >&2
exit 1
if test -f "weblate-create-projects-oneshot-run.sh" ; then
	cd ..
fi
if ! test -f "50-tools/weblate-create-projects-oneshot-run.sh" ; then
	echo "Please call this script from yast-translations top directory."
	exit 1
fi
. 50-tools/weblate-functions.inc
weblate_create_project packages-i18n "" https://github.com/openSUSE/packages-i18n
EOF

pushd $WORKDIR/50-pot

generate a
for POT in *.pot ; do
	DOMAIN=${POT%.pot}
	# base must be created first
	if test $DOMAIN = a ; then
		continue
	fi
	generate $DOMAIN
done

popd
exec 3>&-
chmod +x 50-tools/weblate-create-projects-oneshot-run.sh

echo "50-tools/weblate-create-projects-oneshot-run.sh is ready"
