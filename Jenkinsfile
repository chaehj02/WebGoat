pipeline {
    agent any

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
                sh '''
aws ec2 start-instances --instance-ids i-0f3dde2aad32ae6ce --region ${REGION}
/var/lib/jenkins/scripts/wait_for_ssh_ready.sh ${DAST_HOST}
                '''
            }
        }

        stage('🐳 Docker Build & Push') {
            steps {
                sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
                sh '''
aws ecr get-login-password --region ${REGION} \
  | docker login --username AWS --password-stdin ${ECR_REPO}
docker push ${ECR_REPO}:${IMAGE_TAG}
                '''
            }
        }

        stage('🧪 병렬 스캔 및 배포') {
            parallel {
                stage('🔍 ZAP & SecurityHub') {
                    agent { label 'DAST' }
                    stages {
                        stage('ZAP 스캔') {
                            steps {
                                withCredentials([sshUserPrivateKey(credentialsId: SSH_CRED_ID, keyFileVariable: 'SSH_KEY')]) {
                                    sh '''
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ec2-user@${DAST_HOST} <<EOF
  aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO}
  docker rm -f ${CONTAINER_NAME} || true
  docker pull ${ECR_REPO}:${IMAGE_TAG}
  docker run -d --name ${CONTAINER_NAME} -p 8080:8080 ${ECR_REPO}:${IMAGE_TAG}
  sleep 10
  chmod +x ~/${ZAP_SCRIPT}
  ~/${ZAP_SCRIPT} ${CONTAINER_NAME}
EOF
scp -i $SSH_KEY -o StrictHostKeyChecking=no ec2-user@${DAST_HOST}:~/zap_test.json .
                                    '''
                                }
                            }
                        }
                        stage('SecurityHub 전송') {
                            steps {
                                script {
                                    def timestamp = new Date().format("yyyyMMdd_HHmmss")
                                    def s3_key = "default/zap_test_${timestamp}.json"
                                    try {
                                        sh "aws s3 cp zap_test.json s3://${S3_BUCKET}/${s3_key} --region ${REGION}"
                                        env.S3_JSON_KEY = s3_key
                                    } catch (err) {
                                        echo "⚠️ S3 업로드 실패 (무시): ${err}"
                                    }
                                }
                            }
                        }
                    }
                }

                stage('🚀 배포 (CodeDeploy)') {
                    agent any
                    stages {
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
                                    def taskDefArn = sh(script: "aws ecs register-task-definition --cli-input-json file://taskdef.json --query 'taskDefinition.taskDefinitionArn' --region ${REGION} --output text", returnStdout: true).trim()
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
                                sh 'zip -r ${BUNDLE} appspec.yaml Dockerfile taskdef.json'
                                sh '''
aws s3 cp ${BUNDLE} s3://${S3_BUCKET}/${BUNDLE} --region ${REGION}
aws deploy create-deployment \
  --application-name ${DEPLOY_APP} \
  --deployment-group-name ${DEPLOY_GROUP} \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
  --s3-location bucket=${S3_BUCKET},bundleType=zip,key=${BUNDLE} \
  --region ${REGION}
                                '''
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "🛑 병렬 작업 종료 → EC2 인스턴스 중지"
            sh "aws ec2 stop-instances --instance-ids i-0f3dde2aad32ae6ce --region ${REGION}"
        }
        success { echo "✅ CD & Security Test 모두 완료!" }
        failure { echo "❌ 파이프라인 실패, 로그 확인 요망." }
    }
}
