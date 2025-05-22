pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_REPO = '535052053335.dkr.ecr.ap-northeast-2.amazonaws.com/wh_1/devpos'
        IMAGE_TAG = 'latest'
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Maven Build') {
            steps { sh 'mvn clean package -DskipTests' }
        }

        stage('Build Docker Image') {
            steps { sh 'docker build -t $ECR_REPO:$IMAGE_TAG .' }
        }

        stage('Login to AWS ECR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'wh1-aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set region $AWS_REGION

                        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps { sh 'docker push $ECR_REPO:$IMAGE_TAG' }
        }

        stage('Trigger CodeDeploy') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'wh1-aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set region $AWS_REGION

                        zip -r deploy2.zip appspec.yaml taskdef.json
                        aws s3 cp deploy.zip s3://webgoat-codedeploy-bucket-soobin/deploy2.zip

                        aws deploy create-deployment \
                          --application-name webgoat-cd-app \
                          --deployment-group-name webgoat-deploy-group \
                          --s3-location bucket=webgoat-codedeploy-bucket-soobin,key=deploy2.zip,bundleType=zip \
                          --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
                          --file-exists-behavior OVERWRITE
                    '''
                }
            }
        }
    }
}
