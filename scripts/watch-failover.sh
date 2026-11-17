#!/usr/bin/env bash
# Polls the app URL every 5 seconds and prints which Region answered.
# Use it while running simulate-region-failure.sh to measure the real RTO.
set -euo pipefail
cd "$(dirname "$0")/../terraform"
URL=$(terraform output -raw app_url)
HC=$(terraform output -raw primary_health_check_id)

echo "Watching $URL (Ctrl+C to stop)"
while true; do
  ANSWER=$(curl -s -m 4 "$URL/api" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["region"], d["role"])' 2>/dev/null || echo "no answer")
  STATUS=$(aws route53 get-health-check-status --health-check-id "$HC" \
    --query 'length(HealthCheckObservations[?starts_with(StatusReport.Status, `Success`)])' --output text 2>/dev/null || echo "?")
  echo "$(date +%T)  app: $ANSWER   primary health checkers OK: $STATUS"
  sleep 5
done
