#!/usr/bin/env bash
# Exercise the platform end to end.
#
#   ./scripts/send-test-messages.sh <api_url> [count]        burst of messages -> watch KEDA scale the worker out
#   ./scripts/send-test-messages.sh <api_url> --poison        one failing message -> retried 5x -> DLQ -> alert
set -euo pipefail

API_URL="${1:?usage: $0 <api_url> [count|--poison]}"
MODE="${2:-50}"

curl --fail --silent --show-error "${API_URL}/health"
echo

if [[ "${MODE}" == "--poison" ]]; then
  curl --fail --silent --show-error -X POST "${API_URL}/webhook/message" \
    -H "Content-Type: application/json" \
    -d '{"channel":"whatsapp","text":"this one fails","simulate_failure":true}'
  echo
  echo "Sent a poison message. After max_delivery_count attempts it moves to the DLQ;"
  echo "the metric alert fires within ~5 minutes."
  exit 0
fi

for i in $(seq 1 "${MODE}"); do
  curl --fail --silent --show-error -o /dev/null -X POST "${API_URL}/webhook/message" \
    -H "Content-Type: application/json" \
    -d "{\"channel\":\"web\",\"customer_id\":\"c-${i}\",\"text\":\"hello #${i}\"}" &
  if (( i % 20 == 0 )); then wait; fi
done
wait
echo "Sent ${MODE} messages. Watch replicas with:"
echo "  az containerapp replica list -g <rg> -n <worker-app> -o table"
