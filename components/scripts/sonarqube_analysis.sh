#!/bin/bash

echo "🔍 SonarQube 분석 시작"

echo "[💡 메모리 상태]"
free -h

echo "[💡 스왑 상태]"
swapon --show

echo "🔧 Maven compile"
${MAVEN_HOME}/bin/mvn compile -DskipTests

echo "🚀 SonarQube 분석 실행"
export NODE_OPTIONS=--max_old_space_size=2048

${SCANNER_HOME}/bin/sonar-scanner \
  -Dsonar.projectKey=webgoat \
  -Dsonar.sources=. \
  -Dsonar.java.binaries=target/classes \
  -Dsonar.host.url=${SONAR_HOST_URL} \
  -Dsonar.login=${SONARQUBE_ENV}

echo "📥 SonarQube 결과 수집"
TIMESTAMP=$(date +%F_%H-%M-%S)
REPORT_FILE="sonar_issues_${TIMESTAMP}.json"

curl -s -H "Authorization: Bearer ${SONARQUBE_ENV}" \
  "${SONAR_HOST_URL}/api/issues/search?componentKeys=webgoat" \
  -o ${REPORT_FILE}

echo "📤 S3 업로드"
aws s3 cp ${REPORT_FILE} s3://ss-bucket-0305/sonarqube-reports/${REPORT_FILE} --region ap-northeast-2
