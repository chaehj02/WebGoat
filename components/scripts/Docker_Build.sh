#!/bin/bash
#source components/dot.env
#docker build -t $ECR_REPO:$IMAGE_TAG .

#!/bin/bash
set -o allexport
source components/dot.env
set +o allexport

docker build -t "$ECR_REPO:$IMAGE_TAG" .
