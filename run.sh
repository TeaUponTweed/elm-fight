#!/usr/bin/env bash

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# open "http://localhost:8080"
go run ${SCRIPTPATH}/target/*.go

