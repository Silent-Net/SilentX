# SilentX MVP - 可交付版本

**构建日期**: 2025-12-06  
**版本**: MVP 1.0  
**状态**: ✅ 可用

---

## 已实现的核心功能

### 1. ✅ Core版本管理（完全功能）

**功能**:
- 从GitHub API获取真实的sing-box版本列表
- **真实下载**: 完整实现tar.gz下载、解压、安装流程
- 下载进度实时显示
- 版本持久化存储（SwiftData）
- 切换视图数据不丢失

**使用方法**:
1. 打开 Settings → Core Versions
2. 点击刷新按钮获取最新版本
3. 点击版本下载（v1.12.12推荐）
4. 等待下载完成
5. 右键菜单 → Set as Active

**下载位置**: `~/Library/Application Support/Silent-Net.SilentX/cores/{version}/sing-box`

---

### 2. ✅ 连接功能（真实实现）

**功能**:
- 真实启动sing-box核心进程
- 配置文件验证和持久化
- 系统代理配置（HTTP/HTTPS）
- 连接状态实时监控
- 崩溃自动恢复

**使用前提**:
1. 必须先下载core版本（见上）
2. 必须导入有效配置文件

**使用方法**:
1. Dashboard → 选择Profile
2. 点击 Connect 按钮
3. 查看状态指示器（绿色=已连接）

**错误提示**: "Core error: Sing-Box core not found" → 需要先下载core

---

### 3. ⚠️ Profile管理（部分功能）

**已实现**:
- ✅ 从URL导入配置
- ✅ 从本地文件导入
- ✅ JSON验证
- ✅ SwiftData持久化
- ✅ 列表查看

**未实现**:
- ❌ 订阅自动更新（Post-MVP Phase 13）
- ❌ 配置编辑器语法高亮

**使用方法**:
1. Profiles → 点击 + 按钮
2. 选择"Import from URL"或"Import from File"
3. 粘贴URL或选择文件
4. 等待验证通过

---

### 4. ❌ Node管理（Mock）

**状态**: UI完整，逻辑为Mock数据  
**原因**: MVP优先级P2，Phase 5任务  
**替代方案**: 使用JSON编辑器直接修改配置

---

### 5. ❌ Rule管理（Mock）

**状态**: UI完整，逻辑为Mock数据  
**原因**: MVP优先级P2，Phase 6任务  
**替代方案**: 使用JSON编辑器直接修改配置

---

### 6. ✅ 日志查看器（完整功能）

**功能**:
- 实时日志流
- 按级别过滤（Error/Warning/Info/Debug）
- 按类别过滤
- 导出到文件

**使用方法**:
1. 点击左侧 Logs 导航
2. 使用顶部过滤器选择级别
3. 点击导出按钮保存日志

---

## 快速开始指南

### 第一次使用

```bash
# 1. 启动应用
open /Applications/SilentX.app

# 2. 下载core（必须）
Settings → Core Versions → 刷新 → 下载 v1.12.12

# 3. 导入配置（必须）
Profiles → + → Import from URL
粘贴你的订阅URL

# 4. 连接
Dashboard → 选择Profile → Connect
```

### 验证功能

```bash
# 检查core是否下载成功
ls ~/Library/Application\ Support/Silent-Net.SilentX/cores/

# 检查core进程是否运行
ps aux | grep sing-box

# 检查系统代理设置
networksetup -getwebproxy Wi-Fi
```

---

## 已知限制

### 技术限制
1. **沙箱限制**: 
   - ✅ 已配置网络权限
   - ⚠️ 文件访问受限（仅用户选择的文件）

2. **系统代理**:
   - ✅ HTTP/HTTPS代理配置
   - ❌ PAC文件支持（未实现）
   - ❌ SOCKS5可选（未实现）

3. **性能目标**:
   - ⚠️ 启动时间: ~3s（未强制验证）
   - ⚠️ 连接时间: ~5s（未强制验证）
   - ✅ 配置验证: <1s

### 功能限制

| 功能 | MVP状态 | Post-MVP计划 |
|------|---------|--------------|
| Core下载 | ✅ 完整 | Phase 7完成 |
| 连接/断开 | ✅ 真实 | Phase 3完成 |
| Profile导入 | ✅ 真实 | Phase 4完成 |
| 订阅更新 | ❌ 缺失 | Phase 13计划 |
| Node编辑 | ❌ Mock | Phase 5计划 |
| Rule编辑 | ❌ Mock | Phase 6计划 |
| Network Extension | ❌ 缺失 | Phase 15计划 |

---

## 文件结构

```
~/Library/Application Support/Silent-Net.SilentX/
├── cores/                    # Core二进制文件
│   ├── 1.9.0/
│   │   └── sing-box
│   └── 1.12.12/
│       └── sing-box
├── profiles/                 # 配置文件
│   └── {UUID}.json
├── logs/                     # 导出的日志
│   └── export-{date}.log
└── default.db               # SwiftData数据库
```

---

## 故障排查

### 问题: "Core error: Sing-Box core not found"

**原因**: 未下载core或下载失败

**解决**:
```bash
# 检查core目录
ls -la ~/Library/Application\ Support/Silent-Net.SilentX/cores/

# 手动下载（备用）
mkdir -p ~/Library/Application\ Support/Silent-Net.SilentX/cores/1.12.12
cd ~/Library/Application\ Support/Silent-Net.SilentX/cores/1.12.12
curl -L -o sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/download/v1.12.12/sing-box-1.12.12-darwin-arm64.tar.gz
tar -xzf sing-box.tar.gz --strip-components=1
chmod +x sing-box
```

### 问题: "Network error (HTTP 0)"

**原因**: GitHub API无法访问或网络问题

**解决**:
1. 检查网络连接
2. 使用VPN/代理访问
3. 等待GitHub API恢复

### 问题: 下载的版本消失了

**原因**: 已修复（SwiftData持久化）

**验证**:
```bash
# 查看数据库
sqlite3 ~/Library/Application\ Support/Silent-Net.SilentX/default.db
> SELECT * FROM CoreVersion;
```

---

## 下一步计划

### 立即可做
1. ✅ 真实下载已实现
2. ✅ 持久化已实现
3. ✅ 连接功能已实现

### 短期（1-2周）
1. Node管理真实化（Phase 5）
2. Rule管理真实化（Phase 6）
3. 订阅自动更新（Phase 13）

### 中期（1个月）
1. Network Extension集成（Phase 15）
2. 真实延迟测试（Phase 16）
3. 性能测试自动化（Phase 14）

---

## 交付清单

- [x] 可构建的Xcode项目
- [x] 真实的Core下载功能
- [x] 真实的连接功能
- [x] 持久化数据存储
- [x] 网络权限配置
- [x] 错误处理和提示
- [x] 基础UI导航
- [x] 日志查看器
- [ ] 完整的Node编辑（Phase 5）
- [ ] 完整的Rule编辑（Phase 6）
- [ ] Network Extension（Phase 15）

**MVP完成度**: 70% 核心功能可用

---

## 使用许可

Private project, all rights reserved.

**构建命令**:
```bash
cd /Users/xmx/workspace/Silent-Net/SilentX
xcodebuild build -scheme SilentX -destination 'platform=macOS'
```

**运行**:
```bash
open build/Debug/SilentX.app
# 或在Xcode中按 ⌘R
```
