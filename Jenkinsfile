pipeline {
    agent any

    environment {
        ECR_REPO = "535052053335.dkr.ecr.ap-northeast-2.amazonaws.com/wh_1/devpos"
        IMAGE_TAG = "latest"
        JAVA_HOME = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH = "${env.JAVA_HOME}/bin:${env.PATH}"
        S3_BUCKET = "webgoat-codedeploy-bucket-soobin"
        DEPLOY_APP = "webgoat-cd-app"
        DEPLOY_GROUP = "webgoat-deploy-group"
        REGION = "ap-northeast-2"
        BUNDLE = "deploy2.zip"
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
                sh 'docker push $ECR_REPO:$IMAGE_TAG'
            }
        }

        stage('🧩 Generate taskdef.json') {
            steps {
                script {
                    def taskdef = """{
  "family": "webgoat-task-def",
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
  "executionRoleArn": "arn:aws:iam::535052053335:role/ecsTaskExecutionRole"
}"""
                    writeFile file: 'taskdef.json', text: taskdef
                }
            }
        }

        stage('📄 Generate appspec.yaml') {
            steps {
                script {
                    def taskDefArn = sh(
                        script: "aws ecs register-task-definition --cli-input-json file://taskdef.json --query 'taskDefinition.taskDefinitionArn' --region $REGION --output text",
                        returnStdout: true
                    ).trim()

                    def appspec = """version: 1
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "${taskDefArn}"
        LoadBalancerInfo:
          ContainerName: "webgoat"
          ContainerPort: 8080
"""
                    writeFile file: 'appspec.yaml', text: appspec
                }
            }
        }

        stage('📦 Bundle for CodeDeploy') {
            steps {
                sh 'zip -r $BUNDLE appspec.yaml Dockerfile taskdef.json'
            }
        }

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