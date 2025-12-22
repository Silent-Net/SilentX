# Quickstart: Privileged Helper Service

## 用户安装流程

### 1. 首次安装服务

1. 打开 SilentX 应用
2. 进入 **设置** → **代理模式**
3. 点击 **安装免密码服务**
4. 输入管理员密码（**仅此一次**）
5. 等待安装完成，显示"服务运行中"

### 2. 使用代理（免密码）

安装服务后，所有代理操作**永不再需要密码**：

- 点击"连接" → 立即启动代理
- 点击"断开" → 立即停止代理
- 切换配置 → 自动重启代理
- 重启电脑 → 服务自动恢复，代理可直接连接

### 3. 卸载服务（可选）

如需回退到密码模式：

1. 进入 **设置** → **代理模式**
2. 点击 **卸载服务**
3. 输入管理员密码
4. 服务已移除，回到每次需要密码的模式

---

## 开发者指南

### 构建服务二进制

```bash
cd /Users/xmx/workspace/Silent-Net/SilentX

# 构建主应用和服务
xcodebuild -scheme SilentX -configuration Release build
xcodebuild -scheme SilentX-Service -configuration Release build
```

### 手动安装测试

```bash
# 1. 复制服务到系统目录
sudo mkdir -p /Library/PrivilegedHelperTools
sudo cp DerivedData/Build/Products/Release/silentx-service /Library/PrivilegedHelperTools/
sudo chmod 544 /Library/PrivilegedHelperTools/silentx-service
sudo chown root:wheel /Library/PrivilegedHelperTools/silentx-service

# 2. 安装 launchd plist
sudo cp Resources/launchd.plist.template /Library/LaunchDaemons/com.silentnet.silentx.service.plist
sudo chmod 644 /Library/LaunchDaemons/com.silentnet.silentx.service.plist
sudo chown root:wheel /Library/LaunchDaemons/com.silentnet.silentx.service.plist

# 3. 加载服务
sudo launchctl bootstrap system /Library/LaunchDaemons/com.silentnet.silentx.service.plist
sudo launchctl enable system/com.silentnet.silentx.service
```

### 验证服务状态

```bash
# 检查服务是否运行
sudo launchctl list | grep silentx

# 查看服务日志
tail -f /tmp/silentx/service.log

# 检查 socket 是否存在
ls -la /tmp/silentx/silentx-service.sock
```

### 手动卸载

```bash
# 1. 停止并移除服务
sudo launchctl bootout system/com.silentnet.silentx.service

# 2. 删除文件
sudo rm /Library/LaunchDaemons/com.silentnet.silentx.service.plist
sudo rm /Library/PrivilegedHelperTools/silentx-service
sudo rm -rf /tmp/silentx
```

### IPC 测试命令

```bash
# 使用 socat 测试 IPC（需要安装 socat: brew install socat）

# 查询状态
echo '{"command":"status","payload":{}}' | socat - UNIX-CONNECT:/tmp/silentx/silentx-service.sock

# 查询版本
echo '{"command":"version","payload":{}}' | socat - UNIX-CONNECT:/tmp/silentx/silentx-service.sock

# 启动 sing-box
echo '{"command":"start","payload":{"configPath":"/path/to/config.json","corePath":"/path/to/sing-box"}}' | socat - UNIX-CONNECT:/tmp/silentx/silentx-service.sock

# 停止 sing-box
echo '{"command":"stop","payload":{}}' | socat - UNIX-CONNECT:/tmp/silentx/silentx-service.sock
```

---

## 故障排除

### 问题：服务安装失败

**症状**：安装时提示错误

**解决方案**：
1. 确保有管理员权限
2. 检查 `/Library/PrivilegedHelperTools/` 目录是否可写
3. 查看安装日志：`cat /tmp/silentx-install.log`

### 问题：服务不响应

**症状**：App 显示"服务不可用"

**解决方案**：
1. 检查服务进程：`ps aux | grep silentx-service`
2. 检查 socket：`ls -la /tmp/silentx/`
3. 查看日志：`tail -f /tmp/silentx/service.log`
4. 重启服务：`sudo launchctl kickstart -k system/com.silentnet.silentx.service`

### 问题：sing-box 启动失败

**症状**：点击连接后，显示启动失败

**解决方案**：
1. 查看服务日志：`tail -100 /tmp/silentx/service.log`
2. 确认配置文件有效：`/path/to/sing-box check -c /path/to/config.json`
3. 确认核心二进制可执行：`chmod +x /path/to/sing-box`

### 问题：显示“已连接”，但系统应用（如 YouTube）仍无法访问

**常见根因**：配置为 tun-only 且 `auto_route=false`。

- 在这种配置下，sing-box 可能成功创建 `utun*` 接口，但不会把系统默认路由指向 TUN。
- 若配置包含 `tun.platform.http_proxy.enabled=true`，这表示**客户端需要启用系统 HTTP/HTTPS 代理**（而不是 sing-box 自动完成）。

**解决方案（推荐）**：
1. 在 SilentX 中启用“自动设置系统代理”（由免密码服务执行，断开时自动恢复）。

**替代方案（高级用户）**：
- 修改配置，把 tun 的 `auto_route` 设为 `true`，并同时配置 `route.auto_detect_interface=true`（防止路由回环）。

**验证方法**：
- 若使用系统代理模式：系统网络设置中 HTTP/HTTPS 代理应指向 `127.0.0.1:<port>`（通常来自 config 的 `platform.http_proxy.server_port`）。
- 若使用 auto_route：默认路由应被 TUN 接管（可用 `route -n get default` 观察 interface 变化）。

### 问题：权限问题

**症状**：普通用户无法连接 socket

**解决方案**：
1. 检查 socket 权限：`ls -la /tmp/silentx/silentx-service.sock`
2. 应该是 `srwxrwxrwx` (0666)
3. 如果权限错误，重启服务会自动修复
