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
        
        stage('🚀 Generate SBOM via CDXGEN Docker') {
                    agent { label 'SCA' }
                    steps {
                        script {
                            def repoUrl = scm.userRemoteConfigs[0].url
                            def repoName = repoUrl.tokenize('/').last().replace('.git', '')
                            
                            sh "/home/ec2-user/run_sbom_pipeline.sh ${repoUrl} ${repoName}"
                        }
                    }
                }

        stage('🛡️ SCA Guardrail Check (Lambda)') {
    agent { label 'SCA' }
    steps {
        script {
            def payload = """
            {
                "project_name": "WebGoat",
                "api_key": "${env.DEPTRACK_API_KEY}",
                "server": "${env.DEPTRACK_URL}"
            }
            """.stripIndent().trim()

            writeFile file: 'lambda_input.json', text: payload

            sh """
            aws lambda invoke \
              --function-name sca_guardrail \
              --payload fileb://lambda_input.json \
              lambda_result.json
            """

            def result = readFile('lambda_result.json')
            echo "Lambda 결과: ${result}"

            def status = new groovy.json.JsonSlurper().parseText(result).status
            if (status == 'fail') {
                error("❌ 가드레일 통과 실패 (OWASP Top 10 관련 취약점 존재)")
            } else {
                echo "✅ 가드레일 통과"
            }
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
