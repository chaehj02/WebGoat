def runScaJobs() {
    // 워크스페이스 내 최상위 디렉토리 목록 추출
    def targets = sh(
        script: "ls -d */ | sed 's#/##'",
        returnStdout: true
    ).trim().split('\n')

    if (targets.size() <= 1) {
        node('SCA') {
            stage("SCA for ${targets[0]}") {
                echo "▶️ 단일 작업 실행: ${targets[0]}"
                sh "bash components/scripts/run_sbom_pipeline.sh 'https://github.com/WH-Hourglass/${targets[0]}.git' '${targets[0]}' '${env.BUILD_ID}'"
            }
        }
    } else {
        def jobs = targets.collectEntries { target ->
            ["${target}": {
                node('SCA') {
                    stage("SCA for ${target}") {
                        echo "▶️ 병렬 작업 실행: ${target}"
                        sh "bash components/scripts/run_sbom_pipeline.sh 'https://github.com/WH-Hourglass/${target}.git' '${target}' '${env.BUILD_ID}'"
                    }
                }
            }]
        }
        parallel jobs
    }
}

return this
