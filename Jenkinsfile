pipeline {
    agent any

    stages {
        stage('Start') {
            steps {
                echo '✅ Jenkins 파이프라인 테스트를 시작합니다.'
            }
        }

        stage('Build') {
            steps {
                echo '🔨 빌드 중...'
                sh 'echo Hello, Jenkins!'
            }
        }

        stage('Test') {
            steps {
                echo '🧪 테스트 실행 중...'
                sh 'echo Running tests...'
            }
        }

        stage('Done') {
            steps {
                echo '🎉 테스트 성공!'
            }
        }
    }
}

