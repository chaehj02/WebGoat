pipeline {
    agent any

    environment {
        ECR_REPO = "159773342061.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-demo"
        IMAGE_TAG = "latest"
        JAVA_HOME = "/opt/jdk-23"
        PATH = "${env.JAVA_HOME}/bin:${env.PATH}"
    }

    stages {
        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        }

        stage('🔨 Build JAR') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('🐳 Docker Build') {
            steps {
                sh '''
                docker build -t $ECR_REPO:$IMAGE_TAG .
                '''
            }
        }

        stage('🔐 ECR Login') {
            steps {
                sh '''
                aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin $ECR_REPO
                '''
            }
        }

        stage('🚀 Push to ECR') {
            steps {
                sh '''
                docker push $ECR_REPO:$IMAGE_TAG
                '''
            }
        }
    }

    post {
        success {
            echo "✅ Successfully built and pushed to ECR!"
        }
        failure {
            echo "❌ Build or push failed. Check logs!"
        }
    }
    stage('Deploy to ECS with CodeDeploy') {
    steps {
        script {
            sh '''
            aws deploy create-deployment \
              --application-name webgoat-codedeploy \
              --deployment-group-name webgoat-deploy-group \
              --file-exists-behavior OVERWRITE \
              --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
              --github-location repository=chaehj02/WebGoat,commitId=${GIT_COMMIT}
            '''
        }
    }
}

}
