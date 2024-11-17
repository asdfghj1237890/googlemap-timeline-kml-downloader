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
  local base_delay=5
  local random_delay
  local count=0
  local batch_size=8
  local batch_pause=3600

  # Create base kml directory if it doesn't exist
  mkdir -p kml

  date_range "$from" "$to" | while IFS="-" read -r year month day; do
    if [ $((count % batch_size)) -eq 0 ] && [ $count -ne 0 ]; then
      local extended_pause=$((batch_pause + RANDOM % 1800))
      debug "Reached $batch_size requests. Pausing for $(($extended_pause / 60)) minutes..."
      sleep $extended_pause
    fi
    
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
    
    # Create year directory if it doesn't exist
    mkdir -p "kml/$year"
    local kmlfile="kml/$year/$year-$month-$day.kml"

    debug "GET $url -> $kmlfile"
    if download_kml "$cookies" "$url" >"$kmlfile"; then
      echo "$kmlfile downloaded successfully."
    else
      debug "Failed to download $kmlfile."
      # Remove empty or invalid KML file
      rm -f "$kmlfile"
    fi

    # Larger random delay range (2-5 minutes)
    random_delay=$(awk -v min=$base_delay -v max=300 'BEGIN{srand(); printf "%.2f", min + rand() * (max - min)}')
    
    # 33% chance to add extra random delay
    if [ $((RANDOM % 3)) -eq 0 ]; then
      random_delay=$(echo "$random_delay * 2.0" | bc)
      debug "Adding extra delay..."
    fi
    
    debug "Waiting for $random_delay seconds before next request..."
    sleep "$random_delay"
    count=$((count + 1))
  done
}

download_kml() {
  local cookies=$1
  local url=$2
  local attempt=1
  local max_attempts=3
  local wait_time=300

  local user_agents=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
  )

  while [ $attempt -le $max_attempts ]; do
    local random_agent=${user_agents[$RANDOM % ${#user_agents[@]}]}
    
    debug "Attempt $attempt of $max_attempts"
    debug "Requesting URL: $url"
    debug "Using User-Agent: $random_agent"
    debug "Starting request at $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Use temporary file to store response headers
    local headers_file=$(mktemp)
    
    response=$(curl -Ls -D "$headers_file" -w "%{http_code}|%{url_effective}" -o temp_response_body -b "$cookies" \
      -H "authority: timeline.google.com" \
      -H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7" \
      -H "accept-encoding: gzip, deflate, br, zstd" \
      -H "accept-language: en-US,en;q=0.9,zh-TW;q=0.8,zh;q=0.7,yue-HK;q=0.6,yue;q=0.5" \
      -H "sec-ch-ua: \"Google Chrome\";v=\"131\", \"Chromium\";v=\"131\", \"Not_A Brand\";v=\"24\"" \
      -H "sec-ch-ua-arch: \"x86\"" \
      -H "sec-ch-ua-bitness: \"64\"" \
      -H "sec-ch-ua-form-factors: \"Desktop\"" \
      -H "sec-ch-ua-full-version: \"131.0.6778.69\"" \
      -H "sec-ch-ua-full-version-list: \"Google Chrome\";v=\"131.0.6778.69\", \"Chromium\";v=\"131.0.6778.69\", \"Not_A Brand\";v=\"24.0.0.0\"" \
      -H "sec-ch-ua-mobile: ?0" \
      -H "sec-ch-ua-model: \"\"" \
      -H "sec-ch-ua-platform: \"Windows\"" \
      -H "sec-ch-ua-platform-version: \"10.0.0\"" \
      -H "sec-ch-ua-wow64: ?0" \
      -H "sec-fetch-dest: document" \
      -H "sec-fetch-mode: navigate" \
      -H "sec-fetch-site: none" \
      -H "sec-fetch-user: ?1" \
      -H "upgrade-insecure-requests: 1" \
      -H "user-agent: $random_agent" \
      -H "x-browser-channel: stable" \
      -H "x-browser-copyright: Copyright 2024 Google LLC. All rights reserved." \
      -H "x-browser-validation: QFEz3B6Z4AT6PlLzuts1mBxQGCM=" \
      -H "x-browser-year: 2024" \
      -H "x-client-data: CIm2yQEIprbJAQiKksoBCKmdygEI4InLAQiWocsBCIWgzQEIsZ7OAQj9pc4BCKrJzgEI+8nOAQiRys4BCIHMzgEIw8zOAQjFzM4BCMfPzgEI9M/OAQiu0M4BCOHQzgEYj87NARibsc4BGIDKzgEYk9DOARjr0M4B" \
      -H "priority: u=0, i" \
      "$url" --retry 2 --retry-delay 5 --compressed)

    # Parse HTTP status code and final URL from response
    http_code=$(echo "$response" | cut -d'|' -f1)
    final_url=$(echo "$response" | cut -d'|' -f2)
    
    debug "Initial URL: $url"
    debug "Final URL: $final_url"
    
    # Check various login-related redirects
    if echo "$final_url" | grep -qE "accounts.google.com/(ServiceLogin|InteractiveLogin)"; then
        debug "Cookie has expired or is invalid (redirected to login page)"
        debug "Please export a new cookies.txt file from your browser"
        rm -f "$headers_file" temp_response_body
        return 1
    fi
    
    if [ "$http_code" -eq 200 ]; then
        # Check if response content is HTML (instead of expected KML)
        if grep -q "<!doctype html>" temp_response_body; then
            debug "Received HTML instead of KML - likely a login page"
            debug "Please check your cookies.txt file"
            rm -f "$headers_file" temp_response_body
            return 1
        fi
        
        # Check if file is empty
        if [ ! -s temp_response_body ]; then
          debug "Empty response body received"
          rm -f "$headers_file"
          return 1
        fi
        
        # Check if response contains required KML content
        if grep -q "<?xml" temp_response_body && grep -q "<kml" temp_response_body; then
          # Ensure file size is above minimum threshold (e.g., 100 bytes)
          if [ $(wc -c < temp_response_body) -gt 100 ]; then
            debug "Valid KML content received"
            cat temp_response_body
            rm -f "$headers_file"
            return 0
          else
            debug "KML file too small, likely invalid"
            rm -f "$headers_file"
            return 1
          fi
        else
          debug "Invalid KML content received"
          debug "Content type check failed"
          rm -f "$headers_file"
          return 1
        fi
    elif [ "$http_code" -eq 429 ]; then
      debug "Rate limited (HTTP 429). Attempting backoff..."
      local sleep_time=$((wait_time * 2 ** (attempt - 1)))
      debug "Waiting ${sleep_time} seconds before retry..."
      sleep "$sleep_time"
      attempt=$((attempt + 1))
    else
      debug "Unexpected HTTP status code: $http_code"
      rm -f "$headers_file"
      return 1
    fi
    
    rm -f "$headers_file"
  done

  debug "Failed to download after $max_attempts attempts"
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