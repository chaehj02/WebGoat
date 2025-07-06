def runScaJobs() {
    def repoName = 'WebGoat'
    def repoUrl = "https://github.com/WH-Hourglass/${repoName}.git"

    echo "📌 run_sbom_pipeline.sh 파일 경로 찾기"
    def scriptPath = sh(
        script: "find ${env.WORKSPACE} -name 'run_sbom_pipeline.sh' -print -quit", 
        returnStdout: true
    ).trim()

    echo "📌 run_sbom_pipeline.sh 경로: ${scriptPath}"

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
                    sh "./run_sbom_pipeline.sh '${repoUrl}' '${repoName}' '${env.BUILD_ID}-${index}'"

                }
            }
        }
    }

    parallel jobs
}

return this
