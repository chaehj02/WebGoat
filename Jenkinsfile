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
        
       stage('🧪 SonarQube Background') {
    agent { label 'SAST' }
    steps {
        withSonarQubeEnv(env.SONARQUBE_ENV) {
            sh '''
                chmod +x components/scripts/run_sonar_pipeline.sh
                export SONAR_AUTH_TOKEN=$SONAR_AUTH_TOKEN;
                export SONAR_HOST_URL=$SONAR_HOST_URL;
                nohup bash components/scripts/run_sonar_pipeline.sh > sonar_pipeline.log 2>&1 &
            '''
        }
    }
}
        
        stage('🔨 Build JAR') {
            steps {
                sh 'components/scripts/Build_JAR.sh'
            }
        }
        
        stage('🧪 병렬 실행 제거: SBOM 생성 nohup') {
            agent { label 'SCA' }
            steps {
                script {
                    def repoUrl = scm.userRemoteConfigs[0].url
                    def repoName = repoUrl.tokenize('/').last().replace('.git', '')
                    def buildId = env.BUILD_NUMBER
        
                    catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                        sh """
                            echo "[+] SBOM 생성 시작 (nohup + disown)"
                            bash -c 'nohup /home/ec2-user/run_sbom_pipeline1.sh "${0}" "${1}" "${2}" > /tmp/sbom_${1}_${2}.log 2>&1 & disown' '${repoUrl}' '${repoName}' '${buildId}'
                        """
                    }
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
                //sh nohup bash -c "DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/DAST_Zap_Scan.sh" > zap_bg.log 2>&1 &

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
