#!/bin/bash
source ./dot.env
set -e

# 기본값 설정
CONTAINER_NAME="${CONTAINER_NAME:-webgoat}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
REGION="${REGION:-ap-northeast-2}"
ECR_REPO="${ECR_REPO}"
ZAP_SCRIPT="${ZAP_SCRIPT:-zap_webgoat.sh}"
S3_BUCKET="${S3_BUCKET:-my-bucket}"

# 동적 변수 설정
containerName="${CONTAINER_NAME}-${BUILD_NUMBER}"
containerFile="container_name_${BUILD_NUMBER}.txt"
zapJson="zap_test_${BUILD_NUMBER}.json"
port=$((8080 + (BUILD_NUMBER % 1000)))
timestamp=$(date +"%Y%m%d_%H%M%S")
s3_key="default/zap_test_${timestamp}.json"

echo "[*] 컨테이너 이름: $containerName"
echo "$containerName" > "$containerFile"

echo "[*] Docker 로그인 및 Pull"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REPO"
docker pull "$ECR_REPO:${IMAGE_TAG}"

echo "[*] 컨테이너 실행 중..."
docker run -d --name "$containerName" -p "${port}:8080" "$ECR_REPO:${IMAGE_TAG}"

echo "[*] Health check..."
for j in {1..15}; do
  if curl -s "http://localhost:$port" > /dev/null; then
    echo "✅ 애플리케이션 기동 완료 ($port)"
    break
  fi
  sleep 2
done

echo "[*] ZAP 스크립트 실행 중..."
chmod +x ~/"$ZAP_SCRIPT"
~/"$ZAP_SCRIPT" "$containerName"

if [ ! -f ~/zap_test.json ]; then
  echo "❌ ZAP 결과 파일이 존재하지 않습니다."
  exit 1
fi

echo "[*] 결과 파일 저장"
cp ~/zap_test.json "$zapJson"
cp "$zapJson" zap_test.json

echo "[*] SecurityHub용 S3 업로드"
if aws s3 cp zap_test.json "s3://${S3_BUCKET}/${s3_key}" --region "$REGION"; then
    echo "✅ S3 업로드 완료 → s3://${S3_BUCKET}/${s3_key}"
else
    echo "⚠️ S3 업로드 실패 (무시)"
fi
