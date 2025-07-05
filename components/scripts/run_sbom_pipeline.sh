#!/bin/bash
set -e

# ========== 인라인 함수 정의 ==========
detect_java_version() {
    echo "[+] Java/언어 감지"

    # Maven, Gradle, SBT, jar 여부 탐지
    if [[ -f "pom.xml" ]]; then
        JAVA_VERSION="java"
    elif [[ -f "build.gradle" ]]; then
        JAVA_VERSION="gradle"
    elif [[ -f "build.sbt" ]]; then
        JAVA_VERSION="sbt"
    elif [[ -f *.jar ]]; then
        JAVA_VERSION="jar"
    else
        JAVA_VERSION="cli"
    fi

    echo "[+] 감지된 Java 버전: $JAVA_VERSION"
    echo "$JAVA_VERSION" > /tmp/cdxgen_image_tag_${REPO_NAME}_${BUILD_ID}.txt
}

upload_sbom() {
    SBOM_FILE="sbom_${REPO_NAME}_${BUILD_ID}.json"
    PROJECT_VERSION="${BUILD_ID}_$(date +%Y%m%d_%H%M%S)"

    echo "[+] Dependency-Track 업로드"
    curl -X POST http://localhost:8080/api/v1/bom \
        -H "X-Api-Key: $DT_API_KEY" \
        -F "projectName=$REPO_NAME" \
        -F "projectVersion=$PROJECT_VERSION" \
        -F "bom=@$SBOM_FILE" \
        -F "autoCreate=true"
}
# =======================================

# ========== 매개변수 처리 ==========
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
# ===================================

# 클린 작업 및 Git clone
echo "[+] 클린 작업: /tmp/${REPO_NAME} 제거"
rm -rf /tmp/${REPO_NAME}

echo "[+] Git 저장소 클론: ${REPO_URL}"
git clone "${REPO_URL}" "/tmp/${REPO_NAME}"

# 진입
cd "/tmp/${REPO_NAME}"

# 인라인 함수 호출
detect_java_version
IMAGE_TAG=$(cat /tmp/cdxgen_image_tag_${REPO_NAME}_${BUILD_ID}.txt)
echo "[+] 선택된 CDXGEN 이미지 태그: $IMAGE_TAG"

echo "[+] REPO_NAME: $REPO_NAME"
echo "[+] BUILD_ID: $BUILD_ID"

# CDXGEN 실행
if [[ "$IMAGE_TAG" == "cli" ]]; then
    echo "[🚀] CDXGEN(CLI) 도커 실행"
    docker run --rm -v "$(pwd):/app" ghcr.io/cyclonedx/cdxgen:latest -o sbom_${REPO_NAME}_${BUILD_ID}.json
else
    echo "[🚀] CDXGEN(Java) 도커 실행 ($IMAGE_TAG)"
    docker run --rm -v "$(pwd):/app" ghcr.io/cyclonedx/cdxgen-"$IMAGE_TAG":latest -o sbom_${REPO_NAME}_${BUILD_ID}.json
fi

# Dependency-Track 컨테이너 확인 및 실행
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

# 업로드 실행
upload_sbom
