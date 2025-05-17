pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-northeast-2'
        IMAGE_NAME = 'jenkins-demo'
        ACCOUNT_ID = '159773342061'
        ECR_URL = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
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
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                    export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                    export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

                    aws ecr get-login-password --region $AWS_REGION | \
                    docker login --username AWS --password-stdin $ECR_URL
                    '''
                }
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

        stage('Deploy to ECS (Fargate)') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                    export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                    export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

                    IMAGE_URI=$ECR_URL/$IMAGE_NAME:latest

                    # 기존 태스크 정의 가져오기
                    aws ecs describe-task-definition \
                      --task-definition jenkins-demo \
                      --region $AWS_REGION > task.json

                    # 새로운 이미지로 태스크 정의 생성
                    jq --arg IMAGE "$IMAGE_URI" \
                       '.taskDefinition |
                       {
                         family: .family,
                         networkMode: .networkMode,
                         executionRoleArn: .executionRoleArn,
                         containerDefinitions: (.containerDefinitions | map(.image = $IMAGE)),
                         requiresCompatibilities: .requiresCompatibilities,
                         cpu: .cpu,
                         memory: .memory
                       }' task.json > new-task.json

                    # 태스크 등록
                    aws ecs register-task-definition \
                      --cli-input-json file://new-task.json \
                      --region $AWS_REGION

                    # ECS 서비스 업데이트 (새 태스크로 배포)
                    aws ecs update-service \
                      --cluster jenkins-cluster \
                      --service jenkins-demo-service \
                      --force-new-deployment \
                      --region $AWS_REGION
                    '''
                }
            }
        }
    }
}
