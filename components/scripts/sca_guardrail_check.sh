#!/bin/bash
set -e

PROJECT_NAME="$1"
DEPTRACK_API_KEY="$2"
DEPTRACK_URL="$3"

INPUT_FILE="lambda_input.json"
OUTPUT_FILE="lambda_result.json"

cat <<EOF > "$INPUT_FILE"
{
  "project_name": "${PROJECT_NAME}",
  "api_key": "${DEPTRACK_API_KEY}",
  "server": "${DEPTRACK_URL}"
}
EOF

aws lambda invoke \
  --function-name sca_guardrail \
  --payload fileb://$INPUT_FILE \
  $OUTPUT_FILE

STATUS=$(jq -r '.status' $OUTPUT_FILE)

echo "[+] Lambda 결과 상태: $STATUS"

if [[ "$STATUS" == "fail" ]]; then
  echo "❌ 가드레일 통과 실패 (OWASP Top 10 관련 취약점 존재)"
  exit 1
else
  echo "✅ 가드레일 통과"
fi

