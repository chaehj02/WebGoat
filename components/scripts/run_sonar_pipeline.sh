#!/bin/bash
set -e

echo "--- [🧪 디버깅] 수신된 환경 변수 확인 ---"
echo "SONAR_HOST_URL: [${SONAR_HOST_URL:-'값이 비어있음'}]"
echo "SONAR_AUTH_TOKEN 길이: [${#SONAR_AUTH_TOKEN}]"
echo "SONAR_AUTH_TOKEN 일부: [${SONAR_AUTH_TOKEN:0:4}****]" 
echo "-------------------------------------------"

# 🛠️ 도구 경로 설정
echo "[🧪 DEBUG] PATH에 SonarScanner 추가"
export PATH=$PATH:/opt/sonar-scanner/bin

SCANNER_HOME="/opt/sonar-scanner/bin/sonar-scanner"
echo "[🧪 DEBUG] SonarScanner 경로: $SCANNER_HOME"

MVN_HOME=$(which mvn)
echo "[🧪 DEBUG] Maven 경로: $MVN_HOME"
$MVN_HOME -v || { echo "[❌ ERROR] Maven 동작 확인 실패"; exit 1; }

# 📦 Maven 의존성 복사 (테스트 제외)
echo "[*] Maven compile + dependency 복사 시작..."
if $MVN_HOME compile dependency:copy-dependencies -DoutputDirectory=target/dependency -DskipTests; then
  echo "[✔] Maven 컴파일 및 복사 완료"
else
  echo "[❌ ERROR] Maven 컴파일 실패"
  exit 1
fi

# 🧪 SonarQube 분석
echo "[*] SonarQube 분석 시작..."
export NODE_OPTIONS=--max_old_space_size=4096

if $SCANNER_HOME \
  -Dsonar.projectKey=webgoat \
  -Dsonar.sources=. \
  -Dsonar.java.binaries=target/classes \
  -Dsonar.java.libraries=target/dependency/*.jar \
  -Dsonar.python.version=3.9 \
  -Dsonar.token=$SONAR_AUTH_TOKEN; then
  echo "[✔] SonarQube 분석 완료"
else
  echo "[❌ ERROR] SonarQube 분석 실패"
  exit 1
fi

# 📄 분석 결과 API로 수집
timestamp=$(date +%F_%H-%M-%S)
REPORT_FILE="sonar_issues_${timestamp}.json"

echo "[*] 분석 결과 API 호출 및 저장 중: $REPORT_FILE"
if curl -s -H "Authorization: Bearer $SONAR_AUTH_TOKEN" \
     "$SONAR_HOST_URL/api/issues/search?componentKeys=webgoat" \
     -o "$REPORT_FILE"; then
  echo "[✔] 분석 결과 저장 완료"
else
  echo "[⚠️ WARN] 분석 결과 저장 실패"
fi

# ☁️ S3 업로드
S3_BUCKET="ss-bucket-0305"
echo "[*] S3 업로드 시작..."
if aws s3 cp "$REPORT_FILE" "s3://${S3_BUCKET}/sonarqube-reports/$REPORT_FILE" --region ap-northeast-2; then
  echo "✅ S3 업로드 완료"
else
  echo "⚠️ S3 업로드 실패 (무시됨)"
fi

echo "[🎉 완료] SonarQube 분석 → API 수집 → S3 업로드 완료"
