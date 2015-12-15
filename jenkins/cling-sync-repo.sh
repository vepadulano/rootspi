#!/bin/bash -e

set -x

clingRepo="$WORKSPACE/cling"
rootRepo="$WORKSPACE/root"

export ASKPASSHELPER=$WORKSPACE/credhelper.sh
# Note: this will write '$', 'C', 'L'... into the tool, not the pass!
echo 'echo $CLINGGITPW' > $ASKPASSHELPER
chmod a+x $ASKPASSHELPER

# What was the last commit in root.git's interpreter/cling?
rootCommit=`cd $rootRepo && git rev-list -n 1 HEAD -- interpreter/cling`
if [ "x$rootCommit" = "x" ]; then
  echo 'Cannot extract last cling commit in root repository!' >&2
  exit 1
fi
echo "Most recent commit in ROOT/interpreter/cling: $rootCommit"

# What was the most recent ROOT commit merged into cling?
clingTag=`cd $clingRepo && git tag -l '__internal-root-*'`
if [ "x$clingTag" = "x" ]; then
  echo 'Cannot extract most recent merge tag!' >&2
  exit 1
fi

if [ "__internal-root-$rootCommit" =  "$clingTag" ]; then
  echo 'cling is already up to date, exiting.'
  exit
fi

startCommit="${clingTag/__internal-root-/}"
echo "Applying patches after $startCommit and up to $rootCommit"

patch="$WORKSPACE/root-to-cling-$startCommit-$rootCommit.patch";

# extract the patch
cd $rootRepo
git format-patch --no-stat --find-renames --find-copies --stdout --keep-subject $startCommit..$rootCommit -- interpreter/cling/ > $patch

# For better logs:
cat $patch

# apply the patch
cd $clingRepo
git am -p3 $patch
GIT_ASKPASS=$ASKPASSHELPER git push origin master
newTag="__internal-root-$rootCommit"
git tag $newTag
GIT_ASKPASS=$ASKPASSHELPER git push origin $newTag
git tag -d $clingTag
GIT_ASKPASS=$ASKPASSHELPER git push origin :refs/tags/$clingTag
# clean up
rm $patch
