# CC Bell — 工作守则

## 核心规则：双目录同步

每次修改代码或配置文件后，必须同步到两个位置：

| 位置 | 用途 |
|------|------|
| `~/coding/cc-bell/` | 开源项目根目录，代码的 canonical 源 |
| `~/.claude/` | 用户本地运行环境，daemon 实际执行处 |

**每次修改后必须执行：**
1. 写入/编辑 `~/coding/cc-bell/` 下的源文件
2. 将编译产物复制到 `~/.claude/cc-bell`
3. 重启 daemon（kill + launchctl reload）
4. 如果修改了 plist，同步到 `~/Library/LaunchAgents/`

## 构建

```bash
make build        # 编译到 .build/cc-bell
make install      # 安装到 /usr/local/bin + LaunchAgent
```

## 项目结构

```
cc-bell/
├── cc-bell.swift           # 主程序
├── Makefile                # 构建/安装/卸载
├── com.cc-bell.plist       # LaunchAgent
├── scripts/
│   ├── lib.sh              # 共享函数（IDE 检测、图标）
│   ├── setup.sh            # Claude Code 集成一键安装
│   ├── claude-hook.sh      # Claude Code hook
│   ├── codex-hook.sh       # Codex CLI hook
│   └── notify.sh           # CLI 通知脚本
├── README.md               # 文档
├── LICENSE                 # MIT
└── CLAUDE.md               # 本文件
```

## 架构

- **notify 模式**: 接收参数，写入 notify-pending.json，启动/唤醒 daemon
- **daemon 模式**: 用 `FSEvents` 风格监听文件变化，弹 NSPanel 显示通知
- **数据存储**: `~/.claude/notify-*`（由 NOTIFY_TOOL_HOME 覆盖）
- **菜单栏**: NSStatusItem + NSMenu（DND / 声音 / 静音 / 退出）
