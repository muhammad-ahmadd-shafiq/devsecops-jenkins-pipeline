pipeline {
    agent any

    environment {
        IMAGE_NAME = "ghcr.io/muhammad-ahmadd-shafiq/devsecops-app"
        IMAGE_TAG  = "${GIT_COMMIT.take(7)}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Gitleaks Scan') {
            steps {
                sh '''
                    gitleaks detect \
                    --source . \
                    --report-format sarif \
                    --report-path gitleaks.sarif
                '''
            }
        }

        stage('Trivy FS Scan') {
            steps {
                sh '''
                    trivy fs . \
                    --exit-code 1 \
                    --severity HIGH,CRITICAL
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Bandit SAST') {
            steps {
                sh '''
                    . venv/bin/activate
                    bandit -r app.py -ll -f txt
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    pytest
                '''
            }
        }

        stage('Trivy Config Scan') {
            steps {
                sh '''
                    trivy config . \
                    --severity HIGH,CRITICAL \
                    --exit-code 1
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t $IMAGE_NAME:$IMAGE_TAG .
                '''
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                    trivy image \
                    --exit-code 1 \
                    --severity HIGH,CRITICAL \
                    --ignore-unfixed \
                    $IMAGE_NAME:$IMAGE_TAG
                '''
            }
        }

        stage('Generate SBOM') {
            steps {
                sh '''
                    trivy image \
                    --format cyclonedx \
                    --output sbom.json \
                    $IMAGE_NAME:$IMAGE_TAG
                '''
            }
        }

        stage('Run Container') {
            steps {
                sh '''
                    docker rm -f app-test || true
                    docker run -d \
                    --name app-test \
                    -p 5000:5000 \
                    $IMAGE_NAME:$IMAGE_TAG
                    sleep 15
                '''
            }
        }

        stage('OWASP ZAP Scan') {
            steps {
                sh '''
                    docker run --rm \
                    --network host \
                    ghcr.io/zaproxy/zaproxy:stable \
                    zap-baseline.py \
                    -t http://localhost:5000 \
                    -I
                '''
            }
        }

        stage('Cleanup Container') {
            steps {
                sh '''
                    docker rm -f app-test || true
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'ghcr-creds',
                        usernameVariable: 'USERNAME',
                        passwordVariable: 'TOKEN'
                    )
                ]) {
                    sh '''
                        echo $TOKEN | docker login ghcr.io -u $USERNAME --password-stdin
                        docker push $IMAGE_NAME:$IMAGE_TAG
                    '''
                }
            }
        }

        stage('Sign Image') {
            steps {
                withCredentials([
                    file(credentialsId: 'cosign-key', variable: 'COSIGN_KEY'),
                    string(credentialsId: 'cosign-password', variable: 'COSIGN_PASSWORD')
                ]) {
                    sh '''
                        cosign sign \
                        --key $COSIGN_KEY \
                        $IMAGE_NAME:$IMAGE_TAG \
                        --yes
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts(
                artifacts: 'gitleaks.sarif,sbom.json',
                fingerprint: true,
                allowEmptyArchive: true
            )
        }
        
        success {
            echo 'Pipeline completed successfully.'
            withCredentials([
                string(credentialsId: 'slack-webhook', variable: 'SLACK_WEBHOOK')
            ]) {
                sh '''
                    curl -X POST \
                      -H "Content-Type: application/json" \
                      --data '{"text":"SUCCESS: DevSecOps Pipeline #'"${BUILD_NUMBER}"' - Image: '"${IMAGE_NAME}:${IMAGE_TAG}"'"}' \
                      $SLACK_WEBHOOK
                '''
            }
        }
        
        failure {
            echo 'Pipeline failed.'
            withCredentials([
                string(credentialsId: 'slack-webhook', variable: 'SLACK_WEBHOOK')
            ]) {
                sh '''
                    curl -X POST \
                      -H "Content-Type: application/json" \
                      --data '{"text":"FAILED: DevSecOps Pipeline #'"${BUILD_NUMBER}"' - Check Jenkins console for details"}' \
                      $SLACK_WEBHOOK
                '''
            }
        }
    }
}

