#!/bin/bash
source components/dot.env
sh 'zip -r $BUNDLE appspec.yaml Dockerfile taskdef.json'