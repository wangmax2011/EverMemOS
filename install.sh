#!/bin/bash

# =============================================================================
# EverMemOS 一键安装启动脚本
# One-Stop Installation Script for EverMemOS
# =============================================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="EverMemOS"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${CYAN}▶ $1${NC}"; }

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1 || \
       netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

# 获取本机 IP
get_host_ip() {
    if command -v ip >/dev/null 2>&1; then
        ip route get 1 | awk '{print $7; exit}'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}'
    else
        echo "localhost"
    fi
}

# =============================================================================
# 步骤 1: 检查系统环境
# =============================================================================
check_system() {
    log_step "步骤 1/7: 检查系统环境"

    # 检查操作系统
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="Linux"
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
    log_info "操作系统: $OS"

    # 检查架构
    ARCH=$(uname -m)
    log_info "系统架构: $ARCH"

    # 检查内存
    if [[ "$OS" == "macOS" ]]; then
        MEM_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    else
        MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
    fi
    log_info "系统内存: ${MEM_GB}GB"

    if [[ $MEM_GB -lt 4 ]]; then
        log_warn "内存不足 4GB，建议至少 8GB 以获得最佳性能"
    fi
}

# =============================================================================
# 步骤 2: 检查并安装依赖
# =============================================================================
install_dependencies() {
    log_step "步骤 2/7: 检查并安装依赖"

    local missing_deps=()

    # 检查 Docker
    if ! command_exists docker; then
        missing_deps+=("docker")
    else
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        log_success "Docker 已安装: $DOCKER_VERSION"
    fi

    # 检查 Docker Compose
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        missing_deps+=("docker-compose")
    else
        if docker compose version >/dev/null 2>&1; then
            log_success "Docker Compose (plugin) 已安装"
        else
            DOCKER_COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
            log_success "Docker Compose 已安装: $DOCKER_COMPOSE_VERSION"
        fi
    fi

    # 检查 Python
    if ! command_exists python3 && ! command_exists python; then
        missing_deps+=("python")
    else
        PYTHON_CMD=$(command_exists python3 && echo "python3" || echo "python")
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
        log_success "Python 已安装: $PYTHON_VERSION"
    fi

    # 检查 uv
    if ! command_exists uv; then
        missing_deps+=("uv")
    else
        UV_VERSION=$(uv --version)
        log_success "uv 已安装: $UV_VERSION"
    fi

    # 安装缺失的依赖
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "缺失依赖: ${missing_deps[*]}"

        if [[ "$OS" == "macOS" ]]; then
            log_info "尝试使用 Homebrew 安装依赖..."
            if ! command_exists brew; then
                log_error "未安装 Homebrew，请先安装: https://brew.sh"
                exit 1
            fi

            for dep in "${missing_deps[@]}"; do
                case $dep in
                    docker)
                        log_info "安装 Docker Desktop..."
                        brew install --cask docker
                        log_warn "请启动 Docker Desktop 后继续"
                        read -p "按回车键继续..."
                        ;;
                    uv)
                        log_info "安装 uv..."
                        curl -LsSf https://astral.sh/uv/install.sh | sh
                        export PATH="$HOME/.cargo/bin:$PATH"
                        ;;
                esac
            done
        else
            log_error "请手动安装以下依赖: ${missing_deps[*]}"
            log_info "安装指南:"
            log_info "  - Docker: https://docs.docker.com/get-docker/"
            log_info "  - uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
            exit 1
        fi
    else
        log_success "所有依赖已安装"
    fi
}

# =============================================================================
# 步骤 3: 配置环境变量
# =============================================================================
setup_environment() {
    log_step "步骤 3/7: 配置环境变量"

    cd "$SCRIPT_DIR"

    # 如果 .env 文件不存在，从模板创建
    if [[ ! -f ".env" ]]; then
        log_info "创建 .env 配置文件..."

        # 读取用户输入
        echo ""
        echo "==============================================="
        echo "请配置以下参数（直接回车使用默认值）:"
        echo "==============================================="

        # 向量模型 API Key
        echo ""
        echo "1. 向量模型 API Key (推荐阿里云百炼):"
        echo "   - 获取地址: https://bailian.console.aliyun.com/"
        echo "   - 免费额度: 100万 Token (90天)"
        read -p "   请输入 API Key: " VECTORIZE_API_KEY

        if [[ -z "$VECTORIZE_API_KEY" ]]; then
            log_warn "未提供 API Key，向量检索功能将不可用"
            VECTORIZE_API_KEY="your-api-key-here"
        fi

        # 创建 .env 文件
        cat > .env << EOF
# =============================================================================
# EverMemOS 环境配置文件
# 生成时间: $(date)
# =============================================================================

# ===================
# LLM Configuration (用于记忆边界检测和提取)
# ===================
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini
LLM_API_KEY=dummy-key-for-local-testing

# ===================
# Vectorize (Embedding) Configuration - 向量模型配置
# 使用阿里云百炼 (推荐，OpenAI 兼容)
# 获取 API Key: https://bailian.console.aliyun.com/
# ===================
VECTORIZE_PROVIDER=vllm
VECTORIZE_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
VECTORIZE_API_KEY=${VECTORIZE_API_KEY}
VECTORIZE_MODEL=text-embedding-v4
VECTORIZE_DIMENSIONS=1024

# Fallback 配置
VECTORIZE_FALLBACK_PROVIDER=none

# ===================
# Rerank Configuration - 重排序模型 (可选)
# ===================
RERANK_PROVIDER=none

# ===================
# Redis Configuration
# ===================
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=8
REDIS_SSL=false

# ===================
# MongoDB Configuration
# ===================
MONGODB_HOST=localhost
MONGODB_PORT=27017
MONGODB_USERNAME=admin
MONGODB_PASSWORD=memsys123
MONGODB_DATABASE=memsys
MONGODB_URI_PARAMS=socketTimeoutMS=15000&authSource=admin

# ===================
# Elasticsearch Configuration
# ===================
ES_HOSTS=http://localhost:19200
ES_USERNAME=
ES_PASSWORD=
ES_VERIFY_CERTS=false
SELF_ES_INDEX_NS=memsys

# ===================
# Milvus Configuration
# ===================
MILVUS_HOST=localhost
MILVUS_PORT=19530
SELF_MILVUS_COLLECTION_NS=memsys

# ===================
# API Server Configuration
# ===================
API_BASE_URL=http://localhost:1995

# ===================
# Environment & Logging
# ===================
LOG_LEVEL=INFO
ENV=dev
MEMORY_LANGUAGE=zh
EOF

        log_success ".env 文件已创建"
    else
        log_info ".env 文件已存在，跳过配置"
    fi
}

# =============================================================================
# 步骤 4: 启动 Docker 容器
# =============================================================================
start_docker_containers() {
    log_step "步骤 4/7: 启动 Docker 容器"

    cd "$SCRIPT_DIR"

    # 检查端口占用
    local ports=(27017 19200 19300 19530 9091 6379)
    local port_conflicts=()

    for port in "${ports[@]}"; do
        if check_port "$port"; then
            port_conflicts+=("$port")
        fi
    done

    if [[ ${#port_conflicts[@]} -gt 0 ]]; then
        log_warn "以下端口已被占用: ${port_conflicts[*]}"
        log_info "尝试停止现有容器..."
        docker-compose stop 2>/dev/null || docker compose stop 2>/dev/null || true
        sleep 2
    fi

    # 启动容器
    log_info "正在启动 Docker 容器..."
    if docker compose up -d 2>&1 | tee /tmp/docker-compose.log; then
        log_success "Docker 容器启动成功"
    else
        log_error "Docker 容器启动失败"
        cat /tmp/docker-compose.log
        exit 1
    fi

    # 等待容器就绪
    log_info "等待容器就绪..."
    local max_wait=120
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        # 检查关键容器状态
        local healthy_count=$(docker ps --format "{{.Names}}:{{.Status}}" | grep -c "healthy" || true)
        local total_count=$(docker ps --format "{{.Names}}" | grep -c "memsys" || true)

        if [[ $healthy_count -ge 4 ]]; then
            log_success "所有容器已就绪 (healthy: $healthy_count/$total_count)"
            break
        fi

        echo -n "."
        sleep 5
        waited=$((waited + 5))
    done

    if [[ $waited -ge $max_wait ]]; then
        log_warn "容器启动超时，但可能仍在初始化中"
    fi

    # 显示容器状态
    echo ""
    log_info "容器状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep memsys || true
}

# =============================================================================
# 步骤 5: 安装 Python 依赖
# =============================================================================
install_python_deps() {
    log_step "步骤 5/7: 安装 Python 依赖"

    cd "$SCRIPT_DIR"

    if [[ ! -f "pyproject.toml" ]]; then
        log_error "未找到 pyproject.toml，请确保在正确的目录中"
        exit 1
    fi

    log_info "正在安装 Python 依赖 (使用 uv)..."
    if uv sync 2>&1 | tee /tmp/uv-sync.log; then
        log_success "Python 依赖安装完成"
    else
        log_error "Python 依赖安装失败"
        cat /tmp/uv-sync.log
        exit 1
    fi
}

# =============================================================================
# 步骤 6: 启动 EverMemOS 服务
# =============================================================================
start_service() {
    log_step "步骤 6/7: 启动 EverMemOS 服务"

    cd "$SCRIPT_DIR"

    # 检查端口 1995 是否被占用
    if check_port 1995; then
        log_warn "端口 1995 已被占用，尝试停止现有服务..."
        pkill -f "python src/run.py" 2>/dev/null || true
        sleep 2
    fi

    # 检查 9090 端口 (Prometheus)
    if check_port 9090; then
        log_warn "端口 9090 已被占用，这可能是之前的服务实例"
    fi

    # 启动服务
    log_info "正在启动 EverMemOS 服务..."
    log_info "日志将输出到: /tmp/evermemos.log"

    nohup uv run python src/run.py > /tmp/evermemos.log 2>&1 &
    local pid=$!

    # 等待服务启动
    local max_wait=60
    local waited=0

    log_info "等待服务启动..."
    while [[ $waited -lt $max_wait ]]; do
        if curl -s http://localhost:1995/health >/dev/null 2>&1; then
            log_success "EverMemOS 服务启动成功 (PID: $pid)"
            return 0
        fi

        # 检查进程是否还在
        if ! kill -0 $pid 2>/dev/null; then
            log_error "服务进程已退出"
            tail -50 /tmp/evermemos.log
            exit 1
        fi

        echo -n "."
        sleep 2
        waited=$((waited + 2))
    done

    log_warn "服务启动超时，请手动检查日志: tail -f /tmp/evermemos.log"
    return 1
}

# =============================================================================
# 步骤 7: 验证安装
# =============================================================================
verify_installation() {
    log_step "步骤 7/7: 验证安装"

    echo ""
    echo "==============================================="

    # 检查健康状态
    if curl -s http://localhost:1995/health >/dev/null 2>&1; then
        log_success "EverMemOS API 健康检查通过"
    else
        log_error "EverMemOS API 健康检查失败"
        return 1
    fi

    # 检查 Docker 容器
    local running_count=$(docker ps --format "{{.Names}}" | grep -c "memsys" || echo "0")
    if [[ $running_count -ge 6 ]]; then
        log_success "Docker 容器运行正常 ($running_count 个容器)"
    else
        log_warn "Docker 容器数量不足 (当前 $running_count 个)"
    fi

    # 测试 API
    log_info "测试 API..."
    local test_result=$(curl -s -X POST http://localhost:1995/api/v1/memories \
        -H "Content-Type: application/json" \
        -d '{
            "message_id": "test-install-001",
            "create_time": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
            "sender": "test-user",
            "sender_name": "Test User",
            "role": "user",
            "content": "这是一句测试消息，用于验证 EverMemOS 安装",
            "group_id": "test-group",
            "group_name": "Test Group"
        }' 2>/dev/null)

    if echo "$test_result" | grep -q "status\|ok\|queued"; then
        log_success "API 测试通过"
    else
        log_warn "API 测试未通过，但服务可能仍在初始化"
    fi

    echo ""
    echo "==============================================="
    log_success "安装完成！"
    echo "==============================================="
}

# =============================================================================
# 显示使用信息
# =============================================================================
show_usage() {
    local host_ip=$(get_host_ip)

    cat << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║                     EverMemOS 安装成功！                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

📍 访问地址:
   - API 服务: http://localhost:1995
   - 健康检查: http://localhost:1995/health

📋 常用命令:
   # 查看服务日志
   tail -f /tmp/evermemos.log

   # 停止服务
   pkill -f "python src/run.py"
   docker-compose stop

   # 重启服务
   pkill -f "python src/run.py"
   uv run python src/run.py

   # 查看 Docker 容器状态
   docker ps --format "table {{.Names}}\\t{{.Status}}"

🔧 下一步:
   1. 安装 Claude Code 插件:
      cd /path/to/evermem-claude-code
      claude --plugin-dir .

   2. 在 Claude Code 中使用:
      /evermem:help      # 查看帮助
      /evermem:hub       # 打开记忆仪表板

💡 提示:
   - 首次启动后，建议等待 1-2 分钟让服务完全初始化
   - 如果遇到问题，请查看日志: tail -f /tmp/evermemos.log
   - 详细文档请查看: README.md

EOF
}

# =============================================================================
# 主函数
# =============================================================================
main() {
    # 显示欢迎信息
    cat << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   ███████╗██╗   ██╗███████╗██████╗ ███╗   ███╗███████╗███╗   ███╗ ██████╗   ║
║   ██╔════╝██║   ██║██╔════╝██╔══██╗████╗ ████║██╔════╝████╗ ████║██╔═══██╗  ║
║   █████╗  ██║   ██║█████╗  ██████╔╝██╔████╔██║█████╗  ██╔████╔██║██║   ██║  ║
║   ██╔══╝  ╚██╗ ██╔╝██╔══╝  ██╔══██╗██║╚██╔╝██║██╔══╝  ██║╚██╔╝██║██║   ██║  ║
║   ███████╗ ╚████╔╝ ███████╗██║  ██║██║ ╚═╝ ██║███████╗██║ ╚═╝ ██║╚██████╔╝  ║
║   ╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝     ╚═╝ ╚═════╝   ║
║                                                                              ║
║                         记忆系统 · 一键安装脚本                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF

    log_info "开始安装 EverMemOS..."
    log_info "项目目录: $SCRIPT_DIR"
    echo ""

    # 执行安装步骤
    check_system
    install_dependencies
    setup_environment
    start_docker_containers
    install_python_deps
    start_service
    verify_installation

    # 显示使用信息
    show_usage
}

# 处理命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            cat << EOF
EverMemOS 一键安装脚本

用法: $0 [选项]

选项:
    --help, -h      显示帮助信息
    --stop          停止 EverMemOS 服务
    --restart       重启 EverMemOS 服务
    --status        查看服务状态

示例:
    $0              # 完整安装并启动
    $0 --stop       # 停止服务
    $0 --restart    # 重启服务

EOF
            exit 0
            ;;
        --stop)
            log_info "停止 EverMemOS 服务..."
            pkill -f "python src/run.py" 2>/dev/null || true
            cd "$SCRIPT_DIR" && docker-compose stop 2>/dev/null || docker compose stop 2>/dev/null || true
            log_success "服务已停止"
            exit 0
            ;;
        --restart)
            log_info "重启 EverMemOS 服务..."
            pkill -f "python src/run.py" 2>/dev/null || true
            sleep 2
            main
            exit 0
            ;;
        --status)
            echo "服务状态:"
            echo ""
            echo "Docker 容器:"
            docker ps --format "table {{.Names}}\t{{.Status}}" | grep memsys || echo "  无运行中的容器"
            echo ""
            echo "Python 服务:"
            ps aux | grep "python src/run.py" | grep -v grep || echo "  服务未运行"
            echo ""
            echo "端口状态:"
            for port in 1995 27017 19200 19530 6379; do
                if check_port $port; then
                    echo "  端口 $port: 已占用"
                else
                    echo "  端口 $port: 空闲"
                fi
            done
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            log_info "使用 --help 查看帮助"
            exit 1
            ;;
    esac
    shift
done

# 运行主函数
main
