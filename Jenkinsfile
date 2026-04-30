pipeline {
    agent any

    environment {
        TARGET_URL = "https://dummyjson.com/"
        LOGIN_URL  = "https://dummyjson.com/auth/login"
        USERNAME   = "emilys"
        PASSWORD   = "emilyspass"
    }

    stages {
        stage('Prepare') {
            steps {
                sh '''
                    sudo apt-get update
                    sudo apt-get install -y jq docker.io curl
                    mkdir -p reports scripts
                    chmod +x scripts/run_full_scan.sh
                    chmod +x scripts/export_discovered_targets.sh
                '''
            }
        }

        stage('Run Full Authenticated Scan') {
            steps {
                sh '''
                    ./scripts/run_full_scan.sh
                '''
            }
        }

        stage('Export Discovered Targets') {
            steps {
                sh '''
                    ./scripts/export_discovered_targets.sh reports
                '''
            }
        }

        stage('Archive Reports') {
            steps {
                archiveArtifacts artifacts: 'reports/*', fingerprint: true
            }
        }
    }

    post {
        success {
            echo 'ZAP scan completed successfully.'
        }
        failure {
            echo 'ZAP scan failed.'
        }
    }
}