def call() {
    def jobs = [:]

    for (int i = 1; i <= 2; i++) {
        def index = i  // 클로저 내 변수 캡처 방지
        jobs["SCA-Run-${index}"] = {
            stage("SCA-Run-${index}") {
                sh "/home/ec2-user/run_sbom_pipeline.sh"
            }
        }
    }

    parallel jobs
}
