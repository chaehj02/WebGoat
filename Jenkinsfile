pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-northeast-2'
        IMAGE_NAME = 'jenkins-demo'  // ECR에 만든 리포지토리 이름
        ACCOUNT_ID = '159773342061'  // ← 여기에 본인 계정 ID 입력
        ECR_URL = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }
    

    stages {
        stage('Docker Build') {
            steps {
                sh 'docker build -t $IMAGE_NAME .'
            }
        }

        stage('ECR Login') {
            steps {
                sh '''
                aws ecr get-login-password --region $AWS_REGION | \
                docker login --username AWS --password-stdin $ECR_URL
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                docker tag $IMAGE_NAME:latest $ECR_URL/$IMAGE_NAME:latest
                docker push $ECR_URL/$IMAGE_NAME:latest
                '''
            }
        }
    }
}
