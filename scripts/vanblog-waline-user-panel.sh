#!/bin/bash

# CornWorld(https://github.com/CornWorld)

# ANSI 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无色
BOLD='\033[1m'

# 确定使用哪个容器命令
container_cmd=""
for cmd in docker nerdctl podman crictl; do
  if command -v "$cmd" &> /dev/null; then
    container_cmd="$cmd"
    echo -e "${BLUE}使用容器运行时: $cmd${NC}"
    break
  fi
done

if [ -z "$container_cmd" ]; then
  echo -e "${RED}错误: 未找到容器运行时命令 (docker, nerdctl, podman 等)${NC}"
  exit 1
fi

# 查找包含 "mongo" 标签的容器 ID
container_id=$($container_cmd ps | grep mongo | awk '{print $1}')

# 检查是否找到符合条件的容器
if [ -z "$container_id" ]; then
  echo -e "${RED}未找到运行中的 MongoDB 容器。${NC}"
  exit 1
fi

echo -e "${GREEN}找到 MongoDB 容器，ID: $container_id${NC}"

# 确定 MongoDB 客户端命令 (mongo 或 mongosh)
mongo_cmd=""
if $container_cmd exec "$container_id" mongosh --version &> /dev/null; then
  mongo_cmd="mongosh"
  echo -e "${BLUE}使用 MongoDB 客户端: mongosh (新版本)${NC}"
elif $container_cmd exec "$container_id" mongo --version &> /dev/null; then
  mongo_cmd="mongo"
  echo -e "${BLUE}使用 MongoDB 客户端: mongo (旧版本)${NC}"
else
  echo -e "${RED}错误: 容器中未找到 mongo 或 mongosh 命令。${NC}"
  exit 1
fi

# 执行MongoDB命令的函数 - 改进版本
execute_mongo_command() {
  local js_command="$1"
  local temp_js_file="temp_mongo_command_$(date +%s).js"
  local max_retries=3
  local retry_count=0
  local success=false

  echo "$js_command" > $temp_js_file

  # 添加重试机制
  while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
    if $container_cmd cp $temp_js_file "$container_id":/tmp/$temp_js_file &> /dev/null; then
      result=$($container_cmd exec "$container_id" $mongo_cmd waline /tmp/$temp_js_file 2>&1)
      status=$?
      success=true
    else
      retry_count=$((retry_count+1))
      echo -e "${YELLOW}与容器通信失败，尝试重试 ($retry_count/$max_retries)${NC}"
      sleep 1
    fi
  done

  # 清理临时文件
  rm -f $temp_js_file
  $container_cmd exec "$container_id" rm -f /tmp/$temp_js_file &> /dev/null

  if [ "$success" = false ]; then
    echo -e "${RED}与容器通信失败，请检查容器状态。${NC}"
    return 1
  fi

  echo "$result"
  return $status
}

# 检查操作结果的辅助函数
check_mongo_operation() {
  local result="$1"
  local operation="$2"

  # 移除MongoDB连接信息和shell版本信息
  local cleaned_result=$(echo "$result" | grep -v "MongoDB shell" | grep -v "connecting to:" | grep -v "Implicit session:" | grep -v "MongoDB server version:")

  case $operation in
    "delete")
      # 对于旧版本mongo shell，通过检查是否有报错来判断
      if [[ "$mongo_cmd" == "mongo" ]]; then
        if echo "$cleaned_result" | grep -q "Error"; then
          return 1
        else
          return 0
        fi
      else
        # 对于mongosh，检查deletedCount
        if echo "$cleaned_result" | grep -q '"deletedCount" : 1'; then
          return 0
        else
          return 1
        fi
      fi
      ;;
    "update")
      # 对于旧版本mongo shell，通过检查是否有报错来判断
      if [[ "$mongo_cmd" == "mongo" ]]; then
        if echo "$cleaned_result" | grep -q "Error"; then
          return 1
        else
          return 0
        fi
      else
        # 对于mongosh，检查是否成功
        if echo "$cleaned_result" | grep -q '"ok" : 1'; then
          return 0
        else
          return 1
        fi
      fi
      ;;
    "insert")
      # 对于旧版本mongo shell，通过检查是否有报错来判断
      if [[ "$mongo_cmd" == "mongo" ]]; then
        if echo "$cleaned_result" | grep -q "Error"; then
          return 1
        else
          return 0
        fi
      else
        # 对于mongosh，检查是否成功
        if echo "$cleaned_result" | grep -q '"acknowledged" : true'; then
          return 0
        else
          return 1
        fi
      fi
      ;;
  esac

  return 0
}

# 列出所有用户
list_users() {
  echo -e "${BLUE}正在获取用户列表...${NC}"

  # 根据mongo版本调整打印格式
  if [ "$mongo_cmd" == "mongosh" ]; then
    format_cmd='printjson(db.Users.find().toArray())'
  else
    format_cmd='db.Users.find().forEach(printjson)'
  fi

  result=$(execute_mongo_command "$format_cmd")

  if [ $? -ne 0 ]; then
    echo -e "${RED}获取用户列表失败。${NC}"
    return 1
  fi

  # 提取用户信息并格式化输出
  echo -e "${BOLD}当前 Waline 用户:${NC}"
  # 清理MongoDB输出中的连接信息
  user_data=$(echo "$result" | grep -v "MongoDB shell" | grep -v "connecting to:" | grep -v "Implicit session:" | grep -v "MongoDB server version:" | grep -v "bye")

  if [ -z "$user_data" ]; then
    echo -e "-----------------------------------"
    echo -e "${YELLOW}没有找到用户记录。${NC}"
    echo -e "-----------------------------------"
    return 0
  fi

  echo "$user_data" | grep -E '(_id|display_name|email|type)' | sed 's/^[[:space:]]*//' |
  awk 'BEGIN {count=0; print "-----------------------------------"}
       /_id/ {if (count>0) print "-----------------------------------"; count++; print "用户 #" count ":"; print $0}
       !(/_id/) {print $0}
       END {print "-----------------------------------"; print "用户总数: " count}'
}

# 删除管理员用户 - 改进版
delete_admin() {
  echo -e "${BLUE}正在获取管理员列表...${NC}"

  # 获取管理员列表
  if [ "$mongo_cmd" == "mongosh" ]; then
    format_cmd='printjson(db.Users.find({type: "administrator"}).toArray())'
  else
    format_cmd='db.Users.find({type: "administrator"}).forEach(printjson)'
  fi

  admins=$(execute_mongo_command "$format_cmd")

  if [ $? -ne 0 ]; then
    echo -e "${RED}获取管理员列表失败。${NC}"
    return 1
  fi

  # 清理MongoDB输出
  admins_data=$(echo "$admins" | grep -v "MongoDB shell" | grep -v "connecting to:" | grep -v "Implicit session:" | grep -v "MongoDB server version:" | grep -v "bye")

  # 检查是否有管理员账户
  admin_count=$(echo "$admins_data" | grep -c "_id")
  if [ "$admin_count" -eq 0 ]; then
    echo -e "${RED}未找到管理员账户。${NC}"
    return 1
  fi

  # 显示管理员列表并让用户选择
  echo -e "${YELLOW}管理员账户:${NC}"
  admin_ids=()
  admin_names=()

  # 提取管理员ID和名称
  while IFS= read -r line; do
    if [[ $line =~ \"_id\"[[:space:]]*:[[:space:]]*ObjectId\(\"([^\"]+)\"\) ]]; then
      current_id="${BASH_REMATCH[1]}"
      admin_ids+=("$current_id")
    elif [[ $line =~ \"display_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      current_name="${BASH_REMATCH[1]}"
      admin_names+=("$current_name")
    fi
  done < <(echo "$admins_data")

  # 显示管理员列表
  echo -e "${BOLD}选择要删除的管理员:${NC}"
  for i in "${!admin_ids[@]}"; do
    echo -e "$((i+1)). ${admin_names[$i]} (ID: ${admin_ids[$i]})"
  done
  echo -e "0. 取消操作"

  # 让用户选择
  read -p "请输入选择 [0-${#admin_ids[@]}]: " selection

  # 验证输入
  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 0 ] || [ "$selection" -gt "${#admin_ids[@]}" ]; then
    echo -e "${RED}无效的选择。操作已取消。${NC}"
    return 1
  fi

  # 取消操作
  if [ "$selection" -eq 0 ]; then
    echo -e "${YELLOW}操作已取消。${NC}"
    return 0
  fi

  # 执行删除操作
  selection=$((selection-1))
  selected_id="${admin_ids[$selection]}"
  selected_name="${admin_names[$selection]}"

  echo -e "${RED}即将删除管理员: $selected_name${NC}"
  read -p "确定要删除吗？此操作无法撤销 [y/N]: " confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    delete_cmd="db.Users.deleteOne({_id: ObjectId('$selected_id')});
                if (db.Users.findOne({_id: ObjectId('$selected_id')}) === null) {
                  print('DELETE_SUCCESS');
                } else {
                  print('DELETE_FAILED');
                }"
    result=$(execute_mongo_command "$delete_cmd")

    # 检查结果中是否包含我们添加的成功标记
    if echo "$result" | grep -q "DELETE_SUCCESS"; then
      echo -e "${GREEN}已成功删除管理员: $selected_name${NC}"
    else
      echo -e "${RED}删除管理员失败。${NC}"
      echo -e "${RED}请确认 MongoDB 权限是否正确。${NC}"
    fi
  else
    echo -e "${YELLOW}删除操作已取消。${NC}"
  fi
}

# 重置管理员密码 - 改进版
reset_admin_password() {
  # 使用已知的密码哈希值（对应 123123）
  default_password_hash='$2a$08$gW.CHW8prPnZMQynsqNM0uiC3wO6olz0EPzEZLCilu1qcyazwJvs2'
  default_email='admin@admin.com'

  echo -e "${BLUE}重置管理员密码和邮箱${NC}"
  echo -e "${YELLOW}这将重置所有管理员账户为:${NC}"
  echo -e "  邮箱: $default_email"
  echo -e "  密码: 123123 (使用预设的哈希值)"
  read -p "确定要继续吗? [y/N]: " confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    update_cmd="db.Users.updateMany(
      { type: 'administrator' },
      {
        \$set: {
          password: '$default_password_hash',
          email: '$default_email'
        }
      }
    );
    var result = db.runCommand('getLastError');
    if (result.ok === 1) {
      print('UPDATE_SUCCESS');
    } else {
      print('UPDATE_FAILED');
    }"

    result=$(execute_mongo_command "$update_cmd")

    # 检查结果中是否包含我们添加的成功标记
    if echo "$result" | grep -q "UPDATE_SUCCESS"; then
      echo -e "${GREEN}管理员密码重置成功。${NC}"
      echo -e "${GREEN}请使用邮箱: $default_email 和密码: 123123 登录 Waline${NC}"
    else
      echo -e "${RED}重置管理员密码失败。${NC}"
      echo -e "${RED}请确认 MongoDB 权限是否正确。${NC}"
    fi
  else
    echo -e "${YELLOW}密码重置已取消。${NC}"
  fi
}

# 创建新管理员账户
create_admin() {
  echo -e "${BLUE}创建新管理员账户${NC}"
  echo -e "${YELLOW}注意: 默认将使用密码 '123123'${NC}"

  read -p "输入显示名称: " display_name
  read -p "输入邮箱: " email

  # 验证必填字段
  if [ -z "$display_name" ] || [ -z "$email" ]; then
    echo -e "${RED}显示名称和邮箱为必填项。操作已取消。${NC}"
    return 1
  fi

  read -p "输入网站 URL (可选): " url

  # 使用默认密码哈希值
  password_hash='$2a$08$gW.CHW8prPnZMQynsqNM0uiC3wO6olz0EPzEZLCilu1qcyazwJvs2'
  echo -e "${YELLOW}使用默认密码: 123123${NC}"

  # 创建新用户
  create_cmd="db.Users.insertOne({
    display_name: '$display_name',
    email: '$email',
    password: '$password_hash',
    url: '$url',
    type: 'administrator'
  });

  var newUser = db.Users.findOne({email: '$email'});
  if (newUser) {
    print('INSERT_SUCCESS');
  } else {
    print('INSERT_FAILED');
  }"

  result=$(execute_mongo_command "$create_cmd")

  # 检查结果中是否包含我们添加的成功标记
  if echo "$result" | grep -q "INSERT_SUCCESS"; then
    echo -e "${GREEN}新管理员账户创建成功。${NC}"
    echo -e "${GREEN}请使用邮箱: $email 和密码: 123123 登录${NC}"
  else
    echo -e "${RED}创建管理员账户失败。${NC}"
    echo -e "${RED}请确认 MongoDB 权限是否正确，或该邮箱是否已被使用。${NC}"
  fi
}

# 主菜单
show_menu() {
  echo
  echo -e "${BOLD}Waline 用户管理${NC} | ${RED} Vanblog 专用${NC}"
  echo -e "by CornWorld(https://github.com/CornWorld)"
  echo -e "1. 列出所有用户"
  echo -e "2. 重置管理员密码 (为默认值: 123123)"
  echo -e "3. 删除管理员账户"
  echo -e "4. 创建新管理员账户"
  echo -e "0. 退出"
  echo
}

# 主循环
while true; do
  show_menu
  read -p "请输入您的选择 [0-4]: " choice

  case $choice in
    1) list_users ;;
    2) reset_admin_password ;;
    3) delete_admin ;;
    4) create_admin ;;
    0) echo -e "${GREEN}退出 Waline 用户管理。再见！${NC}"; exit 0 ;;
    *) echo -e "${RED}无效的选项。请重试。${NC}" ;;
  esac

  # 暂停让用户查看结果
  echo
  read -p "按回车键继续..."
done
