#!/bin/bash

current_version=$(kubectl version | grep -i server | cut -d '.' -f2)
echo "Current Kubernetes Minor Version: $current_version"

next_version=$((current_version + 1))
echo "Checking for deprecated APIs in Kubernetes 1.$next_version..."

