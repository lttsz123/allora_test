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
  git clone https://github.com/allora-network/allora-offchain-node .

  # 复制配置文件
  cp ./config.example.json ./config.json
  # 修改配置文件
  sed -i "s/\"addressKeyName\": \".*\"/\"addressKeyName\": \"$instance_number\"/" ./config.json
  sed -i "s/\"addressRestoreMnemonic\": \".*\"/\"addressRestoreMnemonic\": \"$wallet_seed\"/" ./config.json
  sed -i "s|\"nodeRpc\": \".*\"|\"nodeRpc\": \"https://sentries-rpc.testnet-1.testnet.allora.network/\"|" ./config.json

  # 修改docker-compose配置
  sed -i "s/- \"8000:8000\"/- \"$((8000 + instance_number)):8000\"/" ./docker-compose.yaml
  sed -i "s/- \"2112:2112\"/- \"$((2100 + instance_number)):2112\"/" ./docker-compose.yaml
  sed -i "s/container_name: offchain_source/container_name: offchain_source_$instance_number/" ./docker-compose.yaml
  sed -i "s/container_name: offchain_node/container_name: offchain_node_$instance_number/" ./docker-compose.yaml
  
  # 给与初始化脚本运行权限
  chmod +x init.config
  # 执行初始化
  ./init.config

  # 运行节点
  docker-compose build
  docker-compose up -d

  # 返回到主目录
  cd /root
}

# 主函数
main() {
  print_message "开始安装多实例 Allora Network Price Prediction Worker..."

  install_dependencies
  install_docker
  install_docker_compose

  filename=nubit1.txt

  lines=()

 # 使用while循环和read命令读取文件的每一行，并将它们存储在数组中
  while IFS= read -r line
  do
     lines+=("$line")  # 将读取的行添加到数组中
  done < "$filename"

 # 再次打印数组中的每一行，并显示行号
  echo "Printing lines from the file with line numbers:"
  for ((i=0; i<${#lines[@]}; i++)); do
     setup_instance $((i+1+50)) "${lines[$i]}"
     num_instances=$((num_instances + 1))
  done
 
  for ((i=0; i<${#lines[@]}; i++)); do
     run_instance $((i+1+50))
  done

  print_message "所有实例安装完成！"
  print_warning "请检查 docker 容器状态："
  docker ps

  print_message "你可以使用以下命令检查各个节点的状态："
  for ((i = 1; i <= num_instances+50; i++)); do
    port_offset=$((i * 10))
    echo "实例 #${i}:"
    echo "检查节点: curl http://localhost:$((8000 + i))/inference/ETH"
    echo ""
  done
}

# 运行主函数
main
