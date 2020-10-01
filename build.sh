#!/usr/bin/env bash

set -e
elm make src/PF.elm --output=elm.js
open index.html
