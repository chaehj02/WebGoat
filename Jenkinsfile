pipeline {
    agent any

    environment {
        ECR_REPO        = "159773342061.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-demo"
        IMAGE_TAG       = "latest"
        JAVA_HOME       = "/opt/jdk-23"
        PATH = "/usr/local/bin:/home/ec2-user/.local/bin:${JAVA_HOME}/bin:${env.PATH}"


        // 개선 1: NVD API Key 연동 (Jenkins Credentials에서 등록한 경우)
        NVD_API_KEY     = credentials('nvd-api-key')

        // 개선 4: 리소스 이름 변수화
        CONTAINER_NAME  = "webgoat"
        CONTAINER_PORT  = "8080"
        TASK_FAMILY     = "webgoat-taskdef"
        EXEC_ROLE_ARN   = "arn:aws:iam::159773342061:role/ecsTaskExecutionRole"

        S3_BUCKET       = "webgoat-deploy-bucket"
        DEPLOY_APP      = "webgoat-cd-app"
        DEPLOY_GROUP    = "webgoat-deployment-group"
        REGION          = "ap-northeast-2"
        BUNDLE          = "webgoat-deploy-bundle.zip"
    }

    stages {
        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        }

        stage('🔍 Static Analysis - Semgrep') {
            steps {
                sh '''
                echo "[+] Running Semgrep..."
                semgrep --config "p/owasp-top-ten" . || true
                '''
            }
        }

        stage('🧪 Dependency Check') {
            steps {
                sh '''
                echo "[+] Running OWASP Dependency-Check..."
                mkdir -p dependency-check-report
                dependency-check.sh \
                  --project "webgoat" \
                  --scan . \
                  --format HTML \
                  --out dependency-check-report \
                  --nvdApiKey "$NVD_API_KEY" || true
                '''
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
  "family": "${TASK_FAMILY}",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "name": "${CONTAINER_NAME}",
      "image": "${ECR_REPO}:${IMAGE_TAG}",
      "memory": 512,
      "cpu": 256,
      "essential": true,
      "portMappings": [
        {
          "containerPort": ${CONTAINER_PORT},
          "protocol": "tcp"
        }
      ]
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "${EXEC_ROLE_ARN}"
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
          ContainerName: "${CONTAINER_NAME}"
          ContainerPort: ${CONTAINER_PORT}
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
            archiveArtifacts artifacts: 'dependency-check-report/**', allowEmptyArchive: true
            echo "✅ Successfully built, analyzed, pushed, and deployed!"
        }
        failure {
            echo "❌ Build or deployment failed. Check logs!"
        }
    }
}
