#nohup이랑 멀티 빌드 합친 ver
pipeline {
    agent { label 'master' }

    environment {
        JAVA_HOME   = "/usr/lib/jvm/java-17-amazon-corretto.x86_64"
        PATH        = "${env.JAVA_HOME}/bin:${env.PATH}"
        SSH_CRED_ID = "WH_1_key"
        DYNAMIC_IMAGE_TAG = "dev-${env.BUILD_NUMBER}-${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
        REPO_URL = 'https://github.com/WH-Hourglass/WebGoat.git'
        BRANCH = 'SCA'
    }

    stages {

        stage('📦 Checkout') {
            steps {
                checkout scm
            }
        }

        stage('🔨 Build JAR') {
            steps {
                sh 'components/scripts/Build_JAR.sh'
            }
        }

       stage('🚀 Generate SBOM for each commit (병렬 + nohup + 안전장치)') {
                steps {
                    script {
                        // 오래된 processing 플래그 정리 (60분 이상 된 것)
                        sh 'find /tmp -name "sbom_processing_*.flag" -mmin +60 -delete 2>/dev/null || true'
                        
                        // 변경된 커밋 목록 추출
                        def commits = sh(
                            script: "git log ${env.GIT_PREVIOUS_COMMIT}..${env.GIT_COMMIT} --pretty=format:'%H'",
                            returnStdout: true
                        ).trim().split("\n")
    
                        // 빈 항목 제거
                        commits = commits.findAll { it != null && it.trim() != "" }
    
                        // 변경된 커밋이 없을 경우 스테이지 스킵
                        if (commits.size() == 0) {
                            echo "⚠️ 변경된 커밋이 없어 SBOM 생성을 스킵합니다."
                            return
                        }
    
                        // 커밋 처리 상태 확인 함수 (처리 중 + 완료 모두 확인)
                        def getCommitStatus = { commitId ->
                            def shortHash = commitId.take(7)
                            def processingExists = sh(
                                script: "test -f /tmp/sbom_processing_${shortHash}.flag",
                                returnStatus: true
                            ) == 0
                            def processedExists = sh(
                                script: "test -f /tmp/sbom_processed_${shortHash}.flag",
                                returnStatus: true
                            ) == 0
                            
                            if (processedExists) return "COMPLETED"
                            if (processingExists) return "PROCESSING"
                            return "PENDING"
                        }
    
                        // 커밋 상태별 분류
                        def pendingCommits = []
                        def processingCommits = []
                        def completedCommits = []
    
                        commits.each { commitId ->
                            def status = getCommitStatus(commitId)
                            def shortHash = commitId.take(7)
                            
                            switch(status) {
                                case "COMPLETED":
                                    completedCommits.add(shortHash)
                                    break
                                case "PROCESSING":
                                    processingCommits.add(shortHash)
                                    break
                                case "PENDING":
                                    pendingCommits.add(commitId)
                                    break
                            }
                        }
    
                        // 상태 리포트
                        echo "📊 커밋 처리 상태:"
                        echo "  ✅ 완료: ${completedCommits.size()}개 ${completedCommits.size() > 0 ? completedCommits.join(', ') : ''}"
                        echo "  🔄 처리중: ${processingCommits.size()}개 ${processingCommits.size() > 0 ? processingCommits.join(', ') : ''}"
                        echo "  ⏳ 대기: ${pendingCommits.size()}개"
    
                        // 처리할 커밋이 없으면 스킵
                        if (pendingCommits.size() == 0) {
                            echo "✅ 모든 커밋이 처리되었거나 처리 중입니다. SBOM 생성을 스킵합니다."
                            return
                        }
    
                        echo "📌 새로 처리할 커밋 목록 (${pendingCommits.size()}개):"
                        pendingCommits.each { echo "  - ${it.take(7)}" }
    
                        // 병렬 작업 정의
                        def jobs = [:]
                        def repoName = env.REPO_URL.tokenize('/').last().replace('.git', '')
    
                        for (int i = 0; i < pendingCommits.size(); i++) {
                            def index = i
                            def commitId = pendingCommits[index]
                            def buildId = "${env.BUILD_NUMBER}-${index}"
                            def shortHash = commitId.take(7)
                            def uniqueWorkspace = "workspace_${buildId}_${shortHash}"
    
                            // ✅ 병렬 고유화된 REPO_NAME 생성
                            def rname = "${repoName}_${buildId}_${shortHash}"
                            def repoUrl = env.REPO_URL
                            def repoDir = "/tmp/${uniqueWorkspace}"
    
                            jobs["SBOM-${index}-${shortHash}"] = {
                                node('SCA') {
                                    catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                                        sh """
                                            echo "[+] SBOM 생성 시작 (nohup): Commit ${shortHash}, Build ${buildId}"
                                            echo "[+] 작업 디렉터리: ${uniqueWorkspace}"
    
                                            # 이중 체크: 다른 프로세스가 이미 처리 시작했는지 확인
                                            if [ -f /tmp/sbom_processing_${shortHash}.flag ] || [ -f /tmp/sbom_processed_${shortHash}.flag ]; then
                                                echo "[!] 다른 프로세스가 이미 처리 중이거나 완료했습니다. 스킵합니다."
                                                exit 0
                                            fi
    
                                            # 처리 시작 플래그 생성 (원자적 연산으로 경합 방지)
                                            if ! (set -C; echo "\$\$" > /tmp/sbom_processing_${shortHash}.flag) 2>/dev/null; then
                                                echo "[!] 다른 프로세스가 동시에 시작했습니다. 스킵합니다."
                                                exit 0
                                            fi
    
                                            # 기존 작업 디렉터리 정리
                                            rm -rf ${repoDir} || true
                                            mkdir -p ${repoDir}
    
                                            cd ${repoDir}
                                            git clone --quiet --branch ${env.BRANCH} ${repoUrl} repo
                                            cd repo
                                            git checkout ${commitId}
    
                                            echo "[+] 체크아웃 완료: \$(git rev-parse --short HEAD)"
    
                                            # nohup으로 백그라운드에서 SBOM 생성 실행 (타임아웃 추가)
                                            nohup bash -c '
                                                set -e
                                                echo "[+] SBOM 생성 시작: \$(date)"
                                                
                                                # 타임아웃 설정 (30분)
                                                timeout 1800 /home/ec2-user/run_sbom_pipeline.sh "${repoUrl}" "${rname}" "${buildId}" "${commitId}" || {
                                                    echo "[!] SBOM 생성 실패 또는 타임아웃: ${buildId}"
                                                    touch /tmp/sbom_failed_${shortHash}.flag
                                                    rm -f /tmp/sbom_processing_${shortHash}.flag
                                                    exit 1
                                                }
                                                
                                                echo "[+] SBOM 생성 완료: ${buildId} at \$(date)"
                                                touch /tmp/sbom_processed_${shortHash}.flag
                                                rm -f /tmp/sbom_processing_${shortHash}.flag
                                                
                                                # 작업 디렉터리 정리
                                                rm -rf ${repoDir} || true
                                                
                                            ' > /tmp/sbom_${rname}_${buildId}.log 2>&1 &
                                            
                                            echo "[+] SBOM 생성 백그라운드 실행 시작: ${buildId}"
                                            echo "[+] 로그 파일: /tmp/sbom_${rname}_${buildId}.log"
                                            echo "[+] PID: \$!"
                                        """
                                    }
                                }
                            }
                        }
    
                        echo "🚀 ${jobs.size()}개의 SBOM 작업을 병렬로 실행합니다..."
                        parallel jobs
                        echo "✅ 모든 SBOM 작업이 백그라운드에서 시작되었습니다."
                    }
                }
            }
    
            stage('📊 SBOM 상태 확인 (선택사항)') {
                when {
                    // 필요시 이 스테이지를 활성화하여 상태 확인 가능
                    expression { return false }
                }
                steps {
                    script {
                        echo "🔍 SBOM 처리 상태 확인 중..."
                        sh '''
                            echo "=== 처리 완료된 커밋 ==="
                            ls -la /tmp/sbom_processed_*.flag 2>/dev/null || echo "없음"
                            
                            echo "=== 처리 중인 커밋 ==="
                            ls -la /tmp/sbom_processing_*.flag 2>/dev/null || echo "없음"
                            
                            echo "=== 실패한 커밋 ==="
                            ls -la /tmp/sbom_failed_*.flag 2>/dev/null || echo "없음"
                            
                            echo "=== 최근 로그 파일 ==="
                            find /tmp -name "sbom_*.log" -mmin -10 -exec echo "--- {} ---" \\; -exec tail -5 {} \\; 2>/dev/null || echo "없음"
                        '''
                    }
                }
            }

        
        stage('🐳 Docker Build') {
            steps {
                sh 'DYNAMIC_IMAGE_TAG=${DYNAMIC_IMAGE_TAG} components/scripts/Docker_Build.sh'
            }
        }
    }
}
