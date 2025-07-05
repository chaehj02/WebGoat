#!/bin/bash

set -e

REPO_URL="$1"
REPO_NAME="$2"
BUILD_ID="$3"

if [[ -z "$REPO_URL" || -z "$REPO_NAME" ]]; then
    echo "❌ REPO_URL과 REPO_NAME을 인자로 전달해야 합니다."
    exit 1
fi

if [[ -z "$BUILD_ID" ]]; then
    BUILD_ID="$(date +%s%N)"
fi

echo "[+] 클린 작업: /tmp/${REPO_NAME} 제거"
rm -rf /tmp/${REPO_NAME}

echo "[+] Git 저장소 클론: ${REPO_URL}"
git clone "${REPO_URL}" "/tmp/${REPO_NAME}"

echo "[+] Java/언어 감지"
cd "/tmp/${REPO_NAME}"
bash /home/ec2-user/detect-java-version-bedrock.sh "$REPO_NAME" "$BUILD_ID"

IMAGE_TAG=$(cat /tmp/cdxgen_image_tag_${REPO_NAME}_${BUILD_ID}.txt)
echo "[+] 선택된 CDXGEN 이미지 태그: $IMAGE_TAG"

echo "[+] REPO_NAME: $REPO_NAME"
echo "[+] BUILD_ID: $BUILD_ID"

if [[ "$IMAGE_TAG" == "cli" ]]; then
    echo "[🚀] CDXGEN(CLI) 도커 실행"
    docker run --rm -v "$(pwd):/app" ghcr.io/cyclonedx/cdxgen:latest -o sbom_${REPO_NAME}_${BUILD_ID}.json
else
    echo "[🚀] CDXGEN(Java) 도커 실행 ($IMAGE_TAG)"
    docker run --rm -v "$(pwd):/app" ghcr.io/cyclonedx/cdxgen-"$IMAGE_TAG":latest -o sbom_${REPO_NAME}_${BUILD_ID}.json
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
bash /home/ec2-user/upload-sbom.sh "$REPO_NAME" "$BUILD_ID"
