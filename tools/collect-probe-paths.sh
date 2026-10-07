#!/usr/bin/env bash
# Collect unique request paths that returned 403 or 404 from nginx access logs.
# Output: count + path, sorted by count descending. Fetch the file via SFTP/SCP for analysis.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: collect-probe-paths.sh [-o FILE] [LOG ...]

  -o FILE   Write results to FILE (default: probe-paths-YYYYMMDD.txt)
  -h        Show this help

Writes the path list only to FILE. The terminal shows a short success
line with the number of unique paths. With no LOG arguments, searches
typical nginx / DirectAdmin locations. Status codes: 403 and 404.
EOF
}

OUTFILE=""
while getopts ":o:h" opt; do
  case "$opt" in
    o) OUTFILE=$OPTARG ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# Extract path from Combined Log lines with status 403 or 404 (query string removed).
extract_paths() {
  awk '
  {
    q = index($0, "\"")
    if (q == 0) next
    rest = substr($0, q + 1)
    sp = index(rest, " ")
    if (sp == 0) next
    rest = substr(rest, sp + 1)
    path = ""
    for (i = 1; i <= length(rest); i++) {
      c = substr(rest, i, 1)
      if (c == " " || c == "?") {
        path = substr(rest, 1, i - 1)
        rest = substr(rest, i)
        break
      }
    }
    if (path == "") next
    q2 = index(rest, "\"")
    if (q2 == 0) next
    rest = substr(rest, q2 + 1)
    sub(/^[ \t]+/, "", rest)
    status = substr(rest, 1, 3)
    if (status == "403" || status == "404") {
      print path
    }
  }
  '
}

# Read one log file (plain or .gz) to stdout.
cat_log() {
  local f=$1
  case "$f" in
    *.gz) gzip -dc -- "$f" 2>/dev/null || true ;;
    *) cat -- "$f" 2>/dev/null || true ;;
  esac
}

# True if the file name looks like a webserver access log (not error/bytes/app).
is_access_log() {
  local base
  base=$(basename -- "$1")
  case "$base" in
    *error*|*bytes*|system.log|system.log.*|task-output*) return 1 ;;
  esac
  case "$base" in
    access.log|access.log.*|*access.log|*access.log.*) return 0 ;;
    *.log|*.log.gz|*.log.[0-9]*|*.log.[0-9]*.gz) return 0 ;;
  esac
  return 1
}

collect_default_logs() {
  # Webserver access logs only — not October/Contao/Symfony app logs under public_html.
  # DirectAdmin nginx: /var/log/nginx/domains/example.com.log
  # DirectAdmin per-domain: /home/USER/domains/DOMAIN/logs/*  (exact depth, not storage/logs)
  {
    if [[ -d /var/log/nginx ]]; then
      find /var/log/nginx -type f 2>/dev/null || true
    fi
    if [[ -d /home ]]; then
      find /home -mindepth 5 -maxdepth 5 -type f \
        -path '/home/*/domains/*/logs/*' 2>/dev/null || true
    fi
  } | while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    if is_access_log "$f"; then
      printf '%s\n' "$f"
    fi
  done | sort -u
}

LOG_FILES=()
if [[ $# -gt 0 ]]; then
  for arg in "$@"; do
    if [[ -f "$arg" ]]; then
      LOG_FILES+=("$arg")
    else
      # shellcheck disable=SC2086
      for f in $arg; do
        [[ -f "$f" ]] && LOG_FILES+=("$f")
      done
    fi
  done
else
  while IFS= read -r f; do
    [[ -n "$f" ]] && LOG_FILES+=("$f")
  done < <(collect_default_logs)
fi

if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
  cat >&2 <<'EOF'
No log files found.

DirectAdmin nginx logs are often named like:
  /var/log/nginx/domains/example.com.log

Locate them, then pass paths explicitly:
  sudo find /var/log/nginx /home -type f -name '*.log' 2>/dev/null | head
  sudo ./collect-probe-paths.sh -o /root/probe-paths.txt /var/log/nginx/domains/*.log
EOF
  exit 1
fi

if [[ -z "$OUTFILE" ]]; then
  OUTFILE="probe-paths-$(date +%Y%m%d).txt"
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

HOST=$(hostname 2>/dev/null || echo unknown)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)

{
  echo "# host: $HOST"
  echo "# generated: $NOW"
  echo "# status: 403 404"
  echo "# log files: ${#LOG_FILES[@]}"
  for f in "${LOG_FILES[@]}"; do
    echo "#   $f"
  done
  echo "#"

  for f in "${LOG_FILES[@]}"; do
    cat_log "$f"
  done | extract_paths | sort | uniq -c | sort -rn
} >"$TMP"

cp "$TMP" "$OUTFILE"
COUNT=$(awk '!/^#/ && NF { n++ } END { print n+0 }' "$OUTFILE")
echo "OK: $COUNT unique paths -> $OUTFILE"
