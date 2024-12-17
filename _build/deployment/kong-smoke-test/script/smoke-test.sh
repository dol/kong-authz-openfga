#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Missing required parameter. <hostname>"
fi

if [ -d "/var/secret" ]; then
  for SECRET_NAME in /var/secret/*;
    do export "$(basename -- "${SECRET_NAME}")"="$(cat "${SECRET_NAME}")";
  done
fi

# Disable proxy settings
export https_proxy=""
export HTTPS_PROXY=""

# Send HTTP/1.1 with SNI smoke.test
curl --connect-to "smoke.test:8443:${1}:8443" "https://smoke.test:8443" \
  --http1.1 \
  --no-alpn \
  --no-npn \
  --insecure \
  --verbose \
  -H "Host: smoke.test" \
  -H "Content-Type: text/plain" \
  -d "${SMOKE_TEST_REQUEST_BODY}" | grep -F "Smoke test was a success"
# Send HTTP/2 with SNI smoke.test
curl --connect-to "smoke.test:8443:${1}:8443" "https://smoke.test:8443" \
  --http2-prior-knowledge \
  --insecure \
  --verbose \
  -H "Host: smoke.test" \
  -H "Content-Type: text/plain" \
  -d "${SMOKE_TEST_REQUEST_BODY}" | grep -F "Smoke test was a success"
