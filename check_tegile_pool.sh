#!/bin/bash

# This script requires jq.
# $USER1$/check_tegile_pool.sh -u $ARG1$ -k $ARG2$ -w $ARG3$ -c $ARG4$

usage() {
  echo "Usage: $0 [ -u URL ] [ -k Base64 encoded credentials ] [ -w Warning treshold percentage ] [ -c Critical treshold percentage ]" 1>&2
}
exit_abnormal() {
  usage
  exit 1
}

exit_message() {
  echo "Pool-A: $POOL_A_PERCENT% used";
  echo "Pool-A: $POOL_A_AVAIL_TIB TiB free";
  echo "Pool-B: $POOL_B_PERCENT% used";
  echo "Pool-B: $POOL_B_AVAIL_TIB TiB free";

}

while getopts ":u:k:w:c:" options; do

  case "${options}" in
    u)
      URL=${OPTARG}
      ;;
    k)
      PASSWD=${OPTARG}
      ;;
    w)
      WARN=${OPTARG}
      if ! [[ "$WARN" =~ ^[0-9]+$ ]]; then
        echo "Error: WARN must be a positive, whole number."
        exit_abnormal
      elif ! [ "$WARN" -ge 0 -a "$WARN" -le 100 ]; then
        echo "Error: WARN must be a value between 0-100 ."
        exit_abnormal
      fi
      ;;
    c)
      CRIT=${OPTARG}
      if ! [[ "$CRIT" =~ ^[0-9]+$ ]]; then
        echo "Error: CRIT must be a positive, whole number."
        exit_abnormal
      elif ! [ "$CRIT" -ge 0 -a "$CRIT" -le 100 ]; then
        echo "Error: CRIT must be a value between 0-100 ."
        exit_abnormal
      fi
      ;;
    :)
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal
      ;;
    *)
      exit_abnormal
      ;;
    esac
  done

JSON=$(curl -sX GET -H "Authorization:Basic $PASSWD" -H Content-Type:application/JSON -d '[]' $URL -k)
if  echo "$JSON" | grep -i "Access Denied"; then
    echo "Wrong password, try again"
    exit 2
else
    POOL_A_AVAIL=$(echo "$JSON" | jq '.[] | select(.name == "pool-a") | .availableSize')
    POOL_A_TOTAL=$(echo "$JSON" | jq '.[] | select(.name == "pool-a") | .totalSize')
    POOL_A_USED="$(($POOL_A_TOTAL-$POOL_A_AVAIL))"
    POOL_A_AVAIL_TIB=`printf "%.2f" $(bc -l <<< "$POOL_A_AVAIL / 1099511627776")`
    POOL_A_USED_TIB=`printf "%.2f" $(bc -l <<< "$POOL_A_USED / 1099511627776")`
    POOL_A_TOTAL_TIB=`printf "%.2f" $(bc -l <<< "$POOL_A_TOTAL / 1099511627776")`
    POOL_A_PERCENT=`printf "%.0f" $(bc -l <<< "$POOL_A_USED / $POOL_A_TOTAL * 100")`

    POOL_B_AVAIL=$(echo "$JSON" | jq '.[] | select(.name == "pool-b") | .availableSize')
    POOL_B_TOTAL=$(echo "$JSON" | jq '.[] | select(.name == "pool-b") | .totalSize')
    POOL_B_USED="$(($POOL_B_TOTAL-$POOL_B_AVAIL))"
    POOL_B_AVAIL_TIB=`printf "%.2f" $(bc -l <<< "$POOL_B_AVAIL / 1099511627776")`
    POOL_B_USED_TIB=`printf "%.2f" $(bc -l <<< "$POOL_B_USED / 1099511627776")`
    POOL_B_TOTAL_TIB=`printf "%.2f" $(bc -l <<< "$POOL_B_TOTAL / 1099511627776")`
    POOL_B_PERCENT=`printf "%.0f" $(bc -l <<< "$POOL_B_USED / $POOL_B_TOTAL * 100")`
fi

if [[ $POOL_A_PERCENT -lt $WARN && $POOL_B_PERCENT -lt $WARN ]]; then
    echo "it's all good; | pool-a=$POOL_A_PERCENT pool-b=$POOL_B_PERCENT"
    exit_message
    exit 0

elif [[ ($POOL_A_PERCENT -ge $WARN || $POOL_B_PERCENT -ge $WARN) && ($POOL_A_PERCENT -lt $CRIT && $POOL_B_PERCENT -lt $CRIT) ]]; then
    echo "It's just a warning;| pool-a=$POOL_A_PERCENT pool-b=$POOL_B_PERCENT"
    exit_message
    exit 1

elif [[ $POOL_A_PERCENT -ge $CRIT || $POOL_B_PERCENT -ge $CRIT ]]; then
    echo "Let's get critical; | pool-a=$POOL_A_PERCENT pool-b=$POOL_B_PERCENT"
    exit_message
    exit 2

else
    echo "Something went wrong with the plugin"
    exit_message
    exit 2

fi
