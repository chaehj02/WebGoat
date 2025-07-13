pipeline {
    agent { label 'master' }

    environment {
        JAVA_HOME   = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH        = "${env.JAVA_HOME}/bin:${env.PATH}"
        SSH_CRED_ID = "WH1_key"
        DYNAMIC_IMAGE_TAG = "dev-${env.BUILD_NUMBER}-${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
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


        stage('🐳 Docker Build') {
            steps {
                sh 'components/scripts/Docker_Build.sh'
            }
        }

 

      
    }

}
