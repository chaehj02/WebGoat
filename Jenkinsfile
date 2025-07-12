pipeline {
    agent { label 'master' }

    environment {
        JAVA_HOME   = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH        = "${env.JAVA_HOME}/bin:${env.PATH}"
        SSH_CRED_ID = "WH1_key"
        DYNAMIC_IMAGE_TAG = "dev-${env.BUILD_NUMBER}-${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
    }
    // 테스트용 주석
    // 테스트용 주석2
    // 테스트용 주석3
    // 테스트용 주석4
    // 테스트용 주석5
    // 테스트용 주석6

    stages {
        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        }
        
       stage('SAST Background Analysis') {
    agent none
    steps {
        script {
            parallel(
                // SAST는 병렬로 따로 실행
                sast: {
                    node('SAST') {
                        withSonarQubeEnv('WH_sonarqube') {
                            sh '''
                                echo "export SONAR_AUTH_TOKEN='${SONAR_AUTH_TOKEN}'" > sonar_env.sh
                                echo "export SONAR_HOST_URL='${SONAR_HOST_URL}'" >> sonar_env.sh
                                chmod +x sonar_env.sh
                                source ./sonar_env.sh
                                bash components/scripts/run_sonar_pipeline.sh
                            '''
                        }
                    }
                },
                // 병렬 블록이 끝나기를 기다리지 않게 하기 위해 빈 태스크를 추가
                dummy: {
                    // 아무것도 안 함
                }
            )
        }
    }
}
        stage('🔨 Build JAR') {
            steps {
                sh 'components/scripts/Build_JAR.sh'
            }
        }
        
        stage('🚀 Generate SBOM via CDXGEN Docker') {
            agent { label 'SCA' }
            steps {
                script {
                    def repoUrl = scm.userRemoteConfigs[0].url
                    def repoName = repoUrl.tokenize('/').last().replace('.git', '')
                    
                    sh """
                        /home/ec2-user/run_sbom_pipeline.sh '${repoUrl}' '${repoName}' '${env.BUILD_NUMBER}'
                    """
                }
            }
        }


        stage('🐳 Docker Build') {
            steps {
                sh 'DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/Docker_Build.sh'
            }
        }

        stage('🔐 ECR Login') {
            steps {
                sh 'components/scripts/ECR_Login.sh'
            }
        }

        stage('🚀 Push to ECR') {
            steps {
                sh 'DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/Push_to_ECR.sh'
            }
        }

        //stage('🔍 ZAP 스캔 및 SecurityHub 전송') {
          //  agent { label 'DAST' }
            //steps {
                // sh 'DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/DAST_Zap_Scan.sh'
                //sh 'nohup components/scripts/DAST_Zap_Scan.sh > zap_bg.log 2>&1 &'
           // }
       // }

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

    post {
        success {
            echo "✅ Successfully built, pushed, and deployed!"
        }
        failure {
            echo "❌ Build or deployment failed. Check logs!"
        }
    }
}
