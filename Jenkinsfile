pipeline {
    agent { label 'master' }

    environment {
        JAVA_HOME   = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH        = "${env.JAVA_HOME}/bin:${env.PATH}"
        SSH_CRED_ID = "WH1_key"
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
        
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Print Path Info') {
            steps {
                script {
                    echo "✅ 현재 워크스페이스 경로: ${env.WORKSPACE}"
                    sh "pwd"
                    sh "ls -al"
                }
            }
        }
        stage('Check File Exists') {
            steps {
                script {
                    def targetFile = "components/scripts/run_sbom_pipeline.sh"
                    if (fileExists(targetFile)) {
                        echo "✅ 파일 존재함: ${targetFile}"
                    } else {
                        echo "❌ 파일 없음: ${targetFile}"
                        sh "find . -name '*run_sbom_pipeline.sh'"
                    }
                }
            }
        }
    }
}
