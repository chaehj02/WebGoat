pipeline {
    agent { label 'master' }

    environment {
        JAVA_HOME      = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH           = "${env.JAVA_HOME}/bin:${env.PATH}"
    
    }

    stages {
        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        } 

        stage('🧪 SonarQube Analysis') {
            parallel{
                stage ('SAST - SonarQube') {
                    agent { label 'SAST'}
                    steps {
                        sh 'mvn compile -DskipTests'
                        script {
                            load 'components/sonarqube_analysis.groovy'
                        }
                    }
                }
            }
        }
    }

}