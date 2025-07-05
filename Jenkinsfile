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

        stage('📂 경로 디버깅') {
            steps {
                script {
                    echo "📌 Jenkins workspace: ${env.WORKSPACE}"
                    sh '''
                        echo "✅ [Groovy에서 실행되는 경로: $(pwd)]"
                        echo "📁 components/scripts 디렉토리 내용:"
                        ls -al components/scripts || echo "❌ 디렉토리 없음"
                        
                        echo "📄 run_sbom_pipeline.sh 경로:"
                        find . -name 'run_sbom_pipeline.sh' || echo "❌ 파일 없음"
        
                        echo "📄 functions.sh 경로:"
                        find . -name 'functions.sh' || echo "❌ 파일 없음"
        
                        echo "📄 sca_parallel.groovy 경로:"
                        find . -name 'sca_parallel.groovy' || echo "❌ 파일 없음"
                    '''
                }
            }
        }

        stage('🔨 Build JAR') {
            steps {
                sh 'components/scripts/Build_JAR.sh'
            }
        }
    }
}
