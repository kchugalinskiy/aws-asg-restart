#!/bin/bash -e
#
# This script restarts each instance in an auto-scaling group, one at a time, removing the instance from the ELB as it goes
#

#The name of the auto-scaling grpup
AUTOSCALING_GROUP='Test-asg'

DELAY=300





# Fetch details about the ASG
ASG_DETAILS=`aws autoscaling describe-auto-scaling-instances --output text --query "AutoScalingInstances[?AutoScalingGroupName == '${AUTOSCALING_GROUP}'].{InstanceId:InstanceId}"`

#Check the ASG exists
if [ "$ASG_DETAILS" == 'No AutoScalingGroups found' ]; then
    echo "Auto-scaling group '${AUTOSCALING_GROUP}' does not exist"
    exit 1
fi

INSTANCES=()

#Get the ELB associated with this ASG
count=0
for LINE in ${ASG_DETAILS} ; do
    INSTANCEID=$LINE
    INSTANCES+=( "$LINE" )
    let count=count+1
done

# Loop over each instance
for INSTANCE in ${INSTANCES[@]} ; do
    echo $INSTANCE

    ELB_NAME=`aws elb describe-load-balancers --output text --query "LoadBalancerDescriptions[? Instances[? InstanceId == '${INSTANCE}']].{LoadBalancerName:LoadBalancerName}"`
    echo "ELB name = " "$ELB_NAME"
    # Remove instance from ELB
    echo "Removing ${INSTANCE} from ${ELB_NAME}"
    aws elb deregister-instances-from-load-balancer --load-balancer-name ${ELB_NAME} --instances ${INSTANCE}
    sleep 2

    # # Wait for the instance to be removed from ELB
    echo "Waiting for ${INSTANCE} to be removed from ${ELB_NAME}"
    while [ `aws elb describe-instance-health --load-balancer-name "${ELB_NAME}" --output text --query "InstanceStates[? InstanceId == '${INSTANCE}'].{State:State}"` == "InService" ]; do
        sleep 2
        echo -n '.'
    done

    # Terminate the instance
    echo "Terminating ${INSTANCE}"
    aws ec2 terminate-instances --instance-ids ${INSTANCE}

    # Wait for ASG to recover before killing the next server
    echo "Sleeping for ${DELAY} seconds whilst the ASG recovers"
    sleep ${DELAY}
    echo -n '.'
done
