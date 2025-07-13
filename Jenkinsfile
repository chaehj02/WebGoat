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
                    sh """
                        rm -rf recent-commits && mkdir recent-commits
                        git clone --quiet --branch ${env.BRANCH} ${env.REPO_URL} recent-commits
                    """

                    dir('recent-commits') {
                        def commits = sh(
                            script: "git log ${env.GIT_PREVIOUS_COMMIT}..${env.GIT_COMMIT} --pretty=format:'%H'",
                            returnStdout: true
                        ).trim().split("\n")

                        echo "📌 변경된 커밋 목록:\n${commits.join('\n')}"

                        if (commits.size() == 0 || commits[0] == "") {
                            echo "✅ 변경된 커밋이 없어 SBOM 작업 생략"
                        } else {
                            def jobs = [:]
                            for (int i = 0; i < commits.size(); i++) {
                                def index = i
                                def commitId = commits[index]
                                def buildId = "${env.BUILD_NUMBER}-${index}"
                                def repoName = env.REPO_URL.tokenize('/').last().replace('.git', '')

                                jobs["SBOM-${index}"] = {
                                    def cid = commitId
                                    def bid = buildId
                                    def rname = repoName
                                    def repoUrl = env.REPO_URL

                                    node('SCA') {
                                                    sh """
                                                        echo "[+] SBOM 생성 시작: Commit ${cid}, Build ${bid}"
                                                        rm -rf /tmp/${rname} || true
                                                        /home/ec2-user/run_sbom_pipeline.sh '${repoUrl}' '${rname}' '${bid}' '${cid}'
                                                    """
                                    }
                                }
                            }

                            parallel jobs
                        }
                    }
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
        } */


        
       stage('🐳 Docker Build') {
            steps {
                sh 'DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/Docker_Build.sh'
            }
        }
 

      
    }

}
