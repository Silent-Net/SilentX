# ✅ 开发流程 (Development Workflow)

## 新的高效流程 (New Efficient Pipeline) 🚀

### 核心理念：Xcode 原生开发流程
**AI 修改代码 → 你在 Xcode 点运行 ▶️ → Xcode 自动编译测试**

这是标准的 macOS/iOS 开发方式，比命令行更快更直观！

## 日常开发流程 (Daily Development)

### 1. AI 修改代码
```
你：描述需要的功能或修复
AI：修改 Swift 文件
```

### 2. 你在 Xcode 中验证
```
1. 在 Xcode 中打开项目
2. 点击 ▶️ 运行按钮 (⌘R)
3. Xcode 自动：
   - 编译代码
   - 检查错误
   - 运行测试
   - 启动应用
```

### 3. 实时测试
```
- 应用在模拟器/真机运行
- 实时查看修改效果
- Console 查看日志
- 调试器可随时暂停
```

## Xcode 快捷键 (Essential Shortcuts)

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| **运行** | ⌘R | 编译并运行 |
| **停止** | ⌘. | 停止运行 |
| **清理** | ⇧⌘K | 清理构建文件夹 |
| **测试** | ⌘U | 运行所有测试 |
| **构建** | ⌘B | 仅编译不运行 |

## 为什么不使用 Make？

SilentX 是原生 macOS 应用，Xcode 提供了更好的开发体验：
- ✅ 实时错误提示和代码补全
- ✅ 集成调试器和性能分析
- ✅ 无需外部工具依赖（无需 xcpretty 等）
- ✅ 更快的增量编译

**不需要 Makefile**，Xcode 原生工作流已足够。

### 2. 开发环境配置
✓ **网络权限 (Network Entitlements)** - 2025-12-06 修复
  - 创建 `SilentX/SilentX.entitlements`
  - 禁用 App Sandbox（代理应用需要）
  - 自动配置到 Xcode 项目
  - ✅ GitHub API 现在可以正常访问

✓ **Xcode 项目配置**
  - CODE_SIGN_ENTITLEMENTS 已设置
  - 支持直接在 Xcode 中运行
  - DerivedData 自动管理

### 3. CI/CD 管道
✓ **GitHub Actions** - 持续集成
  - 自动构建和测试
  - 性能阈值检查
  - 测试结果报告

## 典型开发场景 (Common Scenarios)

### 场景 1: 修复 Bug
```
1. AI 修改代码修复问题
2. 你在 Xcode 点 ▶️
3. 应用启动，测试修复效果
4. 如果还有问题，告诉 AI 继续修
5. 满意后提交代码
```

### 场景 2: 添加新功能
```
1. 描述功能需求给 AI
2. AI 创建/修改必要的文件
3. Xcode 点 ▶️ 查看效果
4. 实时调整细节
5. 功能完成
```

### 场景 3: 调试问题
```
1. 在 Xcode 中设置断点
2. 点 ▶️ 运行到断点
3. 检查变量和调用栈
4. 告诉 AI 发现的问题
5. AI 修复，再次测试
```

## 当前项目状态 (Current Status)

### 实现进度 (Implementation Progress)
- ✅ Phase 1-3: 完成 (Setup, Foundation, US1 Connect)
- ✅ Phase 4: 完成 (US2 Import Profiles with Auto-update)
- 🔄 Phase 5-10: 进行中 (60 tasks remaining)
- **总进度**: 148/208 tasks (71%)

### 性能要求 (Performance Requirements)
| 指标 | 阈值 | 状态 |
|------|------|------|
| 应用启动 | <3秒 | ⏳ 待测试 |
| 连接建立 | <5秒 | ⏳ 待测试 |
| 配置验证 | <1秒 | ⏳ 待测试 |
| 核心切换 | <10秒 | ⏳ 待测试 |

### 最近修复 (Recent Fixes)
- ✅ **网络访问问题** (2025-12-06)
  - 问题: "Network error (HTTP 0)"
  - 原因: App Sandbox 阻止网络连接
  - 解决: 创建 entitlements 文件，禁用 sandbox
  - 结果: 可以正常获取 v1.12.12 等最新版本

- ✅ **Profile 模型扩展** (2025-12-06)
  - 添加 `lastSyncAt` 字段
  - 创建 Release/ReleaseAsset 域模型
  - 实现订阅更新重试/退避逻辑

## 下一步开发 (Next Development)

**Phase 5: Node Latency (US3)** - 5 tasks
- T026-T030: 节点延迟测试和实现

**Phase 6: Rule Validation (US4)** - 5 tasks  
- T031-T035: 路由规则验证

**Phase 7: Core Hash Verification (US5)** - 5 tasks
- T036-T040: 核心版本校验

**优先级 (Priority)**:
1. 修复发现的 bug（如网络问题）
2. 完成当前 Phase 功能
3. 测试性能指标
4. 优化用户体验

## 开发最佳实践 (Best Practices)

### 与 AI 协作
```
✅ DO:
- 描述具体问题："点击按钮后应用崩溃"
- 提供错误信息：粘贴 Console 日志
- 说明期望行为："应该显示版本列表"

❌ DON'T:
- 模糊描述："有点问题"
- 没有上下文："改一下"
- 多个问题混在一起
```

### Xcode 调试技巧
```
- Console (⇧⌘C): 查看日志和错误
- Breakpoint Navigator (⌘8): 管理断点
- Debug Area (⇧⌘Y): 查看变量
- Issues Navigator (⌘5): 查看编译错误
```

## 文件位置

- Pipeline: `Makefile`
- Pre-commit: `.git/hooks/pre-commit`
- CI: `.github/workflows/ci.yml`
- 文档: `docs/pipeline.md`, `PIPELINE.md`
- Constitution: `.specify/memory/constitution.md`

---

**Pipeline Status**: ✅ 已激活并运行
**Constitution Version**: 1.1.0
**Last Updated**: 2025-12-06
