pipeline {
    agent any 

    environment {
    AWS_REGION = 'ap-northeast-2'
    IMAGE_NAME = 'jenkins-demo'
    ACCOUNT_ID = '159773342061'
    ECR_URL = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')     // Jenkins credentials ID
    AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key') // Jenkins credentials ID
}


    stages {
        stage('Build JAR') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

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
