#!/bin/bash
source components/dot.env
docker build -t $ECR_REPO:$IMAGE_TAG .