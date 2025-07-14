pipeline {
    agent { label 'master' }

    environment {
        JAVA_HOME   = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH        = "${env.JAVA_HOME}/bin:${env.PATH}"
        SSH_CRED_ID = "WH_1_key"
        DYNAMIC_IMAGE_TAG = "dev-${env.BUILD_NUMBER}-${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
        REPO_URL = 'https://github.com/WH-Hourglass/WebGoat.git'
        BRANCH = 'SCA'
    }

    stages {

        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        }

        stage('🔨 Build JAR') {
            steps {
                sh 'components/scripts/Build_JAR.sh'
            }
        }

        stage('🚀 Generate SBOM for each commit') {
            steps {
                script {
                    // 변경된 커밋 목록 추출
                    def commits = sh(
                        script: "git log ${env.GIT_PREVIOUS_COMMIT}..${env.GIT_COMMIT} --pretty=format:'%H'",
                        returnStdout: true
                    ).trim().split("\n")

                    // 빈 항목 제거
                    commits = commits.findAll { it != null && it.trim() != "" }

                    // 변경된 커밋이 없을 경우 현재 HEAD로 대체
                    if (commits.size() == 0) {
                        echo "⚠️ 변경된 커밋이 없어 – HEAD 커밋(${env.GIT_COMMIT})으로 대체"
                        commits = [env.GIT_COMMIT]
                    }

                    echo "📌 처리할 커밋 목록 (${commits.size()}개):\n${commits.join('\n')}"

                    // 병렬 작업 정의
                    def jobs = [:]
                    def repoName = env.REPO_URL.tokenize('/').last().replace('.git', '')

                    for (int i = 0; i < commits.size(); i++) {
                        def index = i
                        def commitId = commits[index]
                        def buildId = "${env.BUILD_NUMBER}-${index}"
                        def shortHash = commitId.take(7)
                        def uniqueWorkspace = "workspace_${buildId}_${shortHash}"

                        // ✅ 병렬 고유화된 REPO_NAME 생성
                        def rname = "${repoName}_${buildId}_${shortHash}"
                        def repoUrl = env.REPO_URL

                        jobs["SBOM-${index}-${shortHash}"] = {
                            node('SCA') {
                                try {
                                    sh """
                                        echo "[+] SBOM 생성 시작: Commit ${shortHash}, Build ${buildId}"
                                        echo "[+] 작업 디렉터리: ${uniqueWorkspace}"

                                        rm -rf /tmp/${uniqueWorkspace} || true
                                        mkdir -p /tmp/${uniqueWorkspace}

                                        cd /tmp/${uniqueWorkspace}
                                        git clone --quiet --branch ${env.BRANCH} ${repoUrl} repo
                                        cd repo
                                        git checkout ${commitId}

                                        echo "[+] 체크아웃 완료: \$(git rev-parse --short HEAD)"

                                        /home/ec2-user/run_sbom_pipeline.sh '${repoUrl}' '${rname}' '${buildId}' '${commitId}'

                                        echo "[+] SBOM 생성 완료: ${buildId}"
                                    """
                                } catch (Exception e) {
                                    echo "❌ SBOM 생성 실패 (${buildId}): ${e.getMessage()}"
                                } finally {
                                    sh """
                                        echo "[+] 정리 작업: ${uniqueWorkspace}"
                                        rm -rf /tmp/${uniqueWorkspace} || true
                                    """
                                }
                            }
                        }
                    }

                    echo "🚀 ${jobs.size()}개의 SBOM 작업을 병렬로 실행합니다..."
                    parallel jobs
                    echo "✅ 모든 SBOM 작업이 완료되었습니다."
                }
            }
        }

        /*
        stage('🧪 병렬 실행 제거: SBOM 생성 nohup') {
            agent { label 'SCA' }
            steps {
                script {
                    def repoUrl = scm.userRemoteConfigs[0].url
                    def repoName = repoUrl.tokenize('/').last().replace('.git', '')
                    def buildId = env.BUILD_NUMBER
                    def repoDir = "/tmp/${repoName}_${buildId}"

                    catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                        sh """
                            echo "[+] SBOM 생성 시작 (nohup)"
                            nohup /home/ec2-user/run_sbom_pipeline1.sh '${repoUrl}' '${repoName}' '${buildId}' '${repoDir}' > /tmp/sbom_${repoName}_${buildId}.log 2>&1 &
                        """
                    }
                }
            }
        }
        */

        stage('🐳 Docker Build') {
            steps {
                sh 'DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/Docker_Build.sh'
            }
        }
    }
}
