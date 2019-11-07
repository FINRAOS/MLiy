#!/bin/bash
# Copyright 2017 MLiy Contributors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

########################################
# GUIDE
#
# This script will automatically terminate the cluster it's on after checking JupyterHub
# and Livy activity. The interval to do the check and the idle "threshold" can be
# customized. Setting the threshold to 0 (or leaving the params blank) will disable the
# script.
#
# Every function of the script can be used as-is by specifying the function after the name of the script.
# This offsets the need to source the script and allows it to be more isolated from everything else.
# ./auto-terminate.sh getJupyterHubApiKey
# ./auto-terminate.sh isLivyIdle
# ./auto-terminate.sh main --minutes 20 --seconds 5 --hours 20 --days 3
# etc.
#
# "main" runs the "terminate" function.
#
# There's a helper function to set the cron.d file with all the necessary args.
# -- Check every 5 minutes for idleness of more than 2 days and 20 minutes --
# ./auto-terminate.sh setAutoTerminate --interval "*/5 * * * *" --days 2 --minutes 20
#
# A simple log file is created in:
# /var/log/mliy/terminate.log
#
# The script will ideally be in /opt/mliy, but it can be customized.
#
########################################

########################################
# VARS
########################################

IDLE_TIME=""

SCRIPT_PATH=/opt/mliy

LOG_PATH=/var/log/mliy
LOG_FILE=terminate.log
LOGS="$LOG_PATH"/"$LOG_FILE"

mkdir -p "$LOG_PATH"
if [ ! -f "$LOGS" ]; then
    touch "$LOGS"
fi

PRIVATE_IP=$(curl -sk http://169.254.169.254/latest/meta-data/local-ipv4)
CLUSTER_ID=$(cat /mnt/var/lib/info/job-flow.json | jq -r ".jobFlowId")
STACK_NAME=$(aws emr describe-cluster --output text --cluster-id "$CLUSTER_ID" --query 'Cluster.Tags[?Key==`Name`].Value | [0]')



########################################
# HELPER FUNCTIONS
########################################

function logger()
{
    NOW=$(date +%Y-%m-%d-%H:%M:%S)
    echo "[$NOW]("${FUNCNAME[1]}") $1" >> "$LOGS"
}

# Code modified from:
# s3://emr-shutdown-blogartifacts/jupyterhub_addAdminToken.sh
function getJupyterhubApiKey()
{
    logger "Starting"
    config_file=/etc/jupyter/conf/jupyterhub_config.py
    if [ -f "$config_file" ]; then
       admin_users=`cat /etc/jupyter/conf/jupyterhub_config.py | grep 'c.Authenticator.admin_users' | awk '{print $3}'`

       # We leave the single quotes in for easier processing later in the "sudo bash -c ..." commands
       users=`echo "$admin_users" | awk '{print substr($0, 2, length($0) - 2)}'`
       lstusers=`echo "$users" | tr "," "\n"`

       for usr in "$lstusers"
       do
          admin_user=$(echo "$usr")
          break
       done

       if grep -q 'c.JupyterHub.api_tokens' "$config_file" ; then
          echo $(grep ": $admin_user," "$config_file" | sed "s/: $admin_user,//g" | sed "s/[',:, ]//g")
       else

          if grep -q 'c.Authenticator.admin_users' /etc/jupyter/conf/jupyterhub_config.py ; then

            admin_token=`openssl rand -hex 32`
            admin_token="'${admin_token}'"

            sudo bash -c 'echo "c.JupyterHub.api_tokens = {" >> /etc/jupyter/conf/jupyterhub_config.py'
            sudo bash -c 'echo "    '"$admin_token"' : '"$admin_user"'," >> /etc/jupyter/conf/jupyterhub_config.py'
            sudo bash -c 'echo "}" >> /etc/jupyter/conf/jupyterhub_config.py'

            sudo docker stop jupyterhub >/dev/null 2>&1
            sudo docker start jupyterhub >/dev/null 2>&1
            echo "$admin_token" | sed "s/[', ]//g"
          else
            logger "No admin users - API Token cannot be configured"
          fi
       fi
    fi
    logger "Exiting"
}


function getInitialIdle()
{
    # Calculate idleness based off of the setup-cluster completion time
    step_completion=$(aws emr list-steps --cluster-id "$CLUSTER_ID" | \
    jq -r '.Steps
    | map(select(.Name | contains("setup-cluster")))
    | map(select(.Status.State | contains("COMPLETED")))
    | .[] .Status.Timeline.EndDateTime' \
    | head -c10)

    logger "Cluster setup step completed at: $step_completion"

    time_diff=$(( $1 - $step_completion ))

    logger "Resource has been idle for: $time_diff s"

    if [[ "$time_diff" -lt "$IDLE_TIME" ]]
    then
        logger "Resource idle threshold has not yet been reached."
        echo 0
    else
        logger "Resource has met the idle threshold."
        echo 1
    fi
}

function setAutoTerminate()
{
    logger "Starting"
    while [[ $# > 1 ]]; do
        key="$1"

        case "$key" in
            --seconds)
            export IDLE_SECONDS="$2"
            shift
            ;;
            --minutes)
            export IDLE_MINUTES="$2"
            shift
            ;;
            --hours)
            export IDLE_HOURS="$2"
            shift
            ;;
            --days)
            export IDLE_DAYS="$2"
            shift
            ;;
            --cron-interval)
            export INTERVAL="$2"
            shift
            ;;
            *)
            # unknown option
            ;;
        esac
    shift
    done

    re='^[0-9]+$'
    if [[ -z "$IDLE_SECONDS" ]] || ! [[ "$IDLE_SECONDS" =~ $re ]] ; then IDLE_SECONDS=0;fi
    if [[ -z "$IDLE_MINUTES" ]] || ! [[ "$IDLE_MINUTES" =~ $re ]] ; then IDLE_MINUTES=0;fi
    if [[ -z "$IDLE_HOURS" ]] || ! [[ "$IDLE_HOURS" =~ $re ]] ; then IDLE_HOURS=0;fi
    if [[ -z "$IDLE_DAYS" ]] || ! [[ "$IDLE_DAYS" =~ $re ]] ; then IDLE_DAYS=0;fi
    if [[ -z "$INTERVAL" ]] ; then INTERVAL="*/5 * * * *";fi

    IDLE_TIME=$(($IDLE_SECONDS+$IDLE_MINUTES*60+IDLE_HOURS*3600+IDLE_DAYS*86400))
    if [[ "$IDLE_TIME" -gt 0 ]]; then
        logger "Idle threshold: $IDLE_TIME"
        logger "Cron job interval: $INTERVAL"
        printf "$INTERVAL root $SCRIPT_PATH/auto_terminate.sh main \
        --seconds $IDLE_SECONDS \
        --minutes $IDLE_MINUTES \
        --hours $IDLE_HOURS \
        --days $IDLE_DAYS\n" > /etc/cron.d/mliy_auto_terminate
    fi
    logger "Exiting"
}

########################################
# FUNCTIONS
########################################

function isJupyterhubIdle()
{
    logger "Starting"
    #logger "Idle threshold: $IDLE_TIME"

    API_TOKEN=`getJupyterhubApiKey`
    #TODO get admin_user(s) (jovyan) dynamically
    timestamps="$(curl -skL -H "Authorization: token $API_TOKEN" http://localhost:9443/hub/api/users | jq -r '. - map(select(.name == "jovyan")) | .[] .last_activity')"

    current_date=$((`date +%s`))
    hub_idle=1

    if [[ ! -z "$timestamps" ]]; then
        while read -r line; do
            idle_date=$(date +%s -d "$line")
            time_diff=$(($current_date-$idle_date))

            logger "JupyterHub has been idle for: $time_diff s"

            if [[ "$IDLE_TIME" -gt "$time_diff" ]]; then
                hub_idle=0
                break
            fi
        done <<< "$timestamps"
    else
        hub_idle=`getInitialIdle "$current_date"`
    fi

    echo "$hub_idle"
    logger "Exiting"
}

# Code modified from:
# s3://emr-shutdown-blogartifacts/pushShutDownMetrin.sh yarnJobsStatusChk()
function isLivyIdle()
{
    logger "Starting"
    #logger "Idle threshold: $IDLE_TIME"

    appid=`curl -skL http://"$PRIVATE_IP":18080/api/v1/applications?status=running | jq -r '.[].id'`
    current=$(date +%s)

    # If all apps are finished, their jobs need to be checked for their timestamp
    if [[ -z "$appid" ]]; then
        appid=`curl -skL http://"$PRIVATE_IP":18080/api/v1/applications | jq -r '.[].id'`
    fi

    livy_idle=0

    # Livy is empty to begin with.
    if [[ -z "$appid" ]]; then
        livy_idle=`getInitialIdle "$current"`
    fi

    for i in `echo "$appid"`
    do
        logger "Checking Livy app $i"
        running_jobs=`curl -skL http://"$PRIVATE_IP":18080/api/v1/applications/"$i"/jobs?status=running| \
        jq -r '.[].completionTime' | head -n 1`

        if [[ -n "$running_jobs" ]]; then
            break
        else
            completion_date=`curl -skL http://"$PRIVATE_IP":18080/api/v1/applications/"$i"/jobs?status=succeeded| \
            jq -r '.[].completionTime' | head -n 1`

            if [[ -z "$completion_date" ]]; then
                completion_date=`curl -skL http://"$PRIVATE_IP":18080/api/v1/applications/"$i" | \
                jq -r '.attempts[].endTime'`
            fi

            completion_time=${completion_date:0:26}
            target=$(date +%s -d "$completion_time")

            if [[ -n "$completion_date" ]] && [[ ! "$target" -eq -1 ]]; then
                time_diff=$(($current - $target))
                logger "Livy app $i has been completed for: $time_diff s"

                if [[ "$time_diff" -lt "$IDLE_TIME" ]]
                then
                    logger "Livy app has not reached the idle threshold."
                    livy_idle=0
                    break
                else
                    logger "Livy app has been idle."
                    livy_idle=1
                fi
            elif [[ -z "$completion_date" ]]; then
                # We put a break in here because the app could have no completion time and no job,
                # which means it's running.
                logger "Livy app is running."
                break
            else
                # We also break here since the completion time could be the epoch time,
                # which means it's running.
                logger "Livy app is running."
                break
            fi
        fi
    done;

    echo "$livy_idle"
    logger "Exiting"
}

function terminate()
{
    logger "Starting"
    CLUSTER_ID=$(cat /mnt/var/lib/info/job-flow.json | jq -r ".jobFlowId")

    STACK_NAME=$(aws emr describe-cluster --output text --cluster-id "$CLUSTER_ID" --query 'Cluster.Tags[?Key==`Name`].Value | [0]')

    logger "Terminating Cloudformation stack"
    aws cloudformation delete-stack --stack-name "$STACK_NAME"

    logger "Terminating EMR cluster"
    # Fallback: terminate cluster and not the CF stack if CF stack deletion failed
    aws emr terminate-clusters --cluster-ids "$CLUSTER_ID"

    logger "Exiting"
}

# Check SSH (debugging purposes)
# TODO Implement

########################################
# MAIN
########################################

function main()
{
    logger "Starting"
    while [[ $# > 1 ]]; do
        key="$1"

        case "$key" in
            --seconds)
            export IDLE_SECONDS="$2"
            shift
            ;;
            --minutes)
            export IDLE_MINUTES="$2"
            shift
            ;;
            --hours)
            export IDLE_HOURS="$2"
            shift
            ;;
            --days)
            export IDLE_DAYS="$2"
            shift
            ;;
            *)
            # unknown option
            ;;
        esac
    shift
    done

    if [[ -z "$IDLE_SECONDS" ]] || ! [[ "$IDLE_SECONDS" =~ $re ]] ; then IDLE_SECONDS=0;fi
    if [[ -z "$IDLE_MINUTES" ]] || ! [[ "$IDLE_MINUTES" =~ $re ]] ; then IDLE_MINUTES=0;fi
    if [[ -z "$IDLE_HOURS" ]] || ! [[ "$IDLE_HOURS" =~ $re ]] ; then IDLE_HOURS=0;fi
    if [[ -z "$IDLE_DAYS" ]] || ! [[ "$IDLE_DAYS" =~ $re ]] ; then IDLE_SECONDS=0;fi

    export IDLE_TIME=$(($IDLE_SECONDS+$IDLE_MINUTES*60+IDLE_HOURS*3600+IDLE_DAYS*86400))
    logger "Idle threshold set to $IDLE_TIME seconds"

    JUPYTER=`isJupyterhubIdle`
    LIVY=`isLivyIdle`

    logger "JupyterHub idle status: $JUPYTER"
    logger "LIVY idle status: $LIVY"
    if [[ "$IDLE_TIME" -gt 0 ]]; then
        if [[ ("$JUPYTER" -eq 1) && \
              ("$LIVY" -eq 1) ]]; then
            logger "Terminating cluster."

            terminate
        else
            logger "Cluster has not reached its idle threshold."
        fi
    fi
    logger "Exiting"
}



"$@"