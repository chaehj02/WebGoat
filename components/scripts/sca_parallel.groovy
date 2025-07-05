echo "✅ SCA 병렬 실행 시작"

def jobs = [:]

for (int i = 1; i <= 2; i++) {
    def index = i
    jobs["SCA-Run-${index}"] = {
        node("SCA-agent${index}") {
            stage("SCA-Run-${index}") {
                sh "bash \$WORKSPACE/WebGoat/components/scripts/run_sbom_pipeline.sh https://github.com/WH-Hourglass/WebGoat.git WebGoat ${index}"
            }
        }
    }
}

parallel jobs
