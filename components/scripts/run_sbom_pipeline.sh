#!/bin/bash

set -e

REPO_URL="$1"
REPO_NAME="$2"

if [[ -z "$REPO_URL" || -z "$REPO_NAME" ]]; then
    echo "❌ REPO_URL과 REPO_NAME을 인자로 전달해야 합니다."
    exit 1
fi

echo "[+] 클린 작업: /tmp/${REPO_NAME} 제거"
rm -rf /tmp/${REPO_NAME}

echo "[+] Git 저장소 클론: ${REPO_URL}"
git clone "${REPO_URL}" "/tmp/${REPO_NAME}"

echo "[+] Java/언어 감지"
cd "/tmp/${REPO_NAME}"
bash /home/ec2-user/detect-java-version-bedrock.sh "$REPO_NAME"

IMAGE_TAG=$(cat /tmp/cdxgen_image_tag.txt)
echo "[+] 선택된 CDXGEN 이미지 태그: $IMAGE_TAG"

if [[ "$IMAGE_TAG" == "cli" ]]; then
    echo "[🚀] CDXGEN(CLI) 도커 실행"
    docker run --rm -v "$(pwd):/app" ghcr.io/cyclonedx/cdxgen:latest -o sbom.json
else
    echo "[🚀] CDXGEN(Java) 도커 실행 ($IMAGE_TAG)"
    docker run --rm -v "$(pwd):/app" ghcr.io/cyclonedx/cdxgen-"$IMAGE_TAG":latest -o sbom.json
fi

echo "[+] Dependency-Track 컨테이너 상태 확인"
if docker ps --format '{{.Names}}' | grep -q '^dependency-track$'; then
    echo "[+] Dependency-Track 컨테이너 실행 중"
elif docker ps -a --format '{{.Names}}' | grep -q '^dependency-track$'; then
    echo "[+] Dependency-Track 멈춤 상태 → 기동"
    docker start dependency-track
else
    echo "[+] Dependency-Track 컨테이너 없음 → 새 기동"
    docker run -d --name dependency-track -p 8080:8080 dependencytrack/bundled:latest
fi

echo "[+] Dependency-Track 업로드"
bash /home/ec2-user/upload-sbom.sh "$REPO_NAME"

echo "[🔍] 가드레일 검사 시작"

PROJECT_NAME="$REPO_NAME"
API_KEY="YOUR_DEPENDENCY_TRACK_API_KEY"
SERVER="http://localhost:8080"
WAIT_SEC=10
MAX_RETRY=30

PROJECT_UUID=$(curl -s -X GET "$SERVER/api/v1/project?searchText=$PROJECT_NAME" \
  -H "X-Api-Key: $API_KEY" | jq -r '.[0].uuid')

if [[ -z "$PROJECT_UUID" || "$PROJECT_UUID" == "null" ]]; then
    echo "❌ 프로젝트 UUID 조회 실패"
    exit 1
fi

echo "[+] 프로젝트 UUID: $PROJECT_UUID"

for i in $(seq 1 $MAX_RETRY); do
    echo "[⏳] 취약점 분석 대기 중... (${i}/${MAX_RETRY})"
    FINDINGS=$(curl -s -X GET "$SERVER/api/v1/finding/project/$PROJECT_UUID" \
      -H "X-Api-Key: $API_KEY")

    CRITICAL_COUNT=$(echo "$FINDINGS" | jq '[.[] | select(.vulnerability.cvssV3.baseScore >= 9.0)] | length')
    HIGH_COUNT=$(echo "$FINDINGS" | jq '[.[] | select(.vulnerability.cvssV3.baseScore >= 7.0 and .vulnerability.cvssV3.baseScore < 9.0)] | length')

    if [[ "$CRITICAL_COUNT" -gt 0 || "$HIGH_COUNT" -gt 0 ]]; then
        break
    fi
    sleep $WAIT_SEC
done

echo "[+] Critical 취약점: $CRITICAL_COUNT개"
echo "[+] High 취약점: $HIGH_COUNT개"

if [[ "$CRITICAL_COUNT" -ge 1 ]]; then
    echo "❌ [가드레일 실패] Critical 취약점이 $CRITICAL_COUNT개 존재합니다."
    exit 1
elif [[ "$HIGH_COUNT" -ge 4 ]]; then
    echo "❌ [가드레일 실패] High 취약점이 $HIGH_COUNT개 존재합니다."
    exit 1
elif [[ "$HIGH_COUNT" -ge 1 ]]; then
    echo "⚠️ [가드레일 경고] High 취약점이 $HIGH_COUNT개 존재합니다. 빌드는 통과합니다."
else
    echo "✅ [가드레일 통과] 심각한 취약점 없음"
fi
