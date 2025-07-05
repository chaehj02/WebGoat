def runScaJobs() {
    def repoName = 'WebGoat'
    def repoUrl = "https://github.com/WH-Hourglass/${repoName}.git"

    // 현재 작업 디렉토리 확인 (Jenkins의 WORKSPACE 환경 변수 사용)
    echo "현재 작업 디렉토리 확인:"
    echo "Jenkins Workspace: ${env.WORKSPACE}"
    
    def commitCount = sh(
        script: "git rev-list --count HEAD ^HEAD~10",  
        returnStdout: true
    ).trim().toInteger()

    // 병렬 최대 2회까지만
    def parallelCount = Math.min(commitCount, 2)

    def jobs = [:]

    for (int i = 1; i <= parallelCount; i++) {
        def index = i
        def agent = "SCA-agent${(index % 2) + 1}"

        jobs["SCA-${repoName}-${index}"] = {
            node(agent) {
                stage("SCA ${repoName}-${index}") {
                    echo "▶️ 병렬 SCA 실행 – 대상: ${repoName}, 인덱스: ${index}, Agent: ${agent}"

                    // WORKSPACE 환경 변수를 이용하여 스크립트 실행
                    echo "📌 Jenkins WORKSPACE 경로로 run_sbom_pipeline.sh 실행"
                    sh "${env.WORKSPACE}/components/scripts/run_sbom_pipeline.sh '${repoUrl}' '${repoName}' '${env.BUILD_ID}-${index}'"
                }
            }
        }
    }

    parallel jobs
}

return this
