#!/usr/bin/env bash
# Καρφωμένο φορτίο: κλώνος Juice Shop στο tag + ΕΛΕΓΧΟΣ commit· (προαιρετικά) pull image by digest.
# Χρήση: ci/payload.sh [--image]
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
set -a; . ci/pins.env; set +a
rm -rf app
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$JS_TAG" https://github.com/juice-shop/juice-shop.git app
test "$(git -C app rev-parse HEAD)" = "$JS_COMMIT"
if [ "${1:-}" = --image ]; then
  for i in 1 2 3; do docker pull -q "$JS_IMG" >/dev/null && break; sleep 10; done
  docker image inspect "$JS_IMG" >/dev/null
fi
echo "payload OK: $JS_TAG @ $JS_COMMIT"
