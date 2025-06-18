// SonarQube 분석 시작
def scannerHome = tool 'MySonarScanner'
def mvnHome = tool 'Maven3'

sh 'echo "[💡 메모리 상태]" && free -h && echo "[💡 스왑 상태]" && swapon --show'

withSonarQubeEnv(env.SONARQUBE_ENV) {
    sh """
    export NODE_OPTIONS=--max_old_space_size=2048
    ${scannerHome}/bin/sonar-scanner \
        -Dsonar.projectKey=webgoat \
        -Dsonar.sources=. \
        -Dsonar.java.binaries=target/classes
    """
}

// SonarQube API 결과 수집 및 파일 저장
withSonarQubeEnv(env.SONARQUBE_ENV) {
    script {
        def timestamp = sh(script: "date +%F_%H-%M-%S", returnStdout: true).trim()
        env.REPORT_FILE = "sonar_issues_${timestamp}.json"

        sh """
        curl -s -H "Authorization: Bearer $SONAR_AUTH_TOKEN" \\
          "$SONAR_HOST_URL/api/issues/search?componentKeys=webgoat" \\
          -o ${env.REPORT_FILE}
        """
    }
}

// S3로 업로드
sh """
aws s3 cp ${env.REPORT_FILE} s3://ss-bucket-0305/sonarqube-reports/${env.REPORT_FILE} --region ${env.REGION}
"""