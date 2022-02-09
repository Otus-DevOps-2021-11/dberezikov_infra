#!/bin/bash

if [ "$1" == "--list" ] ; then
  if [ -e $inventory_temp ]; then 
  	  echo "[all]" > inventory_temp
  else
	  touch inventory_temp
	  echo "[all]" > inventory_temp
  fi
  yc compute instance list | awk '{print$10}' | grep -v '^|' | sed -E '/^$/d' >> inventory_temp
  if [ -e $inventory.json ]; then
	  ansible-inventory --list -i inventory_temp > inventory.json
  else 
	  touch inventory.json
	  ansible-inventory --list -i inventory_temp > inventory.json
  fi
  ansible-inventory --list -i inventory_temp
  rm inventory_temp
elif [ "$1" == "--host" ]; then
	  echo '{"_meta": {"hostvars": {}}}'
  else
          echo "{ }"
fi
