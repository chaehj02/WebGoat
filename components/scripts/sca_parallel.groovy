def runScaJobs() {
    def repoName = 'WebGoat'
    def repoUrl = "https://github.com/WH-Hourglass/${repoName}.git"
    def parallelCount = 2

    def jobs = [:]

    for (int i = 1; i <= parallelCount; i++) {
        def index = i
        def agent = "SCA-agent${(index % 2) + 1}"

        jobs["SCA-${repoName}-${index}"] = {
            node(agent) {
                stage("SCA ${repoName}-${index}") {
                    sh "bash components/scripts/run_sbom_pipeline.sh '${repoUrl}' '${repoName}' '${env.BUILD_ID}-${index}'"
                }
            }
        }
    }

    parallel jobs
}

return this
