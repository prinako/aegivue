#!/bin/sh
set -eu

mkdir -p /etc/nginx

if [ -z "$(find /etc/nginx -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  echo "Initializing empty /etc/nginx volume with default configuration"
  cp -a /usr/share/nginx-default/. /etc/nginx/
fi
