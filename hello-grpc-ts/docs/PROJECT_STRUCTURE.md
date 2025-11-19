# hello-grpc-ts 项目结构

## 概述

本项目采用标准的 TypeScript 项目结构，清晰地分离了源代码、构建输出、脚本和文档。

## 目录结构

```
hello-grpc-ts/
├── src/                      # 源代码目录
│   ├── generated/            # Proto 生成的文件
│   │   ├── landing_grpc_pb.d.ts
│   │   ├── landing_grpc_pb.js
│   │   ├── landing_pb.d.ts
│   │   └── landing_pb.js
│   ├── lib/                  # 通用库和工具
│   │   ├── conn.ts           # gRPC 连接管理
│   │   ├── tls.ts            # TLS/SSL 证书管理
│   │   ├── utils.ts          # 工具函数
│   │   ├── errorMapper.ts    # 错误映射
│   │   ├── loggingConfig.ts  # 日志配置
│   │   ├── retry_helper.ts   # 重试辅助
│   │   └── shutdownHandler.ts # 优雅关闭处理
│   ├── proto/                # Proto 定义文件（如果有）
│   ├── hello_server.ts       # gRPC 服务器实现
│   └── hello_client.ts       # gRPC 客户端实现
├── dist/                     # 编译输出目录
│   ├── generated/            # 编译后的 proto 文件
│   ├── lib/                  # 编译后的库文件
│   ├── hello_server.js
│   └── hello_client.js
├── scripts/                  # 脚本目录
│   ├── server_start.sh       # 服务器启动脚本
│   ├── client_start.sh       # 客户端启动脚本
│   ├── build.sh              # 构建脚本
│   ├── start_tls_server.ps1  # Windows TLS 服务器脚本
│   └── start_tls_client.ps1  # Windows TLS 客户端脚本
├── docs/                     # 文档目录
│   ├── PROJECT_STRUCTURE.md  # 本文件
│   └── SCRIPTS_USAGE.md      # 脚本使用指南
├── test/                     # 测试目录
│   └── utils.test.ts         # 工具函数测试
├── logs/                     # 日志目录
│   └── .gitkeep
├── node_modules/             # Node.js 依赖
├── package.json              # 项目配置
├── package-lock.json         # 依赖锁定文件
├── tsconfig.json             # TypeScript 配置
├── yarn.lock                 # Yarn 锁定文件
└── README.md                 # 项目说明
```

## 目录说明

### src/ - 源代码目录

所有 TypeScript 源代码都位于此目录。

#### src/generated/
- **用途**: 存放从 Protocol Buffers 定义生成的代码
- **文件**: 
  - `landing_grpc_pb.js/d.ts` - gRPC 服务定义
  - `landing_pb.js/d.ts` - Protocol Buffers 消息定义
- **注意**: 这些文件是自动生成的，不应手动编辑

#### src/lib/
- **用途**: 可复用的库代码和工具函数
- **主要文件**:
  - `conn.ts` - gRPC 连接管理，包括客户端创建和服务器配置
  - `tls.ts` - TLS/SSL 证书加载和凭证创建
  - `utils.ts` - 通用工具函数
  - `errorMapper.ts` - gRPC 错误码映射
  - `loggingConfig.ts` - Winston 日志配置
  - `retry_helper.ts` - 请求重试逻辑
  - `shutdownHandler.ts` - 优雅关闭处理

#### src/hello_server.ts
- **用途**: gRPC 服务器主程序
- **功能**:
  - 实现四种 gRPC 通信模式
  - 支持 TLS 和非 TLS 模式
  - 支持代理模式
  - 优雅关闭处理

#### src/hello_client.ts
- **用途**: gRPC 客户端主程序
- **功能**:
  - 演示四种 gRPC 通信模式
  - 支持 TLS 和非 TLS 模式
  - 自动重试机制
  - 优雅关闭处理

### dist/ - 编译输出目录

TypeScript 编译后的 JavaScript 文件存放在此目录。

- **结构**: 与 `src/` 目录结构保持一致
- **生成**: 通过 `npm run build` 或 `tsc` 命令生成
- **注意**: 此目录应添加到 `.gitignore`

### scripts/ - 脚本目录

包含项目的各种脚本文件。

#### server_start.sh / client_start.sh
- **用途**: 启动服务器和客户端的便捷脚本
- **特性**:
  - 自动检查和安装依赖
  - 自动构建 TypeScript 项目
  - 支持 TLS 和非 TLS 模式
  - 灵活的命令行参数
  - 智能证书路径查找

#### build.sh
- **用途**: 构建脚本
- **功能**: 编译 TypeScript 代码并复制必要的文件

#### start_tls_*.ps1
- **用途**: Windows PowerShell 启动脚本
- **功能**: 在 Windows 环境下启动 TLS 服务器和客户端

### docs/ - 文档目录

项目文档集中存放位置。

- `PROJECT_STRUCTURE.md` - 项目结构说明（本文件）
- `SCRIPTS_USAGE.md` - 脚本使用指南
- 其他技术文档

### test/ - 测试目录

单元测试和集成测试文件。

- 使用 Mocha 测试框架
- 使用 ts-mocha 运行 TypeScript 测试
- 运行命令: `npm test`

### logs/ - 日志目录

应用程序运行时日志存放位置。

- Winston 日志输出目录
- 包含 `.gitkeep` 以保持目录结构

## 配置文件

### tsconfig.json

TypeScript 编译器配置：

```json
{
  "compilerOptions": {
    "rootDir": "./src",
    "outDir": "./dist",
    "baseUrl": "./src",
    "paths": {
      "@lib/*": ["lib/*"],
      "@generated/*": ["generated/*"]
    },
    "target": "es2016",
    "module": "commonjs",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "test", "scripts"]
}
```

**关键配置**:
- `rootDir`: 源代码根目录为 `src/`
- `outDir`: 输出目录为 `dist/`
- `baseUrl`: 模块解析基础路径
- `paths`: 路径别名配置（可选）
- `include`: 只编译 `src/` 目录下的文件
- `exclude`: 排除不需要编译的目录

### package.json

项目依赖和脚本配置：

```json
{
  "scripts": {
    "compile": "tsc --outDir dist",
    "build": "tsc --outDir dist",
    "start:server": "node dist/hello_server.js",
    "start:client": "node dist/hello_client.js",
    "test": "ts-mocha test/**/*.test.ts"
  }
}
```

## 导入路径规范

### 相对导入

在 `src/` 目录内，使用相对路径导入：

```typescript
// 在 src/hello_server.ts 中
import { logger } from './lib/conn';
import { TalkRequest } from './generated/landing_pb';

// 在 src/lib/conn.ts 中
import { LandingServiceClient } from '../generated/landing_grpc_pb';
```

### 外部依赖

使用包名直接导入：

```typescript
import * as grpc from '@grpc/grpc-js';
import { v4 as uuidv4 } from 'uuid';
import { createLogger } from 'winston';
```

## 构建流程

### 1. 安装依赖

```bash
npm install
```

### 2. 编译 TypeScript

```bash
npm run build
```

这会：
- 编译 `src/` 目录下的所有 `.ts` 文件
- 输出到 `dist/` 目录
- 保持目录结构

### 3. 复制生成的文件

```bash
cp src/generated/landing_*.js dist/generated/
```

Proto 生成的 `.js` 文件需要手动复制到 `dist/` 目录。

### 4. 运行

```bash
# 使用脚本（推荐）
bash scripts/server_start.sh
bash scripts/client_start.sh

# 或直接运行
node dist/hello_server.js
node dist/hello_client.js
```

## 开发工作流

### 添加新功能

1. 在 `src/lib/` 中创建新的模块文件
2. 在主文件中导入并使用
3. 运行 `npm run build` 编译
4. 测试功能

### 修改现有代码

1. 编辑 `src/` 目录下的 `.ts` 文件
2. 运行 `npm run build` 重新编译
3. 测试更改

### 添加测试

1. 在 `test/` 目录创建 `.test.ts` 文件
2. 编写测试用例
3. 运行 `npm test` 执行测试

## 最佳实践

### 1. 代码组织

- **单一职责**: 每个模块只负责一个功能
- **分层架构**: 
  - `src/lib/` - 底层工具和库
  - `src/hello_*.ts` - 应用层逻辑
  - `src/generated/` - 自动生成的代码

### 2. 导入管理

- 使用相对路径导入项目内部模块
- 按类型分组导入（外部依赖、内部模块）
- 避免循环依赖

### 3. 类型安全

- 充分利用 TypeScript 的类型系统
- 为函数参数和返回值添加类型注解
- 使用接口定义数据结构

### 4. 错误处理

- 使用 try-catch 捕获异常
- 记录详细的错误日志
- 提供有意义的错误消息

### 5. 日志记录

- 使用统一的日志系统（Winston）
- 记录关键操作和错误
- 使用适当的日志级别

## 与其他语言版本的对比

### 与 hello-grpc-nodejs 的区别

| 特性 | TypeScript | Node.js |
|------|------------|---------|
| 类型系统 | 静态类型 | 动态类型 |
| 编译 | 需要编译 | 直接运行 |
| 目录结构 | src/ + dist/ | 扁平结构 |
| 导入路径 | 相对路径 | 相对路径 |
| 开发体验 | IDE 支持更好 | 更灵活 |

### 共同特性

- 相同的 gRPC 功能
- 相同的 TLS 支持
- 相同的启动脚本接口
- 相同的配置方式

## 故障排除

### 编译错误

**问题**: 找不到模块

```
error TS2307: Cannot find module './common/landing_pb'
```

**解决**: 检查导入路径是否正确，应该使用 `./generated/` 或 `./lib/`

### 运行时错误

**问题**: 找不到模块

```
Error: Cannot find module './generated/landing_grpc_pb'
```

**解决**: 
1. 确保已运行 `npm run build`
2. 检查 `dist/generated/` 目录是否存在
3. 复制 proto 生成的 `.js` 文件到 `dist/generated/`

### 脚本错误

**问题**: 脚本找不到文件

**解决**: 确保从项目根目录运行脚本，或使用 `scripts/` 目录中的脚本

## 总结

这个标准化的项目结构提供了：

- ✅ 清晰的代码组织
- ✅ 标准的 TypeScript 项目布局
- ✅ 易于维护和扩展
- ✅ 良好的开发体验
- ✅ 与其他语言版本的一致性

通过遵循这个结构，可以更容易地理解、维护和扩展项目。
