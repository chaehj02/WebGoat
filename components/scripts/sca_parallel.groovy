def runScaJobs() {
    def repoName = 'WebGoat'
    def repoUrl = "https://github.com/WH-Hourglass/${repoName}.git"

    echo "📌 커밋 수 계산 중"
    def commitCount = sh(
        script: "git rev-list --count HEAD ^HEAD~10",
        returnStdout: true
    ).trim().toInteger()

    def parallelCount = Math.min(commitCount, 2) // 병렬 최대 2개
    def jobs = [:]

    for (int i = 1; i <= parallelCount; i++) {
        def index = i
        def agent = "SCA-agent${(index % 2) + 1}"

        jobs["SCA-${repoName}-${index}"] = {
            node(agent) {
                stage("SCA ${repoName}-${index}") {
                    echo "▶️ 병렬 SCA 실행 – 대상: ${repoName}, 인덱스: ${index}, Agent: ${agent}"

                    // 워크스페이스 위치 확인
                    sh "echo '현재 디렉토리:' && pwd && echo '📁 파일 목록:' && ls -al"

                    // 스크립트 위치 확인 및 권한 부여
                    def scriptPath = "${env.WORKSPACE}/components/scripts/run_sbom_pipeline.sh"
                    sh "ls -al ${scriptPath} || echo '❌ 스크립트 없음'"
                    sh "chmod +x ${scriptPath}"

                    // 실행
                    sh "${scriptPath} '${repoUrl}' '${repoName}' '${env.BUILD_ID}-${index}'"
                }
            }
        }
    }

    parallel jobs
}

return this
