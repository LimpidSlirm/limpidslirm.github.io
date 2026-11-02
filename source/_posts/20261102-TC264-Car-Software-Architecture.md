---
title: 面向 TC264 课程小车的裸机混合软件架构
date: 2026-11-02 16:15:00
index_img: /img/20261102.png
index_img_position: right
tags:
  - Smart Car
  - Embedded Systems
  - TC264
  - Software Architecture
---

2026-11-02 智能车课程架构研究与工程落地记录。今天围绕当前 TC264 裸机工程，设计了适合课程小车的轻量级软件架构，并将第一阶段的接口骨架同步到项目。

## 1. 为什么需要重新组织架构

当前小车已经包含：

- 按键输入；
- PIT 周期中断；
- A/B H 桥电机输出；
- 编码器计数；
- 左右轮速度 PID；
- UART 和 TFT 调试接口。

如果所有逻辑继续堆积在 `app.c` 或 `isr.c` 中，新增循迹、姿态、避障和通信功能后会出现几个问题：

1. 硬件端口和业务逻辑互相污染；
2. PID、传感器和电机模块难以独立测试；
3. 中断函数越来越长，实时性难以评估；
4. 修改一个引脚可能影响多个业务文件；
5. 后续扩展只能不断增加条件分支。

因此本次选择不引入 RTOS，而是在现有裸机工程基础上采用：

> 分层架构 + 周期任务调度 + 事件驱动的轻量级混合架构。

## 2. 推荐架构

整体分为四层：

```text
应用层
    模式管理、目标速度、故障策略、用户交互
        ↓
控制与功能模块层
    PID、速度控制、按键、循迹、姿态、避障、通信
        ↓
设备抽象层
    电机、编码器、传感器、显示、UART
        ↓
底层驱动层
    GPIO、PWM、GPT12、PIT、UART、SPI
```

数据流原则是：

```text
传感器数据向上汇聚
控制目标向下传递
硬件细节停留在设备抽象层
按键和故障以事件进入应用层
```

## 3. 裸机任务模型

当前工程没有 RTOS，因此不能依赖操作系统提供任务调度。可以使用 PIT 作为统一时间基准，把任务按实时性划分：

```text
快速基础任务：采样、计时、电机输出刷新
控制任务：编码器测速、速度 PID、姿态控制
中速任务：循迹计算、状态机、传感器融合
低速任务：UART、参数保存、显示和日志
```

具体周期不应脱离传感器和执行器特性随意决定。当前已验证的控制链路是 1 ms 基础节拍和 10 ms 速度 PID 更新；未来循迹、姿态和通信任务应根据实际采样率再分配。

中断函数统一放在 `user/isr.c`，建议中断只做：

1. 清除中断标志；
2. 读取极短的硬件数据；
3. 更新必要的快速输出；
4. 递增时间基准或置任务标志；
5. 尽快退出。

字符串解析、参数校验、模式切换和复杂故障策略应放在主循环或低频任务中。

## 4. 当前工程的模块映射

| 文件 | 架构职责 |
|---|---|
| `user/cpu0_main.c` | CPU0 启动入口 |
| `user/isr.c` | PIT 和其他中断函数 |
| `code/app.c/.h` | 应用层、按键行为和目标管理 |
| `code/key_module.c/.h` | 按键采样、消抖和事件 |
| `code/motor.c/.h` | A/B H 桥输出和电机缓启动 |
| `code/pid.c/.h` | 通用 PID 算法 |
| `code/speed_control.c/.h` | 编码器采样和左右轮闭环 |
| `code/motion_interface.h` | 运动命令和运动反馈结构 |

`libraries/` 只作为底层能力来源，不修改其中的文件。

## 5. 第一阶段接口骨架

为了避免应用层直接依赖控制模块内部变量，新增了统一的运动接口：

```c
typedef struct
{
    int16 left_target;
    int16 right_target;
    uint8 enable;
    uint8 safety_stop;
} motion_command_t;

typedef struct
{
    int16 left_measurement;
    int16 right_measurement;
    int16 left_output;
    int16 right_output;
    uint8 feedback_valid;
} motion_feedback_t;
```

应用层通过命令结构提交目标：

```c
speed_control_set_command(&command);
```

控制模块通过反馈结构提供状态：

```c
speed_control_get_feedback(&feedback);
```

本次接口整理采用兼容方式，保留原来的 `speed_control_set_target()` 和分项读取函数，因此不会改变已经验证的 PID、电机映射和按键行为。

## 6. 运动控制数据流

```text
KEY3 / KEY4
     ↓
app.c 生成 motion_command_t
     ↓
speed_control.c
     ├── 读取 TIM5/TIM6 编码器增量
     ├── 分别运行左右轮 PID
     └── 调用 motor_set()
             ↓
motor.c
     ├── 逻辑左轮：P02.4 / P02.5
     └── 逻辑右轮：P02.6 / P02.7
```

这样，PID 不需要知道 PWM 的具体引脚，应用层也不需要知道编码器计数器的寄存器细节。

## 7. 目录结构规划

当前工程可以逐步整理为：

```text
E01_gpio_demo/
|-- code/
|   |-- app.c / app.h
|   |-- scheduler.c / scheduler.h
|   |-- motion_interface.h
|   |-- pid.c / pid.h
|   |-- speed_control.c / speed_control.h
|   |-- motor.c / motor.h
|   |-- encoder.c / encoder.h
|   |-- key_module.c / key_module.h
|   |-- line_sensor.c / line_sensor.h
|   |-- imu.c / imu.h
|   |-- safety_manager.c / safety_manager.h
|   `-- protocol.c / protocol.h
|-- user/
|   |-- cpu0_main.c
|   |-- isr.c
|   `-- isr_config.h
|-- libraries/
|-- 实验报告/
`-- AI对话日志.md
```

其中 `scheduler`、循迹、姿态和安全管理模块属于后续扩展，不在本次接口骨架阶段一次性实现。

## 8. 架构优点

### 8.1 硬件变化影响范围小

本次调试中，电机接口从“方向+PWM”的错误假设改成 A/B H 桥输出，并重新交换了左右轮逻辑映射。由于电机硬件细节集中在 `motor.c`，应用层和 PID 算法不需要跟着修改。

### 8.2 适合实时控制

编码器采样和 PID 有固定周期，通信、显示和按键事件则可以放到低频处理。这样能够避免串口输出或复杂逻辑阻塞速度环。

### 8.3 便于测试

可以按层验证：

```text
PID 数学计算
    ↓
编码器反馈
    ↓
单轮电机输出
    ↓
双轮开环
    ↓
双轮闭环
```

### 8.4 便于扩展

循迹可以输出左右轮差速目标，姿态控制可以复用 PID，避障可以通过安全管理器发出限速或停车请求，而不需要直接操作 PWM。

## 9. 架构缺点和风险

裸机混合架构仍然需要手动处理共享数据和任务时序。随着功能增加，软件计时器和任务标志可能变复杂；一个模块执行时间过长，也可能影响其他任务。由于没有 RTOS 的任务隔离，还需要主动增加：

- 传感器数据有效性检查；
- 控制任务超时检测；
- 通信命令边界检查；
- 统一的故障停车接口；
- 对 ISR 和主循环共享变量的临界区保护。

因此，架构设计不能只停留在目录划分，还必须持续测量任务执行时间和控制周期。

## 10. 构建验证

接口骨架完成后，使用工程现有 headless 构建脚本进行回归编译：

```text
build_headless.bat build
```

结果为：

```text
Build Finished. 0 errors, 0 warnings.
```

本阶段只整理接口，没有改变已验证的电机映射、PID 参数和按键行为，因此没有重新烧录。后续若实现调度器或安全管理器，应重新进行编译、烧录和实车回归测试。

## 11. 后续实施顺序

建议按以下顺序继续：

1. 增加统一状态快照和故障停车接口；
2. 将 PIT 中的周期控制改为任务标志调度；
3. 增加循迹传感器模块；
4. 增加姿态/角度控制模块；
5. 增加避障和安全管理；
6. 最后接入通信参数服务。

每一步都应保持已有电机和速度 PID 接口稳定，并单独完成编译和硬件回归。

