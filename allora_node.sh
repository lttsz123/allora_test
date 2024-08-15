#!/bin/bash
git clone https://github.com/allora-network/allora-chain.git
cd allora-chain
mv docker-compose.yaml bak.docker-compose.yaml.bak
wget -O docker-compose.yaml https://raw.githubusercontent.com/lttsz123/allora_test/main/docker-compose.yaml
cd scripts
rm -rf l1_node.sh
wget -O l1_node.sh https://raw.githubusercontent.com/lttsz123/allora_test/main/l1_node.sh
chmod +x l1_node.sh
cd ..
docker-compose pull
docker-compose up -d
