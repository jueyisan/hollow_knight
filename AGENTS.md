# AGENTS.md

## 语言规则
- 默认始终使用简体中文进行**思考（reasoning）**与所有最终回答。
- 计划、工具调用、总结、代码注释同样使用简体中文。
- 仅代码、命令、文件路径、变量名、API 名称等必须原样保留的内容使用英文。

## 项目

- Godot 4.6.3（Forward Plus，Windows 上使用 D3D12）2D 类空洞骑士横版平台游戏。主场景：`scene/main_scene.tscn`（根节点 `MainScene`）。
- 唯一的游戏逻辑脚本是 `scene/player.tscn` 上的 `scene/player.gd`。`scene/boss.tscn` 有动画但尚无脚本。
- 资源位于 `assets/`。资源文件名、动画、输入名称和注释均为中文；请保持该约定。

## 运行与验证

- 引擎二进制文件：`& "D:/hcs/godot/Godot_v4.6.3-stable_win64.exe" --path .`（添加 `--editor` 打开编辑器）。
- 不存在测试、lint 或构建配置。通过运行主场景并检查编辑器/输出日志来验证。
- 单脚本解析检查：`& "D:/hcs/godot/Godot_v4.6.3-stable_win64.exe" --headless --path . --check-only --script res://scene/player.gd`
- `godot_mcp` 编辑器插件已启用（HTTP，默认端口 9080），并添加了 `MCPRuntimeProbe` 自动加载节点。优先使用其工具进行场景树编辑、节点属性、日志和运行项目；避免直接编辑 `.tscn` 文本。
- 设计分辨率为 320x180，以 1280x720 显示，使用 `canvas_items` 拉伸模式。布局请使用 320x180 坐标。

## 编辑规则

- 绝不重命名或移动 `assets/` 下的文件或现有场景/脚本文件。`.tscn` 和 `.import` 文件通过 `uid://` 加原始中文路径绑定资源；重命名会破坏导入。请使用 Godot/MCP 文件操作加重新导入。
- 保持 `.uid` 文件已提交；Godot 4.4+ 依赖它们来标识脚本/资源。
- `.tscn` 文件包含压缩的动画子资源和 UID 引用。尽可能通过 godot-mcp 工具或编辑器编辑它们。
- 玩家是手写状态机：`enum State` 位于 `scene/player.gd:48`，通过 `scene/player.gd:119` 的 `change_state()` 进行转换，动画通过中文字符串名称引用。添加状态时，需添加 `_physics_process` 分支并调用攻击判定框清理路径；离开攻击状态时判定框会自动禁用。

## 已知问题

- 输入动作：`A`/`D` 移动，`W`/`S` 上/下，`K` 跳跃，`L` 冲刺，`J` 攻击。
- 碰撞位：`1` = 地面，`2` = 玩家，`4` = 敌人（Boss）。玩家 HurtBox 使用层 2，掩码 4。