#!/usr/bin/env bash

set -e
# elm make src/Board.elm --output=elm.js
elm make src/Main.elm --output=elm.js
# cat elm.js index.js > main.js
open index.html
# firebase serve

