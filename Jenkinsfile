stage('🚀 Generate SBOM for each commit (병렬 + nohup)') {
            steps {
                script {
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

                    // 이미 처리된 커밋 확인을 위한 함수
                    def isCommitProcessed = { commitId ->
                        def shortHash = commitId.take(7)
                        def result = sh(
                            script: "test -f /tmp/sbom_processed_${shortHash}.flag",
                            returnStatus: true
                        )
                        return result == 0
                    }

                    // 아직 처리되지 않은 커밋만 필터링
                    def unprocessedCommits = commits.findAll { !isCommitProcessed(it) }

                    if (unprocessedCommits.size() == 0) {
                        echo "✅ 모든 커밋이 이미 처리되었습니다. SBOM 생성을 스킵합니다."
                        return
                    }

                    echo "📌 처리할 커밋 목록 (${unprocessedCommits.size()}개):\n${unprocessedCommits.join('\n')}"

                    // 병렬 작업 정의
                    def jobs = [:]
                    def repoName = env.REPO_URL.tokenize('/').last().replace('.git', '')

                    for (int i = 0; i < unprocessedCommits.size(); i++) {
                        def index = i
                        def commitId = unprocessedCommits[index]
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

                                        # 기존 작업 디렉터리 정리
                                        rm -rf ${repoDir} || true
                                        mkdir -p ${repoDir}

                                        cd ${repoDir}
                                        git clone --quiet --branch ${env.BRANCH} ${repoUrl} repo
                                        cd repo
                                        git checkout ${commitId}

                                        echo "[+] 체크아웃 완료: \$(git rev-parse --short HEAD)"

                                        # 커밋 처리 시작 마크 (백그라운드 실행 전)
                                        touch /tmp/sbom_processing_${shortHash}.flag

                                        # nohup으로 백그라운드에서 SBOM 생성 실행
                                        nohup bash -c '
                                            /home/ec2-user/run_sbom_pipeline.sh "${repoUrl}" "${rname}" "${buildId}" "${commitId}" && 
                                            echo "[+] SBOM 생성 완료: ${buildId}" && 
                                            touch /tmp/sbom_processed_${shortHash}.flag &&
                                            rm -f /tmp/sbom_processing_${shortHash}.flag
                                        ' > /tmp/sbom_${rname}_${buildId}.log 2>&1 &
                                        
                                        echo "[+] SBOM 생성 백그라운드 실행 시작: ${buildId}"
                                        echo "[+] 로그 파일: /tmp/sbom_${rname}_${buildId}.log"
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
