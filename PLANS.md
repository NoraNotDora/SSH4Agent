# plans

制作一个通用的让agent能够通过本地命令行进行远程操控的插件
支持同时管理多个工作区（在workspaces中，本地的文件夹和远程文件夹相映射）
需要有sh文件引导完成配置设置
agent可以通过简单的命令类似“remote1 cd ./”等同于在远程服务器上执行“cd ./”
remote代表的是第几个ssh配置

## implemented

- `tool/tool4remote`：Python CLI，支持多 remote、多 workspace、pull/push/run/status/tail/gpu/tmux。
- `tool/setup.sh`：初始化配置目录、本地 workspace 目录、并为 `remote1` 等 remote 生成短命令包装器。
- `tool/configs/ssh_config`：OpenSSH 配置，由工具通过 `ssh -F` 使用。
- `tool/configs/config.toml`：remote 与 workspace 映射。
- `workspaces/`：本地镜像根目录。
