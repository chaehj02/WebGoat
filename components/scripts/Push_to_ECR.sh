#!/bin/bash
source components/dot.env
docker push $ECR_REPO:$IMAGE_TAG