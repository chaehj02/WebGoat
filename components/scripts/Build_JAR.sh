#!/bin/bash

# Maven이 있는 경로를 명시적으로 추가
export PATH=/usr/bin:$PATH
sh 'mvn clean package -DskipTests'