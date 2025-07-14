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
        




        stage('🐳 Docker Build') {
            steps {
                sh 'DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/Docker_Build.sh'
            }
        }

        stage('🔐 ECR Login') {
            steps {
                sh 'components/scripts/ECR_Login.sh'
            }
        }

        stage('🚀 Push to ECR') {
            steps {
                sh 'DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/Push_to_ECR.sh'
            }
        }

        stage('🔍 ZAP 스캔 및 SecurityHub 전송') {
            agent { label 'DAST' }
            steps {
                //sh 'DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/DAST_Zap_Scan.sh'
                sh nohup bash -c "DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/DAST_Zap_Scan.sh" > zap_bg.log 2>&1 &

            }
        }

    post {
        success {
            echo "✅ Successfully built, pushed, and deployed!"
        }
        failure {
            echo "❌ Build or deployment failed. Check logs!"
        }
    }
}
