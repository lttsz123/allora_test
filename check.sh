# 检查节点
# 拷贝文件，然后
# 1.给与权限，运行： chmod +x ./check.sh
# 2.运行： ./check.sh
# 运行实例
read -p "请输入开始节点数字: " num_start
read -p "请输入结束节点数字: " num_end
 
network_height=$(curl -s -X 'GET' 'https://allora-rpc.testnet-1.testnet.allora.network/abci_info' -H 'accept: application/json' | jq -r .result.response.last_block_height)
echo ${network_height}
run_instance() {
  local instance_number=$1
  port_offset=$((i * 10))
  port=$((6000 + port_offset)) 

  echo "正在检查实例 #${instance_number}..."
  # 使用curl命令  
  curl --location "http://localhost:$port/api/v1/functions/execute" --header 'Content-Type: application/json' --data "{  
      \"function_id\": \"bafybeigpiwl3o73zvvl6dxdqu7zqcub5mhg65jiky2xqb4rdhfmikswzqm\",  
      \"method\": \"allora-inference-function.wasm\",  
      \"parameters\": null,  
      \"topic\": \"1\",  
      \"config\": {  
          \"env_vars\": [  
              {  
                  \"name\": \"BLS_REQUEST_PATH\",  
                  \"value\": \"/api\"  
              },  
              {  
                  \"name\": \"ALLORA_ARG_PARAMS\",  
                  \"value\": \"ETH\"  
              },  
              {  
                  \"name\": \"ALLORA_BLOCK_HEIGHT_CURRENT\",  
                  \"value\": \"${network_height}\"  
              }  
          ],  
          \"number_of_nodes\": -1,  
          \"timeout\": 10  
      }  
  }"  | jq
      echo "检查 Updater 节点: curl http://localhost:$((8000 + port_offset))/update"
      curl http://localhost:$((8000 + port_offset))/update
      echo ""
      echo "检查 Inference 节点: curl http://localhost:$((8000 + port_offset))/inference/ETH"
      curl http://localhost:$((8000 + port_offset))/inference/ETH
      echo ""
}

# 主函数
main() {
  for ((i = num_start; i <= num_end; i++)); do
    run_instance $i
  done
}

# 运行主函数
main