#!/bin/bash
set -e

function getPods() {
    local val='';
    while [ true ]; do
        val=`kubectl get pods -n ${NAMESPACE} --selector="name=${1}" -o $2`
        if [[ $val != '' ]] || [[ $? -eq 0 ]]; then break; fi
    done
    echo "${val}"
}

function watchPods() {
    kubectl get pods --watch -a -n ${NAMESPACE} --selector="name=${1}" -o $2
}

function getLogs() {
    kubectl logs -n ${NAMESPACE} -f $1
}

function deleteJob() {
    kubectl delete job -n ${NAMESPACE} $1
}

function deployOutput() {
     echo "=== START: DEPLOY TASK OUTPUT ============================================="
     getLogs $( getPods $TASK_NAME 'jsonpath={.items[0].metadata.name}' )
     echo "=== END: DEPLOY TASK OUTPUT ==============================================="
}

function deployTasks() {
    # cleanup any stale deploy-tasks jobs
    export TASK_STAGE=$1
    export TASK_NAME=${NAME}-${TASK_STAGE}-deploy-tasks
    kubectl delete job -n ${NAMESPACE} ${TASK_NAME} 2&> /dev/null || true
    # Create pre deploy scripts
    cat deploy-tasks.yaml | envsubst | kubectl apply -n ${NAMESPACE} -f -

    while [ true ]; do
        phase=`getPods ${TASK_NAME} 'jsonpath={.items[0].status.phase}'`
        echo -ne "Deploy Tasks Status: $phase"\\r
        if [[ "$phase" == "Failed" && "$TASK_STAGE" == "pre" ]]; then
         deployOutput
         echo '!!! Deploy canceled. deploy-tasks failed.'
         deleteJob ${TASK_NAME}
         exit 1;
        fi
        if [ "$phase" == "Succeeded" ]; then
         deployOutput
         deleteJob ${TASK_NAME}
         break;
        fi
    done
}

function runWebDeployment(){
    cat web-deployment.yaml | envsubst | kubectl apply -n ${NAMESPACE} -f -
    kubectl rollout status -n ${NAMESPACE} deployment/${DEPLOY_NAME}
}

function runJobsDeployment(){
    cat sidekiq-deployment.yaml | envsubst | kubectl apply -n ${NAMESPACE} -f -
    kubectl rollout status -n ${NAMESPACE} deployment/${DEPLOY_NAME}
}


function applyCrons(){
    FILES=crons/*
    for f in $FILES
    do
       cat $f | envsubst | kubectl apply -f -
    done
}

#Below could be quay.io, ECR, GCR, and Docker
export IMAGE_REPO=
export NAME=$1
export CERT=$5
export REGION=$4
export SHA=$2
export NAMESPACE=$3
export REPLICAS=$6
export IMAGE="$IMAGE_REPO/$NAME:$SHA"
export DEPLOY_NAME=$NAME-deployment
export DATE=`date +%s`

echo "deploying $IMAGE to stage: $NAMESPACE"
echo "running pre deploy tasks"
deployTasks "pre"
echo "deploying..."
runWebDeployment
runJobsDeployment
applyCrons
echo "Deploy complete"
