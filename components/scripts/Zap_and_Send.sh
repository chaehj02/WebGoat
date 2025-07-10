#!/bin/bash
source ./dot.env

# 기본값
CONTAINER_NAME="${BUILD_TAG}"
REGION="${REGION:-ap-northeast-2}"
ECR_REPO="${ECR_REPO:?ECR_REPO를 설정하세요}"
IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG를 설정하세요}"
ZAP_SCRIPT="zap_scan.sh"
ZAP_BIN="${ZAP_BIN:-$HOME/ZAP/zap.sh}" # zap.sh 실행 경로
S3_BUCKET="${S3_BUCKET:-my-bucket}"
startpage="${1:-}"

echo "DEBUG: 변수 설정 완료"

for try_port in {8081..8089}; do
  echo "[DEBUG] 시도 중: $try_port"

  set +e
  lsof_stdout=$(lsof -iTCP:$try_port -sTCP:LISTEN -n -P 2>/dev/null)
  lsof_exit_code=$?
  set -e

  echo "[DEBUG] lsof 종료 코드: $lsof_exit_code"
  echo "[DEBUG] lsof 출력: $lsof_stdout"

  # "포트 사용 안 함" 상황 → 정상 처리
  if [ $lsof_exit_code -ne 0 ] && [ -z "$lsof_stdout" ]; then
    echo "[DEBUG] 포트 $try_port 는 사용 중 아님 (lsof 정상)"
  elif [ $lsof_exit_code -ne 0 ]; then
    echo "🚨 Error: lsof 명령 실패 (예외 상황)"
    exit 1
  fi

  # 이 포트가 사용 중이면 다음 포트로
  if [ -n "$lsof_stdout" ]; then
    continue
  fi

  # docker 검사
  in_use_docker=""
  docker_output=$(docker ps --format '{{.Ports}}' 2>/dev/null || true)
  if echo "$docker_output" | grep -E "[0-9\.]*:$try_port->" >/dev/null; then
    in_use_docker=1
  fi
  echo "[DEBUG] docker 결과: $in_use_docker"

  if [ -z "$in_use_docker" ]; then
    port=$try_port
    echo "[DEBUG] 사용 가능한 포트 발견: $port"

    if [[ "$port" =~ ^[0-9]+$ ]]; then
      zap_port=$((port + 10))
      echo "[DEBUG] ZAP 포트: $zap_port"
    else
      echo "🚨 Error: port 값이 숫자가 아님: '$port'"
      exit 1
    fi
    break
  fi
done



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



echo "[*] ZAP 데몬 실행 중..."
nohup "$ZAP_BIN" -daemon -port "$zap_port" -host 0.0.0.0 -config api.disablekey=true >"$zap_log" 2>&1 &
echo $! >"$zap_pidfile"
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
