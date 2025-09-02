# Docker 使用说明
<!-- TOC depthFrom:2 -->

- [1. 前期工作](#1-前期工作)
- [2. 方式一：一键脚本(推荐)](#2-方式一一键脚本推荐)
- [3. 方式二：手动 Docker Compose](#3-方式二手动-docker-compose)
    - [3.1. 启动](#31-启动)
    - [3.2. 其他命令参考](#32-其他命令参考)
- [4. 方式三：手动Docker指令](#4-方式三手动docker指令)
    - [4.1. Docker启动](#41-docker启动)
    - [4.2. 其他指令参考](#42-其他指令参考)
    - [4.3. 使用Watchtower更新容器](#43-使用watchtower更新容器)
- [5. 登录](#5-登录)
- [6. 添加 Bili 账号](#6-添加-bili-账号)
- [7. 自己构建镜像（非必须）](#7-自己构建镜像非必须)
- [8. 其他](#8-其他)

<!-- /TOC -->

## 1. 前期工作

```
apt-get update
apt-get install curl
```

## 2. 方式一：一键脚本(推荐)

```
bash <(curl -sSL https://raw.githubusercontent.com/RayWangQvQ/BiliBiliToolPro/main/docker/install.sh)
```

## 3. 方式二：手动 Docker Compose

### 3.1. 启动

```
# 创建目录
mkdir bili_tool_web && cd bili_tool_web

# 下载
wget https://raw.githubusercontent.com/RayWangQvQ/BiliBiliToolPro/main/docker/sample/docker-compose.yml
mkdir -p config
cd ./config
wget https://raw.githubusercontent.com/RayWangQvQ/BiliBiliToolPro/main/docker/sample/config/cookies.json
cd ..

# 启动
docker compose up -d

# 查看启动日志
docker logs -f bili_tool_web
```

最终文件结构如下：

```
bili_tool_web
├── Logs
├── config
├──── cookies.json
└── docker-compose.yml
```

### 3.2. 其他命令参考

```
# 启动 docker-compose
docker compose up -d

# 停止 docker-compose
docker compose stop

# 查看实时日志
docker logs -f bili_tool_web

# 进入容器
docker exec -it bili_tool_web /bin/bash

# 手动更新容器
docker compose pull && docker compose up -d
```

## 4. 方式三：手动Docker指令

### 4.1. Docker启动

```
# 创建目录
mkdir bili_tool_web && cd bili_tool_web

# 生成并运行容器
docker pull ghcr.io/raywangqvq/bili_tool_web
docker run -d --name="bili_tool_web" \
    -p 22330:8080 \
    -e TZ=Asia/Shanghai \
    -v ./Logs:/app/Logs \
    -v ./config:/app/config \
    ghcr.io/raywangqvq/bili_tool_web

# 查看实时日志
docker logs -f bili_tool_web
```

其中，`cookie`需要替换为自己真实的cookie字符串

### 4.2. 其他指令参考

```
# 启动容器
docker start bili_tool_web

# 停止容器
docker stop bili_tool_web

# 重启容器
docker restart bili_tool_web

# 删除容器
docker rm bili_tool_web

# 进入容器
docker exec -it bili_tool_web /bin/bash
```

### 4.3. 使用Watchtower更新容器
```
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower \
    --run-once --cleanup \
    bili_tool_web
```

## 5. 登录

- 默认用户：`admin`
- 默认密码：`BiliTool@2233`

首次登陆后，请到`Admin`页面修改密码。

## 6. 添加 Bili 账号

扫码进行账号添加。

![trigger](../docs/imgs/web-trigger-login.png)

![login](../docs/imgs/docker-login.png)

## 7. 自己构建镜像（非必须）

目前我提供和维护的镜像：

- DockerHub: `[zai7lou/bili_tool_web](https://hub.docker.com/repository/docker/zai7lou/bili_tool_web)`
- GitHub: `[bili_tool_web](https://github.com/RayWangQvQ/BiliBiliToolPro/pkgs/container/bili_tool_web)`

如果有需要（大部分都不需要），可以使用源码自己构建镜像，如下：

### 7.1. 推荐方式：使用构建脚本

我们提供了功能强大的构建脚本，支持多种构建选项：

```bash
# 基础构建
./docker/build.sh

# 自定义镜像名称和标签
./docker/build.sh -n my-bili-tool -t v1.0.0

# 多架构构建（支持 AMD64 和 ARM64）
./docker/build.sh --multi-arch

# 构建并推送到镜像仓库
./docker/build.sh -r ghcr.io/yourusername --push

# 查看所有选项
./docker/build.sh --help
```

### 7.2. 传统方式：手动构建

在有项目的Dockerfile的目录运行：

```bash
docker build -t TARGET_NAME .
```

`TARGET_NAME`为镜像名称和版本，可以自己起个名字

### 7.3. 多架构构建

使用 buildx 进行多架构构建：

```bash
# AMD64 架构
docker buildx build --platform linux/amd64 -t TARGET_NAME .

# ARM64 架构（适用于 Apple Silicon Mac、ARM 服务器）
docker buildx build --platform linux/arm64 -t TARGET_NAME .

# 多架构同时构建
docker buildx build --platform linux/amd64,linux/arm64 -t TARGET_NAME .
```

### 7.4. 故障排除

如果构建过程中遇到网络问题（如 NuGet 连接失败），请：

1. 检查网络连接到 `api.nuget.org`
2. 使用重试机制：`./docker/build.sh --retry 5`
3. 如果在企业网络环境中，可能需要配置代理设置
4. 参考详细的构建指南：[docker/BUILD.md](docker/BUILD.md)

### 7.5. 构建环境测试

运行以下命令测试构建环境是否正常：

```bash
./docker/test-build-env.sh
```

## 8. 其他

代码编译和发布环境: mcr.microsoft.com/dotnet/sdk:8.0

代码运行环境: mcr.microsoft.com/dotnet/aspnet:8.0

如果下载`github`资源有问题，可以尝试添加加速器。
