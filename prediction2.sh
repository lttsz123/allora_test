#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 函数定义
print_message() {
  echo -e "${GREEN}$1${NC}"
}

print_warning() {
  echo -e "${YELLOW}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

# 检查命令是否存在
check_command() {
  if ! command -v $1 &>/dev/null; then
    print_error "$1 未找到。正在安装..."
    return 1
  fi
  return 0
}

# 安装依赖
install_dependencies() {
  print_message "正在安装依赖..."
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl git wget make jq build-essential pkg-config lsb-release libssl-dev libreadline-dev libffi-dev gcc screen unzip lz4 python3 python3-pip
}

# 安装 Docker
install_docker() {
  if ! check_command docker; then
    print_message "正在安装 Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
  fi
}

# 安装 Docker Compose
install_docker_compose() {
  if ! check_command docker-compose; then
    print_message "正在安装 Docker Compose..."
    VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  fi
}

# 设置单个实例
setup_instance() {
  local instance_number=$1
  local wallet_seed=$2

  print_message "正在设置实例 #${instance_number}..."

  # 创建实例目录
  mkdir -p /root/allora-instances/instance-${instance_number}
  cd /root/allora-instances/instance-${instance_number}

  # 克隆仓库
  git clone https://github.com/allora-network/basic-coin-prediction-node .

  # 复制配置文件
  # cp ./config.example.json ./config.json
  sudo rm -rf ./config.json
  cat >/root/allora-instances/instance-${instance_number}/config.json <<EOL
{
  "wallet": {
    "addressKeyName": "$instance_number",
    "addressRestoreMnemonic": "$wallet_seed",
    "alloraHomeDir": "",
    "gas": "1000000",
    "gasAdjustment": 1.0,
    "nodeRpc": "https://158.220.116.212:26657/",
    "maxRetries": 1,
    "delay": 1,
    "submitTx": false
  },
  "worker": [
    {
      "topicId": 1,
      "inferenceEntrypointName": "api-worker-reputer",
      "loopSeconds": 5,
      "parameters": {
        "InferenceEndpoint": "http://inference:8000/inference/{Token}",
        "Token": "ETH"
      }
    },
    {
      "topicId": 2,
      "inferenceEntrypointName": "api-worker-reputer",
      "loopSeconds": 5,
      "parameters": {
        "InferenceEndpoint": "http://inference:8000/inference/{Token}",
        "Token": "ETH"
      }
    },
    {
      "topicId": 7,
      "inferenceEntrypointName": "api-worker-reputer",
      "loopSeconds": 5,
      "parameters": {
        "InferenceEndpoint": "http://inference:8000/inference/{Token}",
        "Token": "ETH"
      }
    }
  ]
}
EOL
  # 修改配置文件
  # sed -i "s/\"addressKeyName\": \".*\"/\"addressKeyName\": \"$instance_number\"/" ./config.json
  # sed -i "s/\"addressRestoreMnemonic\": \".*\"/\"addressRestoreMnemonic\": \"$wallet_seed\"/" ./config.json
  # sed -i "s|\"nodeRpc\": \".*\"|\"nodeRpc\": \"https://sentries-rpc.testnet-1.testnet.allora.network/\"|" ./config.json  

  # 给与初始化脚本运行权限
  chmod +x init.config
  # 执行初始化
  ./init.config

  # 修改docker-compose配置，避免端口或名字冲突
  sed -i "s/- \"8000:8000\"/- \"$((8000 + instance_number)):8000\"/" ./docker-compose.yml
  sed -i "s/container_name: inference-basic-eth-pred/container_name: inference-basic-eth-pred_$instance_number/" ./docker-compose.yml
  sed -i "s/container_name: updater-basic-eth-pred/container_name: updater-basic-eth-pred_$instance_number/" ./docker-compose.yml
  sed -i "s/container_name: worker/container_name: worker_$instance_number/" ./docker-compose.yml
  
  # 运行节点
  docker-compose build
  docker-compose up -d

  # 返回到主目录
  cd /root
}

# 设置docker网络子网数量
change_docker_network(){
  # 检查 /etc/docker/daemon.json 文件中是否包含 "default-address-pools" 字符串
    if grep -q '"default-address-pools"' /etc/docker/daemon.json; then
        echo "发现 'default-address-pools'，退出方法。"
        return 0  # 或者你可以使用 exit 1 来终止整个脚本
    fi

    # 如果没有发现 "default-address-pools"，继续执行其他逻辑
    echo "未发现 'default-address-pools'，继续执行方法。"

    # 在这里添加其他的操作...
  sudo rm -rf /etc/docker/daemon.json
  cat >/etc/docker/daemon.json <<EOL
{
  "default-address-pools": [
    {
      "base": "172.80.0.0/16",
      "size": 24
    }
  ]
}
EOL
  sudo systemctl restart docker
}

# 主函数
main() {
  print_message "开始安装多实例 Allora Network Price Prediction Worker..."

  install_dependencies
  install_docker
  install_docker_compose

  change_docker_network

 #read -p "请输入要运行的实例开始数字: " num_start
  #read -p "请输入要运行的实例结束数字: " num_instances
  num_start=1
  num_instances=11

#   for ((i = 1; i <= num_instances; i++)); do
#     read -p "请输入实例 #${i} 的钱包助记词: " wallet_seed
#     setup_instance $i "$wallet_seed"
#   done

  for ((i = num_start; i <= num_instances; i++)); do
    # read -p "请输入实例 #${i} 的钱包助记词: " wallet_seed
    file_path="./input.txt"
    wallet_seed=$(sed -n "${i}p" "$file_path" | tr -d '\r\n')
    setup_instance $i "$wallet_seed"
  done

  print_message "所有实例安装完成！"
  print_warning "请检查 docker 容器状态："
  docker ps

  print_message "你可以使用以下命令检查各个节点的状态："
  for ((i = 1; i <= num_instances; i++)); do
    echo "实例 #${i}:"
    echo "检查 Worker 节点: curl http://localhost:$((8000 + i))/inference/ETH"
    echo ""
  done
}

# 运行主函数
main
