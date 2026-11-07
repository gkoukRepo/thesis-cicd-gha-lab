#!/usr/bin/env bash
# Εκδόσεις μέσα στο run: DB scanners (κατέβηκαν ΣΤΟ runner — όχι κοινό snapshot με local/jenkins),
# image digests, φορτίο, runner image/version. Απαιτεί env D, SYS.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
set -a; . ci/pins.env; set +a
E=evidence; C=${RUNNER_TEMP:-/tmp}/cache; mkdir -p "$E"
DR=(docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp --tmpfs /tmp:rw,mode=1777)
"${DR[@]}" -v "$C/trivy:/cache/trivy" "$IMG_TRIVY" --cache-dir /cache/trivy version --format json > "$E/trivydb_${SYS}_${D}.json"
"${DR[@]}" -v "$C/grype:/cache/grype" -e GRYPE_DB_CACHE_DIR=/cache/grype -e GRYPE_DB_AUTO_UPDATE=false \
  "$IMG_GRYPE" db status -o json > "$E/grypedb_${SYS}_${D}.json"
docker image inspect "$JS_IMG" "$IMG_TRIVY" "$IMG_GRYPE" "$IMG_GITLEAKS" "$IMG_SEMGREP" "$IMG_CHECKOV" "$IMG_ZAP" \
  > "$E/images_${SYS}_${D}.json"
echo "juiceshop_source_tag=$JS_TAG juiceshop_source_commit=$(git -C app rev-parse HEAD) juiceshop_image=$JS_IMG" \
  > "$E/payload_${SYS}_${D}.txt"
# (η έκδοση του runner agent ΔΕΝ εκτίθεται ως env· καταγράφεται από το log «Current runner version» στο collect)
jq -n --arg os "${ImageOS:-}" --arg img "${ImageVersion:-}" \
      --arg name "${RUNNER_NAME:-}" --arg env "${RUNNER_ENVIRONMENT:-}" --arg docker "$(docker --version)" \
      --arg sha "${GITHUB_SHA:-}" --arg run "${GITHUB_RUN_ID:-}" --arg att "${GITHUB_RUN_ATTEMPT:-}" \
  '{runner_image_os:$os, runner_image_version:$img, runner_name:$name,
    runner_environment:$env, docker:$docker, workflow_sha:$sha, run_id:$run, run_attempt:$att}' \
  > "$E/runner_${SYS}_${D}.json"
