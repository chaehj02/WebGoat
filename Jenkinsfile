pipeline {
    agent { label 'master' }

    environment {
        ECR_REPO       = "535052053335.dkr.ecr.ap-northeast-2.amazonaws.com/wh_1/devpos"
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        JAVA_HOME      = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH           = "${env.JAVA_HOME}/bin:${env.PATH}"
        REGION         = "ap-northeast-2"
        DAST_HOST      = "172.31.8.217"
        ZAP_SCRIPT     = "zap_webgoat.sh"
        CONTAINER_NAME = "webgoat-test"
        SSH_CRED_ID    = "WH1_key"
        S3_BUCKET      = "testdast"
    }

    stages {
        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        }

        stage('⚡ EC2 부팅') {
            steps {
                sh '''
                    aws ec2 start-instances --instance-ids i-08b682cce060eb8de --region ${REGION}
                    /var/lib/jenkins/scripts/wait_for_ssh_ready.sh ${DAST_HOST}
                '''
            }
        }

        stage('🧪 SonarQube Analysis') {
            steps {
                script {
                    load 'components/sonarqube_analysis.groovy'
                }
            }
        }

        stage('🔨 Build JAR') {
            steps {
                sh 'components/scripts/Build_JAR.sh'
            }
        }

        stage('🐳 Docker Build') {
            steps {
                sh 'components/scripts/Docker_Build.sh'
            }
        }

        stage('🔐 ECR Login') {
            steps {
                sh 'components/scripts/ECR_Login.sh'
            }
        }

        stage('🚀 Push to ECR') {
            steps {
                sh 'components/scripts/Push_to_ECR.sh'
            }
        }

        stage('🧪 병렬 스캔 및 배포') {
            parallel {
                stage('🔍 ZAP & SecurityHub') {
                    agent { label 'zap' }
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

                stage('🧩 Generate taskdef.json') {
                    steps {
                        script {
                            def runTaskDefGen = load 'components/functions/generateTaskDef.groovy'
                            runTaskDefGen(env)
                        }
                    }
                }

                stage('📄 Generate appspec.yaml') {
                    steps {
                        script {
                            def runAppSpecGen = load 'components/functions/generateAppspecAndWrite.groovy'
                            runAppSpecGen(env.REGION)
                        }
                    }
                }

                stage('📦 Bundle for CodeDeploy') {
                    steps {
                        sh 'components/scripts/Bundle_for_CodeDeploy.sh'
                    }
                }

                stage('🚀 Deploy via CodeDeploy') {
                    steps {
                        sh 'components/scripts/Deploy_via_CodeDeploy.sh'
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
        success {
            echo "✅ Successfully built, pushed, and deployed!"
        }
        failure {
            echo "❌ Build or deployment failed. Check logs!"
        }
    }
}
