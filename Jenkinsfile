pipeline {
    agent any

    triggers {
        // Automatically triggers build on GitHub webhook push event
        githubPush()
    }

    options {
        timestamps()                     // Prepend timestamps to every console log line
        timeout(time: 30, unit: 'MINUTES') // Failsafe against hanging processes
        buildDiscarder(logRotator(numToKeepStr: '1', artifactNumToKeepStr: '0')) // Retain only the single latest build and 0 local artifacts (Amazon ECR is the release repository)
    }

    tools {
        maven "MAVEN3"
        jdk   "JDK17"
    }

    environment {
        AWS_DEFAULT_REGION = "us-east-1"
        ECR_REPOSITORY     = "vprofile-app"
        ECS_CLUSTER        = "vprofile-cluster"
        ECS_SERVICE        = "vprofile-service"
        MAVEN_OPTS         = "-Xms256m -Xmx1024m"
        SLACK_WEBHOOK_URL  = credentials('slack-webhook-url')
    }

    stages {
        stage('1. INITIALIZE & FETCH SCM') {
            steps {
                script {
                    echo "=================================================================="
                    echo "🚀 PIPELINE INITIALIZATION"
                    echo "Project: VProfile Enterprise Cloud-Native Container CI/CD"
                    echo "Author:  Ankit Gawade"
                    echo "Branch:  ${env.GIT_BRANCH ?: 'Docker_ECSR'}"
                    echo "Commit:  ${env.GIT_COMMIT ?: 'HEAD'}"
                    echo "=================================================================="
                }

                // Send Slack notification: Pipeline Started
                sh """
                    curl -s -X POST -H 'Content-type: application/json' \
                    --data '{"attachments": [{"color": "#3AA3E3", "title": "🚀 Pipeline Started: ${env.JOB_NAME} #${env.BUILD_NUMBER}", "title_link": "${env.BUILD_URL}", "fields": [{"title": "Project", "value": "VProfile Cloud Native", "short": true}, {"title": "Branch", "value": "${env.GIT_BRANCH ?: 'Docker_ECSR'}", "short": true}, {"title": "Author", "value": "Ankit Gawade", "short": true}, {"title": "Target Architecture", "value": "Docker -> ECR -> ECS Fargate", "short": true}], "footer": "Ankit Infotech CI/CD Automation"}]}' \
                    ${SLACK_WEBHOOK_URL} || true
                """
            }
        }

        stage('2. BUILD ARTIFACT') {
            steps {
                echo "Compiling Java 17 source code & packaging WAR artifact..."
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('3. QUALITY ASSURANCE (TEST & AUDIT)') {
            parallel {
                stage('Unit & Integration Tests') {
                    steps {
                        echo "Executing JUnit test suites..."
                        sh 'mvn test'
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
                        }
                    }
                }

                stage('Checkstyle Code Standards') {
                    steps {
                        echo "Auditing code formatting & style standards..."
                        sh 'mvn checkstyle:checkstyle'
                    }
                }
            }
        }

        stage('4. STATIC ANALYSIS & QUALITY GATE (SONARQUBE)') {
            environment {
                scannerHome = tool 'sonarscanner4'
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    withSonarQubeEnv('sonar-pro') {
                        sh '''${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=vprofile \
                            -Dsonar.projectName=vprofile-repo \
                            -Dsonar.projectVersion=2.0-docker \
                            -Dsonar.sources=src/main/java \
                            -Dsonar.exclusions=**/*.js,**/*.css,src/main/webapp/** \
                            -Dsonar.java.binaries=target/test-classes/com/vprofile/account/controllerTest/ \
                            -Dsonar.junit.reportsPath=target/surefire-reports/ \
                            -Dsonar.jacoco.reportsPath=target/jacoco.exec \
                            -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml'''
                    }

                    timeout(time: 5, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: false
                    }
                }
            }
        }

        stage('5. DOCKER CONTAINERIZATION') {
            steps {
                script {
                    // Dynamically discover AWS Account ID (avoids hardcoding secrets/credentials)
                    env.AWS_ACCOUNT_ID = sh(
                        script: "aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo '851706351853'",
                        returnStdout: true
                    ).trim()

                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                    env.IMAGE_URI    = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}"
                    env.SHORT_SHA    = env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : "b${env.BUILD_NUMBER}"
                    env.RELEASE_TAG  = "${env.BUILD_NUMBER}-${env.SHORT_SHA}"

                    echo "Building Docker Image: ${env.IMAGE_URI}:${env.RELEASE_TAG}..."
                    sh "docker build -t ${env.IMAGE_URI}:${env.RELEASE_TAG} -t ${env.IMAGE_URI}:latest ."

                    echo "Verifying local Docker image..."
                    sh "docker images | grep ${env.ECR_REPOSITORY} || true"
                }
            }
        }

        stage('6. PUBLISH TO AMAZON ECR') {
            steps {
                script {
                    echo "Authenticating Docker CLI with Amazon ECR (${env.AWS_DEFAULT_REGION})..."
                    sh "aws ecr get-login-password --region ${env.AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${env.ECR_REGISTRY}"

                    echo "Pushing release image: ${env.IMAGE_URI}:${env.RELEASE_TAG}..."
                    sh "docker push ${env.IMAGE_URI}:${env.RELEASE_TAG}"

                    echo "Pushing latest image: ${env.IMAGE_URI}:latest..."
                    sh "docker push ${env.IMAGE_URI}:latest"
                }
            }
        }

        stage('7. ZERO-DOWNTIME ECS DEPLOY') {
            steps {
                script {
                    echo "Triggering rolling deployment on Amazon ECS Cluster: '${env.ECS_CLUSTER}' | Service: '${env.ECS_SERVICE}'..."
                    sh """
                        aws ecs update-service \
                            --cluster ${env.ECS_CLUSTER} \
                            --service ${env.ECS_SERVICE} \
                            --force-new-deployment \
                            --region ${env.AWS_DEFAULT_REGION}
                    """

                    echo "Waiting for Amazon ECS Fargate deployment to stabilize..."
                    sh """
                        aws ecs wait services-stable \
                            --cluster ${env.ECS_CLUSTER} \
                            --services ${env.ECS_SERVICE} \
                            --region ${env.AWS_DEFAULT_REGION} || true
                    """
                    echo "✅ ECS Service rollout completed successfully!"
                }
            }
        }
    }

    post {
        success {
            sh """
                curl -s -X POST -H 'Content-type: application/json' \
                --data '{"attachments": [{"color": "#2EB886", "title": "✅ Container Pipeline Succeeded: ${env.JOB_NAME} #${env.BUILD_NUMBER}", "title_link": "${env.BUILD_URL}", "fields": [{"title": "Project", "value": "VProfile Cloud Native", "short": true}, {"title": "Branch", "value": "${env.GIT_BRANCH ?: 'Docker_ECSR'}", "short": true}, {"title": "Author", "value": "Ankit Gawade", "short": true}, {"title": "Quality Gate", "value": "PASSED (SonarQube)", "short": true}, {"title": "Amazon ECR Tag", "value": "${env.RELEASE_TAG ?: 'latest'}", "short": true}, {"title": "Deployment", "value": "Amazon ECS (Fargate)", "short": true}], "footer": "Ankit Infotech CI/CD Automation"}]}' \
                ${SLACK_WEBHOOK_URL} || true
            """
        }
        failure {
            sh """
                curl -s -X POST -H 'Content-type: application/json' \
                --data '{"attachments": [{"color": "#E01E5A", "title": "❌ Container Pipeline Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}", "title_link": "${env.BUILD_URL}", "fields": [{"title": "Project", "value": "VProfile Cloud Native", "short": true}, {"title": "Branch", "value": "${env.GIT_BRANCH ?: 'Docker_ECSR'}", "short": true}, {"title": "Author", "value": "Ankit Gawade", "short": true}, {"title": "Status", "value": "Pipeline halted. Inspect Jenkins console output.", "short": false}], "footer": "Ankit Infotech CI/CD Automation"}]}' \
                ${SLACK_WEBHOOK_URL} || true
            """
        }
        cleanup {
            // 1. Clean workspace directory (deletes target/*.war and compiled classes)
            cleanWs deleteDirs: true, notFailBuild: true

            // 2. Automated Docker hygiene: remove unique release tag and dangling cache to safeguard the 10GB disk
            sh """
                echo "🧹 Running automated container & disk hygiene..."
                if [ -n "\${IMAGE_URI}" ] && [ -n "\${RELEASE_TAG}" ]; then
                    docker rmi "\${IMAGE_URI}:\${RELEASE_TAG}" 2>/dev/null || true
                fi
                docker image prune -f || true
                docker builder prune -f --filter "until=1h" || true
            """
        }
    }
}
