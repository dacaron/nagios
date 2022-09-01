#!/bin/bash

# This script requires jq.
# $USER1$/check_vcenter_health.sh $HOSTADDRESS$ $ARG1$ ; where $ARG1$=service or vcha
# Possible services: applmgmt, database-storage, load, mem, software-packages, storage, swap, system
# vCenter credentials must be in the ~/.netrc file. See netrc(5) man page for its syntax.

OK=green
WARN=yellow
ALERT=orange
CRIT=red
UNK=grey

HOSTADDRESS=$1
SERVICE=$2
SESSIONID=`curl -n -ksX POST -H "Content-Type: application/json" -H "Accept: application/json" -H "vmware-use-header-authn: test" -H "vmware-api-session-id: null" "https://${HOSTADDRESS}/rest/com/vmware/cis/session" | jq -r .[]`

case $SERVICE in
  load|mem|storage|swap)
    HEALTH=`curl -ksX GET -H "Content-Type: application/json" -H "Accept: application/json" -H "vmware-api-session-id: ${SESSIONID}" "https://${HOSTADDRESS}/rest/appliance/health/${SERVICE}" | jq -r .[]`
    MESSAGE=`curl -ksX GET -H "Content-Type: application/json" -H "Accept: application/json" -H "vmware-api-session-id: ${SESSIONID}" "https://${HOSTADDRESS}/rest/appliance/health/${SERVICE}/messages" | jq .[]`
    if [ "$HEALTH" == "$OK" ]; then
      echo "$SERVICE is $HEALTH"
      echo "$MESSAGE"
      exit 0
    elif [ "$HEALTH" == "$WARN" ]; then
      echo "$SERVICE is $HEALTH"
      echo "$MESSAGE"
      exit 1
    elif [ "$HEALTH" == "$ALERT" ]; then
      echo "$SERVICE is $HEALTH"
      echo "$MESSAGE"
      exit 1
    elif [ "$HEALTH" == "$CRIT" ]; then
      echo "$SERVICE is $HEALTH"
      echo "$MESSAGE"
      exit 2
    elif [ "$HEALTH" == "$UNK" ]; then
      echo "$SERVICE is $HEALTH"
      echo "$MESSAGE"
      exit 3
    fi
    ;;
  applmgmt|database-storage|software-packages|system)
    HEALTH=`curl -ksX GET -H "Content-Type: application/json" -H "Accept: application/json" -H "vmware-api-session-id: ${SESSIONID}" "https://${HOSTADDRESS}/rest/appliance/health/${SERVICE}" | jq -r .[]`
    if [ "$HEALTH" == "$OK" ]; then
      echo "$SERVICE is $HEALTH"
      exit 0
    elif [ "$HEALTH" == "$WARN" ]; then
      echo "$SERVICE is $HEALTH"
      exit 1
    elif [ "$HEALTH" == "$ALERT" ]; then
      echo "$SERVICE is $HEALTH"
      exit 1
    elif [ "$HEALTH" == "$CRIT" ]; then
      echo "$SERVICE is $HEALTH"
      exit 2
    elif [ "$HEALTH" == "$UNK" ]; then
      echo "$SERVICE is $HEALTH"
      exit 3
    fi
    ;;
  vcha)
    OK_MODE=ENABLED
    OK_HEALTH=HEALTHY
    MODE=`curl -ksX POST -H "Content-Type: application/json" -H "Accept: application/json" -H "vmware-api-session-id: ${SESSIONID}" -d '{ "partial": true }' "https://${HOSTADDRESS}/rest/vcenter/vcha/cluster?action=get" | jq -r '.[] | .mode'`
    HEALTH=`curl -ksX POST -H "Content-Type: application/json" -H "Accept: application/json" -H "vmware-api-session-id: ${SESSIONID}" -d '{ "partial": true }' "https://${HOSTADDRESS}/rest/vcenter/vcha/cluster?action=get" | jq -r '.[] | .health_state'`
    if [ $MODE == $OK_MODE ] && [ $HEALTH == $OK_HEALTH ]; then
      echo mode:$MODE health_state:$HEALTH
      exit 0
    else
      echo mode:$MODE health_state:$HEALTH
      exit 2
    fi
    ;;
esac

echo "something went wrong with the plugin"
exit 3
