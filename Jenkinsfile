pipeline {
    agent any

    environment {
        ECR_REPO = "159773342061.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-demo"
        IMAGE_TAG = "latest"
        JAVA_HOME = "/opt/jdk-23"
        PATH = "${env.JAVA_HOME}/bin:${env.PATH}"
        S3_BUCKET = "webgoat-deploy-bucket"
        DEPLOY_APP = "webgoat-cd-app"
        DEPLOY_GROUP = "webgoat-deployment-group"
        REGION = "ap-northeast-2"
        BUNDLE = "webgoat-deploy-bundle.zip"
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
                aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPO
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

        // ✅ 신규 단계: taskdef.json 생성
        stage('🧩 Generate taskdef.json') {
            steps {
                script {
                    def taskdef = """{
  "family": "webgoat-taskdef",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "name": "webgoat",
      "image": "${ECR_REPO}:${IMAGE_TAG}",
      "memory": 512,
      "cpu": 256,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ]
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::159773342061:role/ecsTaskExecutionRole"
}"""
                    writeFile file: 'taskdef.json', text: taskdef
                }
            }
        }

        // ✅ appspec.yaml + taskdef.json 번들 압축
        stage('📦 Bundle for CodeDeploy') {
            steps {
                sh 'zip -r $BUNDLE appspec.yaml Dockerfile taskdef.json'
            }
        }

        // ✅ S3 업로드 및 CodeDeploy 트리거
        stage('🚀 Deploy via CodeDeploy') {
            steps {
                sh '''
                aws s3 cp $BUNDLE s3://$S3_BUCKET/$BUNDLE --region $REGION

                aws deploy create-deployment \
                  --application-name $DEPLOY_APP \
                  --deployment-group-name $DEPLOY_GROUP \
                  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
                  --s3-location bucket=$S3_BUCKET,bundleType=zip,key=$BUNDLE \
                  --region $REGION
                '''
            }
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
