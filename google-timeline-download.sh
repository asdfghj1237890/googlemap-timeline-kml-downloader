#!/bin/bash
set -e -u -o pipefail

# Usage: Export a cookies.txt file from a browser logged-in in timeline.google.com with some
#   add-on/extension (i.e., Export cookies, Get cookies.txt). Now run the script for the
#   desired period:
#
#    $ bash google-timeline-download.sh cookies.txt 2022-01-01 2022-02-20
#
# Dependencies: curl.
#
# Each KML file will be saved individually with the date as its filename.
#
# Example KML Viewer: https://kmlviewer.nsspot.net

debug() {
  echo "$@" >&2
}

date_range() {
  local from=$1 to=$2
  local days=$(( ($(date '+%s' -d "$to") - $(date '+%s' -d "$from")) / (60 * 60 * 24) ))

  seq 0 $days | while read -r days_offset; do
    date -d "$from + $days_offset days" "+%Y-%m-%d"
  done
}

download_kml_files() {
  local cookies=$1 from=$2 to=$3
  local base_delay=1  # Base delay in seconds
  local random_delay

  date_range "$from" "$to" | while IFS="-" read -r year month day; do
    local month0=$((10#$month - 1)) # 0-index month
    local day0=$((10#$day))         # The day arguments must not contain leading zeros
    local pb_ary=(
      "!1m8"
      "!1m3"
      "!1i$year!2i$month0!3i$day0"
      "!2m3"
      "!1i$year!2i$month0!3i$day0"
    )
    local pb=$(echo "${pb_ary[@]}" | tr -d " ")
    local url="https://timeline.google.com/maps/timeline/kml?authuser=0&pb=${pb}"
    local kmlfile="$year-$month-$day.kml"

    debug "GET $url -> $kmlfile"
    if download_kml "$cookies" "$url" >"$kmlfile"; then
      echo "$kmlfile downloaded successfully."
    else
      debug "Failed to download $kmlfile."
    fi

    # Add random delay between requests to avoid hitting rate limits
    # Randomization helps prevent predictable request patterns
    random_delay=$(awk -v min=$base_delay -v max=$((base_delay + 2)) 'BEGIN{srand(); printf "%.2f", min + rand() * (max - min)}')
    sleep "$random_delay"
  done
}

download_kml() {
  local cookies=$1 url=$2
  local attempt=1
  local max_attempts=5
  local wait_time=2  # Initial wait time in seconds

  while [ $attempt -le $max_attempts ]; do
    # Make the request and capture headers
    response=$(curl -L -k -sS -D - -o temp_response_body -b "$cookies" "$url" --retry 3 --retry-delay 2)
    http_code=$(echo "$response" | grep HTTP | tail -1 | awk '{print $2}')
    retry_after=$(echo "$response" | grep -i "Retry-After:" | awk '{print $2}')

    if [ "$http_code" -eq 200 ]; then
      # Success - return the response body
      cat temp_response_body
      rm -f temp_response_body
      return 0
    elif [ "$http_code" -eq 429 ]; then
      # HTTP 429 = "Too Many Requests" - Server is rate limiting us
      # Use server's Retry-After header if provided, otherwise use our wait_time
      if [ -n "$retry_after" ]; then
        wait_time=$retry_after
      fi
      debug "Rate limit hit (HTTP 429). Attempt $attempt/$max_attempts. Waiting for $wait_time seconds before retrying..."
      sleep $wait_time
      wait_time=$((wait_time * 2))  # Exponential backoff to gradually increase delays
      attempt=$((attempt + 1))
    else
      debug "Unexpected HTTP status code: $http_code"
      rm -f temp_response_body
      return 1
    fi
  done

  debug "Failed to download after $max_attempts attempts due to rate limiting."
  rm -f temp_response_body
  return 1
}

main() {
  if [ $# -ne 3 ]; then
    echo "Usage: $(basename "$0") COOKIES.txt FROM(YYYY-MM-DD) TO(YYYY-MM-DD)"
    exit 2
  else
    download_kml_files "$1" "$2" "$3"
  fi
}

main "$@"