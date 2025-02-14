#!/bin/sh
set -e

mkdir -p ./bin
odin build ./src -out:./bin/pong -o:speed
