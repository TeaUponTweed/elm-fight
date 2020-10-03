#!/usr/bin/env bash

# set -e
STARTPATH="$( cd . >/dev/null 2>&1 ; pwd -P )"
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# echo $STARTPATH
# echo $SCRIPTPATH
# echo "cd $SCRIPTPATH/pushfight-viz"

# cd $SCRIPTPATH/pushfight-viz
# echo $PWD
if [[ $1 == '--optimize' ]] ; then
	elm make ${SCRIPTPATH}/pushfight-viz/Main.elm --optimize --output=${SCRIPTPATH}/target/elm.js
	uglifyjs ${SCRIPTPATH}/target/elm.js \
		--compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" \
	| uglifyjs --mangle --output=${SCRIPTPATH}/target/elm.min.js
else
	elm make ${SCRIPTPATH}/pushfight-viz/Main.elm --output=${SCRIPTPATH}/target/elm.js
fi
# cd $STARTPATH
# open index.html
