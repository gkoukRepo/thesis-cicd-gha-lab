#!/usr/bin/env bash
# Toolbaseline (CONTROL): ένας canonical scanner ως container (ΙΔΙΑ images/digests με SYS=local/jenkins).
# Καταγράφει το exit code στο evidence/exitcodes_${SYS}_${D}.txt και ΕΠΙΣΤΡΕΦΕΙ το ίδιο exit code
# (ο χειρισμός fail/allow γίνεται από το ΣΥΣΤΗΜΑ: `continue-on-error` στο workflow — όχι εδώ).
# Χρήση: ci/scan.sh <trivy|trivyfs|grype|gitleaks|semgrep|checkov|zap>     (απαιτεί env D, SYS)
set -uo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
set -a; . ci/pins.env; set +a
: "${D:?}" "${SYS:?}"
tool=$1; W=$PWD; E=evidence; mkdir -p "$E" "${RUNNER_TEMP:-/tmp}/cache/trivy" "${RUNNER_TEMP:-/tmp}/cache/grype"
C=${RUNNER_TEMP:-/tmp}/cache
SOCK_GID=$(stat -c %g /var/run/docker.sock)
DR=(docker run --rm -u "$(id -u):$(id -g)" -v "$W:$W" -w "$W" -e HOME=/tmp --tmpfs /tmp:rw,mode=1777,size=4g)
DOCK=(-v /var/run/docker.sock:/var/run/docker.sock --group-add "$SOCK_GID")
case "$tool" in
  trivy)   "${DR[@]}" "${DOCK[@]}" -v "$C/trivy:/cache/trivy" "$IMG_TRIVY" --cache-dir /cache/trivy image \
             --quiet --format json --output "$E/trivy_${SYS}_${D}.json" "$JS_IMG" ;;
  trivyfs) "${DR[@]}" -v "$C/trivy:/cache/trivy" "$IMG_TRIVY" --cache-dir /cache/trivy fs --quiet \
             --scanners vuln,secret,misconfig --format json --output "$E/trivyfs_${SYS}_${D}.json" app ;;
  grype)   "${DR[@]}" "${DOCK[@]}" -v "$C/grype:/cache/grype" -e GRYPE_DB_CACHE_DIR=/cache/grype \
             -e GRYPE_CHECK_FOR_APP_UPDATE=false "$IMG_GRYPE" "$JS_IMG" -o json --file "$E/grype_${SYS}_${D}.json" ;;
  gitleaks) "${DR[@]}" "$IMG_GITLEAKS" detect --source app --no-git --no-banner --report-format json \
             --report-path "$E/gitleaks_${SYS}_${D}.json" ;;
  semgrep) "${DR[@]}" "$IMG_SEMGREP" semgrep scan --config p/ci --json --output "$E/semgrep_${SYS}_${D}.json" app ;;
  # Checkov: ΜΟΝΟ το config του συστήματος (.github/workflows → framework github_actions)
  checkov) "${DR[@]}" --entrypoint sh "$IMG_CHECKOV" -c "checkov -d '$W/.github' --output json > '$E/checkov_${SYS}_${D}.json'" ;;
  # ZAP: στόχος = service container `juice` (native `services:`), στο δίκτυο του job (ZAP_NET)
  zap)     chmod 777 "$E"
           docker run --rm --network "${ZAP_NET:?}" -v "$W/$E:/out" --tmpfs /zap/wrk:rw,mode=1777 --entrypoint sh "$IMG_ZAP" -c \
             "cd /zap/wrk && zap-baseline.py -t http://juice:3000 -J zap.json; rc=\$?; cp zap.json /out/zap_${SYS}_${D}.json; exit \$rc" ;;
  *) echo "άγνωστο εργαλείο: $tool" >&2; exit 2 ;;
esac
rc=$?
echo "exit_${tool}=${rc}" >> "$E/exitcodes_${SYS}_${D}.txt"
echo "scanner ${tool}: exit=${rc} (καταγράφηκε· fail/allow = απόφαση του workflow)"
exit "$rc"
