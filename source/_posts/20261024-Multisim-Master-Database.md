---
title: Multisim 打不开 Database
date: 2026-10-24 17:40:00
tags:
  - Multisim
  - Windows
---

Multisim 神了。打开之后提示无法打开 Master Database。

## 1. 现象

启动 Multisim 时直接弹出「无法打开 Master Database」，元件库整个不可用：

- 数据库文件确实存在，检查下来也没有损坏；
- 删除用户配置里的 `config` 目录，再重新注册 `dao360.dll`，**有概率**恢复正常；
- 换一台机器、或者重装之后再遇到，同样的操作又不一定生效。

也就是说，这不是一个确定性的修复步骤，而是「命中某个环节才有效」。下面把这条链路拆开看。

## 2. Master Database 是什么

Multisim 的元件库本质上是 Microsoft Access 的 `.mdb` 文件，默认位置：

```text
%ProgramData%\National Instruments\Circuit Design Suite\<版本>\database\
```

库一般分三类：

- **Master Database**：随安装提供的官方元件库；
- **Corporate Database**：机构共享库；
- **User Database**：本机用户维护的库。

除此之外，`%AppData%` 与 `%LocalAppData%` 下还各有一份**用户配置缓存**，用来记录最近打开的数据库、窗口状态、库路径等运行状态。

### 2.1 打开数据库的实际链路

Multisim 自己并不直接解析 `.mdb`，它通过 Windows 的 DAO / Jet 组件去打开：

```text
Multisim.exe
    ↓ 调用
DAO / Jet COM 组件（dao360.dll、msjet40.dll）
    ↓ 打开
database\*.mdb（同时在同目录写入 .ldb 锁文件）
```

所以「打不开」这个现象，可能发生在上面任意一层，而报错文案是同一个。

## 3. 文件没坏却打不开的原因

| 断点 | 典型表现 | 原因 |
| --- | --- | --- |
| COM 组件未注册 | 启动即报无法打开 | `dao360.dll`、`msjet40.dll` 的 CLSID 注册项缺失或失效 |
| 用户配置缓存损坏 | 库是好的，仍然打不开 | 缓存里的路径与状态和实际情况不符 |
| 文件属性或权限异常 | 报无法打开，或只读 | `.mdb` 被设为只读/隐藏，或 ACL 缺少写权限，无法创建 `.ldb` 锁文件 |

原先的「删 `config` + 重注册 `dao360.dll`」正好命中前两条，所以它能修好一部分机器，但对第三条无能为力。

> 第三点经常被忽略：Access 数据库在被打开时必须能与数据文件同目录创建锁文件。只读属性或目录权限不足都会让「文件明明是好的」变成「打不开」。

## 4. 解决方法

### 4.1 手动版本

1. 关闭 Multisim；
2. 删除 `%AppData%\National Instruments\Circuit Design Suite\<版本>\config`；
3. 以管理员身份重新注册 32 位 DAO 组件：

```bat
C:\Windows\SysWOW64\regsvr32.exe /s "C:\Program Files (x86)\Common Files\Microsoft Shared\DAO\dao360.dll"
```

4. 重新启动 Multisim。

### 4.2 脚本版本

手动步骤有两个问题：容易漏掉第三条链路，以及 `regsvr32` 的位宽很容易用错。`fix_multisim_database.bat` 把五件事串起来，并加上提权、备份和日志。

```bat
fix_multisim_database.bat            :: 正常修复
fix_multisim_database.bat -DryRun    :: 只预览，不修改任何东西
fix_multisim_database.bat -Full      :: 连带清理整个本地数据缓存
```

执行过程会打印每一步的结果，同时写入 `%TEMP%\multisim_db_fix.log`：

```text
[1/5] Closing Multisim and stopping NI services
[2/5] Looking for installed versions
[3/5] Clearing user configuration caches
[4/5] Resetting database file attributes and permissions
[5/5] Re-registering DAO and Jet database engines
```

## 5. 脚本做了什么

| 步骤 | 动作 | 针对的断点 |
| --- | --- | --- |
| 1 | 结束 `multisim.exe` 等进程，尝试停止 NI 服务 | 释放 `.mdb` / `.ldb` 文件句柄 |
| 2 | 扫描 `Circuit Design Suite` 下带 `database` 子目录的版本 | 避免写死版本号 |
| 3 | 备份并删除用户 `config` 缓存 | 配置缓存损坏 |
| 4 | 用 `attrib` 与 `icacls` 复位属性与权限 | 只读属性、ACL 缺写权限 |
| 5 | 按位宽重新注册 DAO / Jet | COM 注册项缺失或失效 |

### 5.1 自动提权

读取 `%SYSTEMROOT%\system32\config\system` 的 ACL 来判断是否管理员（非管理员会失败），不是就写一个临时 `.vbs` 用 `ShellExecute(..., "runas", 1)` 把自己以管理员身份重新拉起，然后原进程退出。

之所以必须提权：`%ProgramData%` 下的数据库目录、`regsvr32` 写入的 HKLM 注册项都需要管理员权限。`-DryRun` 模式跳过提权，因为只读预览不需要。

### 5.2 版本自动探测

原脚本写死 `set "VER=14.3"`，换机器或升级就失效。现在的判据是「该版本目录下存在 `database` 子目录」，用 `for /d` 遍历得到，不依赖具体版本号。

### 5.3 缓存先备份再删除

`config` 缓存用 `robocopy` 复制到 `%TEMP%\multisim_db_fix_backup\<随机号>\` 之后再删除，出问题可以还原。判断 robocopy 成败时用的是 `errorlevel GEQ 8`，因为它的 0–7 都算成功，直接判 `errorlevel 1` 会误报。

默认只删 `config` 子目录（破坏面最小），加 `-Full` 才删除整个版本目录。

### 5.4 regsvr32 的位宽必须匹配

这是「重注册有概率成功」的主要来源之一：

```text
32 位 DLL  →  C:\Windows\SysWOW64\regsvr32.exe
64 位 DLL  →  C:\Windows\System32\regsvr32.exe
```

位宽用错时 `regsvr32` 会静默失败，注册表里什么都没写进去。脚本对每个候选 DLL 分别用对应位宽的 `regsvr32` 注册，不存在的直接跳过（DAO 通常只有 32 位版本，`System32` 下并没有 `dao360.dll`）。

### 5.5 属性与权限复位

```bat
attrib -r -s -h "%DB%\*.*" /s /d
icacls "%DB%" /reset /T /C /Q
```

`attrib` 去掉只读、系统、隐藏属性（`/s` 递归、`/d` 连目录本身）；`icacls /reset` 把 ACL 恢复为从父目录继承的默认权限。这两条对应第三种断点。

## 6. 方案的边界

这个脚本解决的是：

- 用户配置缓存损坏导致的打不开；
- `.mdb` 只读属性或权限不足；
- DAO / Jet 的 COM 注册丢失；
- 运行中的进程占用数据库文件。

它不解决：

- 数据库文件本身损坏（需要从安装目录或备份恢复 `masterdatabase.mdb` 等文件）；
- `CPCompDev.prz` 变成 0 KB 这类初始化中断，脚本只会报告大小，不会自动修复；
- 杀毒软件/受限权限目录导致的持续写入失败；
- 不同版本（14.0、14.2、14.3 等）各自的私有问题。

如果脚本跑完仍然打不开，先看它打印的 `CPCompDev.prz` 大小：等于 0 字节基本可以确认数据库初始化被中断过，此时应优先考虑重新安装或恢复数据库文件，而不是继续折腾注册表。

---

## 脚本下载

- [下载 fix_multisim_database.bat](/downloads/fix_multisim_database.bat)