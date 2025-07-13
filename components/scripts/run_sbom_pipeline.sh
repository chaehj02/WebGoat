#!/bin/bash
set -e

REPO_URL="$1"
REPO_NAME="$2"
BUILD_ID="$3"
COMMIT_ID="$4"  # 병렬 실행 시 커밋 ID 전달됨

if [[ -z "$REPO_URL" || -z "$REPO_NAME" ]]; then
    echo "❌ REPO_URL과 REPO_NAME을 인자로 전달해야 합니다."
    exit 1
fi

if [[ -z "$BUILD_ID" ]]; then
    BUILD_ID="$(date +%s%N)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

REPO_DIR="/tmp/${REPO_NAME}_${BUILD_ID}"
LOG_FILE="/tmp/sbom_runlog_${REPO_NAME}_${BUILD_ID}.log"

mkdir -p "$REPO_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "📌 로그 기록 시작: $LOG_FILE"
echo "[+] 클린 작업: ${REPO_DIR} 제거"
rm -rf "$REPO_DIR"

echo "[+] Git 저장소 클론: ${REPO_URL} → ${REPO_DIR}"
git clone "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

if [[ -n "$COMMIT_ID" ]]; then
    echo "[+] 커밋 체크아웃: $COMMIT_ID"
    git checkout "$COMMIT_ID"
fi

detect_java_version "$REPO_NAME" "$BUILD_ID"

IMAGE_TAG=$(cat "/tmp/cdxgen_image_tag_${REPO_NAME}_${BUILD_ID}.txt")
echo "[+] 선택된 CDXGEN 이미지 태그: $IMAGE_TAG"

SBOM_FILE="${REPO_DIR}/sbom_${REPO_NAME}_${BUILD_ID}.json"

if [[ "$IMAGE_TAG" == "cli" ]]; then
    echo "[🚀] CDXGEN(CLI) 도커 실행"
    docker run --rm -v "${REPO_DIR}:/app" ghcr.io/cyclonedx/cdxgen:latest -o "$SBOM_FILE"
else
    echo "[🚀] CDXGEN(Java) 도커 실행 ($IMAGE_TAG)"
    docker run --rm -v "${REPO_DIR}:/app" ghcr.io/cyclonedx/cdxgen-${IMAGE_TAG}:latest -o "$SBOM_FILE"
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

upload_sbom "$REPO_NAME" "$BUILD_ID" "$REPO_DIR"

echo "[✅] SBOM 파이프라인 완료"
