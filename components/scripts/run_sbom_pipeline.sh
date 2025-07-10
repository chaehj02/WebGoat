#!/bin/bash
set -e

REPO_URL="$1"
REPO_NAME="$2"
BUILD_ID="$3"

# --- 추가된 환경 변수 파싱 (--env 옵션) ---
ENV_MODE="dev"
for i in "${!@}"; do
  if [[ "${!i}" == "--env" ]]; then
    ENV_MODE="${!((i+1))}"
  fi
done

if [[ -z "$REPO_URL" || -z "$REPO_NAME" ]]; then
    echo "❌ REPO_URL과 REPO_NAME을 인자로 전달해야 합니다."
    exit 1
fi

if [[ -z "$BUILD_ID" ]]; then
    BUILD_ID="$(date +%s%N)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

echo "[+] 실행 환경: $ENV_MODE"
echo "[+] 클린 작업: /tmp/${REPO_NAME} 제거"
rm -rf "/tmp/${REPO_NAME}"

echo "[+] Git 저장소 클론: ${REPO_URL}"
git clone "$REPO_URL" "/tmp/${REPO_NAME}"

detect_java_version "$REPO_NAME" "$BUILD_ID"

IMAGE_TAG=$(cat "/tmp/cdxgen_image_tag_${REPO_NAME}_${BUILD_ID}.txt")
echo "[+] 선택된 CDXGEN 이미지 태그: $IMAGE_TAG"
echo "[+] REPO_NAME: $REPO_NAME"
echo "[+] BUILD_ID: $BUILD_ID"

cd "/tmp/${REPO_NAME}"

if [[ "$IMAGE_TAG" == "cli" ]]; then
    echo "[🚀] CDXGEN(CLI) 도커 실행"
    docker run --rm -v "$(pwd):/app" ghcr.io/cyclonedx/cdxgen:lat
