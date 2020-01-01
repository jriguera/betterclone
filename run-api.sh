#!/usr/bin/env bash

export PREFIX="$(pwd)"
case "$(uname -m)" in
  x86_64)
    WEBHOOK_URL="https://github.com/adnanh/webhook/releases/download/2.6.8/webhook-linux-amd64.tar.gz"
  ;;
  armv7l)
    WEBHOOK_URL="https://github.com/adnanh/webhook/releases/download/2.6.8/webhook-linux-arm.tar.gz"
  ;;
  *)
    echo "Unknown architecture!"
    exit 1
  ;;
esac
[ ! -x "${PREFIX}]/lib/webhook" ] && wget -q -O- "${WEBHOOK_URL}" | tar -zx --strip 1 -C "${PREFIX}/lib"

sudo PREFIX="${PREFIX}" "${PREFIX}/bin/betterclone-http-api.sh"

