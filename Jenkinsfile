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

        stage('🧪 SonarQube Analysis') {
            agent {label 'SAST'}
            steps {
                script {
                    sh 'components/scripts/sonarqube_analysis.sh'
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
