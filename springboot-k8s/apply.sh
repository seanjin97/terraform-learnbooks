#!/bin/sh

HELP="Usage: $0 [(-E) localhost|dev ]"

while getopts :E:h f
do
  case "$f" in
    E) env=${OPTARG} ;;
    h) echo "$HELP" >&2
       exit 1 ;;
    *) echo "$HELP" >&2
       exit 1 ;;
  esac
done

if [ "$env" != "dev" ] && [ "$env" != "localhost" ] ; then
   echo "$HELP" >&2
       exit 1 ;
fi

terraform apply -var-file="env/$env.tfvars" -auto-approve