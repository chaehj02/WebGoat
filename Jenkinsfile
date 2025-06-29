pipeline {
    agent { label 'master' }

    environment {
        JAVA_HOME   = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH        = "${env.JAVA_HOME}/bin:${env.PATH}"
        SSH_CRED_ID = "WH1_key"
    }

    stages {
        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        }

        stage('🧪 SonarQube Analysis') {
            agent { label 'SAST' }
            steps {
                script {
                    load 'components/scripts/sonarqube_analysis.groovy'
                }
            }
        }

        stage('🔨 Build JAR') {
            steps {
                sh 'components/scripts/Build_JAR.sh'
            }
        }

            stage('🔍 도커 이미지 태그 결정') {
            steps {
                script {
                    env.JAVA_VERSION = sh(
                        script: "python3 components/scripts/pom_to_docker_image_test.py pom.xml",
                        returnStdout: true
                    ).trim()
                    echo "[+] 사용 자바 버전: ${env.JAVA_VERSION}"

                    env.IMAGE_TAG = sh(
                        script: "python3 components/scripts/docker_tag.py ${env.JAVA_VERSION}",
                        returnStdout: true
                    ).trim()
                    echo "[+] 이미지 태그: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('📦 SBOM 생성 & DTrack 업로드') {
            steps {
                script {
                    sh "bash components/scripts/run_cdxgen_test.sh ${env.IMAGE_TAG}"
                    sh "./components/scripts/upload_to_dtrack.sh ${env.DTRACK_URL} ${env.DTRACK_UUID} ${env.DTRACK_APIKEY} sbom.json"
                }
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

        stage('🔍 ZAP 스캔 및 SecurityHub 전송') {
            agent { label 'DAST' }
            steps {
                // sh 'components/scripts/DAST_Zap_Scan.sh'
                sh 'nohup components/scripts/DAST_Zap_Scan.sh > zap_bg.log 2>&1 &'
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

    post {
        success {
            echo "✅ Successfully built, pushed, and deployed!"
        }
        failure {
            echo "❌ Build or deployment failed. Check logs!"
        }
    }
}
