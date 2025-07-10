#!/bin/bash
source ./dot.env
set -e

# 기본값
CONTAINER_NAME="${BUILD_TAG}"
REGION="${REGION:-ap-northeast-2}"
ECR_REPO="${ECR_REPO:?ECR_REPO를 설정하세요}"
IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG를 설정하세요}"
ZAP_SCRIPT="${ZAP_SCRIPT:-zap_scan.sh}"
ZAP_BIN="${ZAP_BIN:-$HOME/ZAP/zap.sh}"  # zap.sh 실행 경로
S3_BUCKET="${S3_BUCKET:-my-bucket}"
startpage="${1:-/}"

# 사용 가능한 웹앱 포트 찾기
for try_port in {8081..8089}; do
  in_use_lsof=$(lsof -iTCP:$try_port -sTCP:LISTEN -n -P 2>/dev/null)
  in_use_docker=$(docker ps --format '{{.Ports}}' | grep -w "$try_port")

  if [ -z "$in_use_lsof" ] && [ -z "$in_use_docker" ]; then
    port=$try_port
    zap_port=$((port + 10))
    break
  fi
done


if [ -z "$port" ]; then
  echo "❌ 사용 가능한 포트가 없습니다 (8081~8089)"
  exit 1
fi

# 동적 변수 설정
containerName="${BUILD_TAG}"
zap_pidfile="zap_${zap_port}.pid"
zap_log="zap_${zap_port}.log"
zapJson="zap_test_${BUILD_TAG}.json"
timestamp=$(date +"%Y%m%d_%H%M%S")
s3_key="default/zap_test_${BUILD_TAG}.json"

echo "[*] 웹앱 컨테이너: $containerName (포트 $port)"
echo "[*] ZAP 데몬: zap.sh (포트 $zap_port)"

echo "[*] Docker 로그인 및 Pull"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REPO"
docker pull "$ECR_REPO:${IMAGE_TAG}"

echo "[*] 웹앱 컨테이너 실행"
docker run -d --name "$containerName" -p "${port}:8080" "$ECR_REPO:${IMAGE_TAG}"

echo "[*] 웹앱 Health Check..."
for j in {1..15}; do
  if curl -s "http://localhost:$port" > /dev/null; then
    echo "✅ 웹앱 기동 완료 ($port)"
    break
  fi
  sleep 2
done

if [ $j -eq 15 ]; then
  echo "❌ 웹앱 기동 실패"
  docker logs "$containerName"
  exit 1
fi

echo "[*] ZAP 데몬 실행 중..."
nohup "$ZAP_BIN" -daemon -port "$zap_port" -host 0.0.0.0 -config api.disablekey=true > "$zap_log" 2>&1 &
echo $! > "$zap_pidfile"
sleep 5

echo "[*] ZAP 스크립트 실행 ($ZAP_SCRIPT)"
chmod +x ~/"$ZAP_SCRIPT"
~/"$ZAP_SCRIPT" "$containerName" "$zap_port" "$startpage"

if [ ! -f ~/zap_test.json ]; then
  echo "❌ ZAP 결과 파일이 존재하지 않습니다."
  exit 1
fi

echo "[*] 결과 파일 저장"
cp ~/zap_test.json "$zapJson"
cp "$zapJson" zap_test.json

echo "[*] S3 업로드"
if aws s3 cp zap_test.json "s3://${S3_BUCKET}/${s3_key}" --region "$REGION"; then
  echo "✅ S3 업로드 완료 → s3://${S3_BUCKET}/${s3_key}"
else
  echo "⚠️ S3 업로드 실패 (무시)"
fi

echo "[*] 정리 중..."
docker rm -f "$containerName" 2>/dev/null && echo "🧹 웹앱 컨테이너 제거 완료" || echo "⚠️ 웹앱 컨테이너 제거 실패"

if [ -f "$zap_pidfile" ]; then
  kill "$(cat "$zap_pidfile")" && echo "🧹 ZAP 데몬 종료 완료" || echo "⚠️ ZAP 데몬 종료 실패"
  rm -f "$zap_pidfile"
fi
