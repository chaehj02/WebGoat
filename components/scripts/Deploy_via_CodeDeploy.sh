#!/bin/bash
source components/dot.env
sh '''
aws s3 cp $BUNDLE s3://$S3_BUCKET/$BUNDLE --region $REGION

aws deploy create-deployment \
    --application-name $DEPLOY_APP \
    --deployment-group-name $DEPLOY_GROUP \
    --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
    --s3-location bucket=$S3_BUCKET,bundleType=zip,key=$BUNDLE \
    --region $REGION
'''