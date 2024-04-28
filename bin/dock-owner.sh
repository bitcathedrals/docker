#! /usr/bin/env bash

owner=$1
shift

output=""

for dir in $@
do
  output="${output} chown -R $owner $dir;"
done

echo "$output"
