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
	EC2_INSTANCE_ID = "i-08b682cce060eb8de"

    }

    stages {
        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        }

	// stage('⚡ EC2 부팅') {
    //         steps {
    //             script {
    //                 def ec2State = sh(
    //                     script: """
    //                         aws ec2 describe-instances \
    //                           --instance-ids ${EC2_INSTANCE_ID} \
    //                           --region ${REGION} \
    //                           --query 'Reservations[0].Instances[0].State.Name' \
    //                           --output text
    //                     """,
    //                     returnStdout: true
    //                 ).trim()

    //                 echo "현재 EC2 상태: ${ec2State}"

    //                 if (ec2State == 'stopped') {
    //                     echo "🔄 인스턴스가 꺼져 있음 → 시작 시도"
    //                     sh "aws ec2 start-instances --instance-ids ${EC2_INSTANCE_ID} --region ${REGION}"
    //                     sh "/var/lib/jenkins/scripts/wait_for_ssh_ready.sh ${DAST_HOST}"
    //                 } else if (ec2State == 'running') {
    //                     echo "✅ 인스턴스가 이미 실행 중 → SSH 접속 확인"
    //                     sh "/var/lib/jenkins/scripts/wait_for_ssh_ready.sh ${DAST_HOST}"
    //                 } else {
    //                     error "🚫 EC2 인스턴스 상태(${ec2State})가 시작 가능한 상태가 아닙니다."
    //                 }
    //             }
    //         }
    //     }
    

        

        stage('🧪 SonarQube Analysis') {
            parallel{
                stage ('SAST - SonarQube') {
                    agent { label 'SAST'}
                    steps {
                        script {
                            load 'components/sonarqube_analysis.groovy'
                        }
                    }
                }
            }
        }

        // stage('🔨 Build JAR') {
        //     steps {
        //         sh 'components/scripts/Build_JAR.sh'
        //     }
        // }

        // stage('🐳 Docker Build') {
        //     steps {
        //         sh 'components/scripts/Docker_Build.sh'
        //     }
        // }

        // stage('🔐 ECR Login') {
        //     steps {
        //         sh 'components/scripts/ECR_Login.sh'
        //     }
        // }

        // stage('🚀 Push to ECR') {
        //     steps {
        //         sh 'components/scripts/Push_to_ECR.sh'
        //     }
        // }

    //     stage('🧪 병렬 스캔 및 배포') {
    //         parallel {
    //             stage('🔍 ZAP & SecurityHub') {
    //                 agent { label 'DAST' }
    //                 stages {
    //                     stage('ZAP 스캔') {
    //                         steps {
    //                             script {
    //                                 def containerName = "${CONTAINER_NAME}-${BUILD_NUMBER}"
    //                                 def containerFile = "container_name_${BUILD_NUMBER}.txt"
    //                                 def zapJson = "zap_test_${BUILD_NUMBER}.json"
    //                                 def port = 8080 + (BUILD_NUMBER.toInteger() % 1000)

    //                                 writeFile file: containerFile, text: containerName

    //                                 sh """
    //                                     aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO}
    //                                     docker pull ${ECR_REPO}:latest
    //                                     docker run -d --name ${containerName} -p ${port}:8080 ${ECR_REPO}:latest

    //                                     for j in {1..15}; do
    //                                     if curl -s http://localhost:${port} > /dev/null; then
    //                                         echo "✅ 애플리케이션 기동 완료 (${port})"
    //                                         break
    //                                     fi
    //                                     sleep 2
    //                                     done

    //                                     chmod +x ~/${ZAP_SCRIPT}
    //                                     ~/${ZAP_SCRIPT} ${containerName}
    //                                     cp ~/zap_test.json ${zapJson}
    //                                     cp ${zapJson} zap_test.json
    //                                 """
    //                             }
    //                         }
    //                     }
    //                     stage('SecurityHub 전송') {
    //                         steps {
    //                             script {
    //                                 def timestamp = new Date().format("yyyyMMdd_HHmmss")
    //                                 def s3_key = "default/zap_test_${timestamp}.json"
    //                                 try {
    //                                     sh "aws s3 cp zap_test.json s3://${S3_BUCKET}/${s3_key} --region ${REGION}"
    //                                     env.S3_JSON_KEY = s3_key
    //                                 } catch (err) {
    //                                     echo "⚠️ S3 업로드 실패 (무시): ${err}"
    //                                 }
    //                             }
    //                         }
    //                     }
    //                 }
    //             }
    //             stage('🚀 배포 (CodeDeploy)') {
    //                 stages {
    //             stage('🧩 Generate taskdef.json') {
    //                 steps {
    //                     script {
    //                         def runTaskDefGen = load 'components/functions/generateTaskDef.groovy'
    //                         runTaskDefGen(env)
    //                     }
    //                 }
    //             }

    //             stage('📄 Generate appspec.yaml') {
    //                 steps {
    //                     script {
    //                         def runAppSpecGen = load 'components/functions/generateAppspecAndWrite.groovy'
    //                         runAppSpecGen(env.REGION)
    //                     }
    //                 }
    //             }

    //             stage('📦 Bundle for CodeDeploy') {
    //                 steps {
    //                     sh 'components/scripts/Bundle_for_CodeDeploy.sh'
    //                 }
    //             }

    //             stage('🚀 Deploy via CodeDeploy') {
    //                 steps {
    //                     sh 'components/scripts/Deploy_via_CodeDeploy.sh'
    //                 }
    //             }
    //         }
    //     }
    // }
    //     }
    }

    //  post {
    //     always {
    //         echo "🧹 ZAP 컨테이너 정리 중..."
    //         node('DAST') {
    //             script {
    //                 def containerFile = "container_name_${env.BUILD_NUMBER}.txt"
    //                 if (fileExists(containerFile)) {
    //                     def containerName = readFile(containerFile).trim()
    //                     echo "[*] 종료 대상 컨테이너: ${containerName}"
    //                     try {
    //                         sh "docker rm -f ${containerName}"
    //                     } catch (e) {
    //                         echo "⚠️ 컨테이너 제거 실패: ${e.message}"
    //                     }
    //                 } else {
    //                     echo "⚠️ container_name_${env.BUILD_NUMBER}.txt 없음 → 컨테이너 정리 생략"
    //                 }
    //             }
    //         }
    //     }
    //     success {
    //         echo "✅ Successfully built, pushed, and deployed!"
    //     }
    //     failure {
    //         echo "❌ Build or deployment failed. Check logs!"
    //     }
    // }
}
