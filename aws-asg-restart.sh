#!/bin/bash -e
#
# This script restarts each instance in an auto-scaling group, one at a time, removing the instance from the ELB as it goes
#

#The name of the auto-scaling grpup
AUTOSCALING_GROUP='Test-asg'

DELAY=300





# Fetch details about the ASG
ASG_DETAILS=`as-describe-auto-scaling-groups ${AUTOSCALING_GROUP}`

#Check the ASG exists
if [ "$ASG_DETAILS" == 'No AutoScalingGroups found' ]; then
    echo "Auto-scaling group '${AUTOSCALING_GROUP}' does not exist"
    exit 1
fi

INSTANCES=()

#Get the ELB associated with this ASG
OIFS="${IFS}"
NIFS=$'\n'
IFS="${NIFS}"
count=0
for LINE in ${ASG_DETAILS} ; do
    if [ $count -eq 0 ]; then
        ELB_NAME=`echo $LINE|awk '{ print $5}'`
        echo $ELB_NAME
    else
        INSTANCENAME=`echo $LINE|awk '{ print $2}'`
        INSTANCES+=($INSTANCENAME)
    fi
    let count=count+1
done
IFS="${OIFS}"

# Loop over each instance
for INSTANCE in ${INSTANCES[@]} ; do
    # Remove instance from ELB
    echo "Removing ${INSTANCE} from ${ELB_NAME}"
    elb-deregister-instances-from-lb ${ELB_NAME} --instances ${INSTANCE}
    sleep 2

    # Wait for the instance to be removed from ELB
    echo "Waiting for ${INSTANCE} to be removed from ${ELB_NAME}"
    while [ `elb-describe-instance-health ${ELB_NAME} | grep ${INSTANCE} | wc -l` -ne 0 ]; do
        sleep 2
        echo -n '.'
    done

    # Terminate the instance
    echo "Terminating ${INSTANCE}"
    ec2-terminate-instances ${INSTANCE}

    # Wait for ASG to recover before killing the next server
    echo "Sleeping for ${DELAY} seconds whilst the ASG recovers"
    sleep ${DELAY}
    echo -n '.'
done
