#!/bin/bash
yc compute instance create \
  --name reddit-full \
  --hostname reddit-full \
  --cores 2 \
  --core-fraction 5 \
  --memory=2 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1604-lts,size=10GB \
  --network-interface subnet-name=otus,nat-ip-version=ipv4 \
  --metadata serial-port-enable=1 \
  --metadata-from-file user-data=./install-dependencies-deploy-app.yaml
