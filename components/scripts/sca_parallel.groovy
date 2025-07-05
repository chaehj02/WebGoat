def call() {
    def jobs = [:]

    for (int i = 1; i <= 2; i++) {
        def index = i
        jobs["SCA-Run-${index}"] = {
            node("SCA-agent${index}") {
                stage("SCA-Run-${index}") {
                    sh "/home/ec2-user/run_sbom_pipeline.sh"
                }
            }
        }
    }

    parallel jobs
}
call()
