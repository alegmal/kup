#!/usr/bin/env bash

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is not installed. Please install jq to proceed."
    echo "brew install jq"
    echo "sudo apt-get install jq"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is not installed. Please install kubectl to proceed."
    exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "kubectl is not configured or not connected to any cluster."
    exit 1
fi

deprecated_list=$(jq -n '{}')

# Function to add an API change to a specific Kubernetes version
add_change() {
    local k8s_minor=k$1  # e.g., "k25"
    local kind=$2        # e.g., "HorizontalPodAutoscaler"
    local new_version=$3 # e.g., "autoscaling/v1"

    deprecated_list=$(echo "$deprecated_list" | jq --arg v "$k8s_minor" --arg k "$kind" --arg nv "$new_version" '
    .[$v][$k] = $nv
  ')
}

# Add changes
add_change "25" "HorizontalPodAutoscaler" "autoscaling/v2"
add_change "25" "Cronjob" "batch/v1"
add_change "25" "EndpointSlice" "discovery.k8s.io/v1"
add_change "25" "PodDisruptionBudget" "policy/v1"

add_change "26" "FlowSchema" "flowcontrol.apiserver.k8s.io/v1beta3"
add_change "26" "HorizontalPodAutoscaler" "autoscaling/v2"

add_change "29" "PriorityLevelConfiguration" "flowcontrol.apiserver.k8s.io/v1"
add_change "29" "FlowSchema" "flowcontrol.apiserver.k8s.io/v1"

add_change "32" "PriorityLevelConfiguration" "flowcontrol.apiserver.k8s.io/v1"
add_change "32" "FlowSchema" "flowcontrol.apiserver.k8s.io/v1"

echo "deprecated list:"
echo "$deprecated_list"

current_version=$(kubectl version | grep -i server | cut -d '.' -f2)
echo "Current Kubernetes Minor Version: $current_version"

next_version=$((current_version + 1))
echo "Checking for deprecated APIs in Kubernetes 1.$next_version..."

deprecated_kinds=$(echo "$deprecated_list" | jq .k$next_version)
if [[ $deprecated_kinds == "null" ]]; then
    echo "No deprecated APIs in 1.$next_version"
    exit 0
fi

echo 'found_deprecated_api="false"' > /tmp/result
echo "$deprecated_kinds" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read -r kind new_api_version; do
    echo "Checking $kind objects for deprecated API version (not matching $new_api_version)..."

    # Query for the objects of this kind and check if they need updating
    kubectl get "$kind" --all-namespaces -o json | jq -c ".items[] | select(.apiVersion != \"$new_api_version\")" | while read -r item; do
        echo 'found_deprecated_api="true"' > /tmp/result

        name=$(echo "$item" | jq -r '.metadata.name')
        namespace=$(echo "$item" | jq -r '.metadata.namespace')
        apiVersion=$(echo "$item" | jq -r '.apiVersion')

        # Print details of the deprecated API
        echo "Deprecated $kind object found:"
        echo "1. Name: $name"
        echo "2. Namespace: $namespace"
        echo "3. Kind: $kind"
        echo "4. Current API Version: $apiVersion"
        echo "5. New API Version: $new_api_version"
        echo "-----------------------------------"
        echo ""
    done
done

source /tmp/result
if [[ $found_deprecated_api == "false" ]]; then
    echo ""
    echo "Found no deprecated APIs in the cluster!"
    exit 0
fi

echo ""
echo "!! Change API and possibly object schema before upgrading to the next Kubernetes version !!"
echo "Documentation: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-$next_version"
exit 1