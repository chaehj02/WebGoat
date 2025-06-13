pipeline {
    agent any

    environment {
        JAVA_HOME = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH = "${env.JAVA_HOME}/bin:${env.PATH}"
        REGION = "ap-northeast-2"
    }

    stages {
        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        }

        stage('🧪 SonarQube Analysis') {
            steps {
                script{
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
                sh 'components/scrips/Docker_Build.sh'
            }
        }

        stage('🔐 ECR Login') {
            steps {
                sh 'components/scrips/ECR_Login.sh'
            }
        }

        stage('🚀 Push to ECR') {
            steps {
                sh 'components/scrips/Push_to_ECR.sh'
            }
        }

        stage('🧩 Generate taskdef.json') {
            steps {
                script {
                    def generateTaskDef=load 'components/functions/generateTaskDef.groovy'
                    def taskdef = generateTaskDef(env)
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

                    def generateAppSpec = load 'components/functions/generateAppSpec.groovy'
                    def appspec = generateAppSpec(taskDefArn)
                    writeFile file: 'appspec.yaml', text: appspec
                }
            }
        }

        stage('📦 Bundle for CodeDeploy') {
            steps {
                sh 'components/scrips/Bundle_for_CodeDeploy'
            }
        }

        stage('🚀 Deploy via CodeDeploy') {
            steps {
                sh 'components/scrips/Deploy_via_CodeDeploy'
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