#!/bin/bash
# 初始化行数计数器  
num_instances=0  
  
filename=nubit.txt

lines=()

# 使用while循环和read命令读取文件的每一行，并将它们存储在数组中
while IFS= read -r line
do
    lines+=("$line")  # 将读取的行添加到数组中
done < "$filename"
for ((i=0; i<${#lines[@]}; i++)); do
    num_instances=$((num_instances + 1))  
done

  print_message "你可以使用以下命令检查各个节点的状态："
  for ((i = 1; i <= num_instances; i++)); do
    port_offset=$((i * 10))
    echo "实例 #${i}:"
    echo "检查 Worker 节点: curl --location 'http://localhost:$((6000 + port_offset))/api/v1/functions/execute' ..."
    curl --location 'http://localhost:$((6000 + port_offset))/api/v1/functions/execute' \
--header 'Content-Type: application/json' \
--data '{
    "function_id": "bafybeigpiwl3o73zvvl6dxdqu7zqcub5mhg65jiky2xqb4rdhfmikswzqm",
    "method": "allora-inference-function.wasm",
    "parameters": null,
    "topic": "1",
    "config": {
        "env_vars": [
            {
                "name": "BLS_REQUEST_PATH",
                "value": "/api"
            },
            {
                "name": "ALLORA_ARG_PARAMS",
                "value": "ETH"
            }
        ],
        "number_of_nodes": -1,
        "timeout": 10
    }
}'
    echo "检查 Updater 节点: curl http://localhost:$((8000 + port_offset))/update"
    curl http://localhost:$((8000 + port_offset))/update
    echo "检查 Inference 节点: curl http://localhost:$((8000 + port_offset))/inference/ETH"
    curl http://localhost:$((8000 + port_offset))/inference/ETH
    echo ""
  done
}
