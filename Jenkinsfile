pipeline {
    agent any

    environment {
        IMAGE_NAME = "ghcr.io/muhammad-ahmadd-shafiq/devsecops-app"
        IMAGE_TAG = "${GIT_COMMIT.take(7)}"
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
		    --error-code 1
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
                    --severity HIGH,CRITICAL --ignore-unfixed \
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
        }

        failure {
            echo 'Pipeline failed.'
        }
    }
}
