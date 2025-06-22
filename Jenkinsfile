pipeline {
    agent { label 'master' }

    environment {
        ECR_REPO       = "159773342061.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-demo"
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        JAVA_HOME      = "/opt/jdk-23"
        PATH           = "${env.JAVA_HOME}/bin:${env.PATH}"
        REGION         = "ap-northeast-2"
        DAST_HOST      = "172.31.8.198"
        SSH_CRED_ID    = "jenkin_sv"
        ZAP_SCRIPT     = "zap_webgoat.sh"
        CONTAINER_NAME = "webgoat-test"
        S3_BUCKET      = "webgoat-deploy-bucket"
        DEPLOY_APP     = "webgoat-cd-app"
        DEPLOY_GROUP   = "webgoat-deployment-group"
        BUNDLE         = "webgoat-deploy-bundle.zip"
        EC2_INSTANCE_ID = "i-0f3dde2aad32ae6ce"
    }

    stages {
        stage('📦 Checkout') {
            steps { checkout scm }
        }

        stage('🔨 Build JAR') {
            steps { sh 'mvn clean package -DskipTests' }
        }

        stage('⚡ EC2 부팅') {
            steps {
                script {
                    def ec2State = sh(
                        script: """
                            aws ec2 describe-instances \
                              --instance-ids ${EC2_INSTANCE_ID} \
                              --region ${REGION} \
                              --query 'Reservations[0].Instances[0].State.Name' \
                              --output text
                        """,
                        returnStdout: true
                    ).trim()

                    echo "현재 EC2 상태: ${ec2State}"

                    if (ec2State == 'stopped') {
                        echo "🔄 인스턴스가 꺼져 있음 → 시작 시도"
                        sh "aws ec2 start-instances --instance-ids ${EC2_INSTANCE_ID} --region ${REGION}"
                        sh "/var/lib/jenkins/scripts/wait_for_ssh_ready.sh ${DAST_HOST}"
                    } else if (ec2State == 'running') {
                        echo "✅ 인스턴스가 이미 실행 중 → SSH 접속 확인"
                        sh "/var/lib/jenkins/scripts/wait_for_ssh_ready.sh ${DAST_HOST}"
                    } else {
                        error "🚫 EC2 인스턴스 상태(${ec2State})가 시작 가능한 상태가 아닙니다."
                    }
                }
            }
        }

        stage('🐳 Docker Build & Push') {
            steps {
                sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
                sh """
                    aws ecr get-login-password --region ${REGION} \
                      | docker login --username AWS --password-stdin ${ECR_REPO}
                    docker push ${ECR_REPO}:${IMAGE_TAG}
                """
            }
        }

        stage('🔍 ZAP 스캔 및 SecurityHub 전송') {
            steps {
                sh 'components/scripts/Zap_and_Send.sh'
            }
        }

        stage('🧩 Generate taskdef.json') {
            steps {
                script {
                    def taskdef = """{
  \"family\": \"webgoat-taskdef\",
  \"networkMode\": \"awsvpc\",
  \"containerDefinitions\": [
    {
      \"name\": \"webgoat\",
      \"image\": \"${ECR_REPO}:${IMAGE_TAG}\",
      \"memory\": 512,
      \"cpu\": 256,
      \"essential\": true,
      \"portMappings\": [
        {\"containerPort\": 8080, \"protocol\": \"tcp\"}
      ]
    }
  ],
  \"requiresCompatibilities\": [\"FARGATE\"],
  \"cpu\": \"256\",
  \"memory\": \"512\",
  \"executionRoleArn\": \"arn:aws:iam::159773342061:role/ecsTaskExecutionRole\"
}"""
                    writeFile file: 'taskdef.json', text: taskdef
                }
            }
        }

        stage('📄 Generate appspec.yaml') {
            steps {
                script {
                    def taskDefArn = sh(
                      script: "aws ecs register-task-definition --cli-input-json file://taskdef.json --query 'taskDefinition.taskDefinitionArn' --region ${REGION} --output text",
                      returnStdout: true
                    ).trim()
                    def appspec = """version: 1
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: \"${taskDefArn}\"
        LoadBalancerInfo:
          ContainerName: \"webgoat\"
          ContainerPort: 8080
"""
                    writeFile file: 'appspec.yaml', text: appspec
                }
            }
        }

        stage('📦 Bundle & Deploy') {
            steps {
                sh "zip -r ${BUNDLE} appspec.yaml Dockerfile taskdef.json"
                sh """
                    aws s3 cp ${BUNDLE} s3://${S3_BUCKET}/${BUNDLE} --region ${REGION}
                    aws deploy create-deployment \
                      --application-name ${DEPLOY_APP} \
                      --deployment-group-name ${DEPLOY_GROUP} \
                      --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
                      --s3-location bucket=${S3_BUCKET},bundleType=zip,key=${BUNDLE} \
                      --region ${REGION}
                """
            }
        }
    }

    post {
        always {
            echo "🧹 ZAP 컨테이너 정리 중..."
            node('zap') {
                script {
                    def containerFile = "container_name_${env.BUILD_NUMBER}.txt"
                    if (fileExists(containerFile)) {
                        def containerName = readFile(containerFile).trim()
                        echo "[*] 종료 대상 컨테이너: ${containerName}"
                        try {
                            sh "docker rm -f ${containerName}"
                        } catch (e) {
                            echo "⚠️ 컨테이너 제거 실패: ${e.message}"
                        }
                    } else {
                        echo "⚠️ container_name_${env.BUILD_NUMBER}.txt 없음 → 컨테이너 정리 생략"
                    }
                }
            }
        }
        success { echo "✅ CD & Security Test 모두 완료!" }
        failure { echo "❌ 파이프라인 실패, 로그 확인 요망." }
    }
}
