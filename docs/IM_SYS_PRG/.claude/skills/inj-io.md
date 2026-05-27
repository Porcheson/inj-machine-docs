---
name: inj-io
description: 生成注塑机 PLC 程序的 IO 管理、Modbus 通讯和 HMI 参数接口代码——数字量输入输出绑定与映射、PLCIOTypes、Modbus 双向通讯、HMI 参数安全接口。
---

# IO / Modbus / HMI 系统代码生成

调用此技能将生成 IO 管理、Modbus 通讯和 HMI 系统的全部 8 个文件。

## 前置要求

必须先读取以下参考文档：
- `.claude/MDs/io-system-template.md` — IO 系统完整模板
- `.claude/MDs/naming-conventions.md` — 命名和注释规范
- `.claude/MDs/architecture.md` — 架构和目录结构

## 生成文件清单

### 1. PLCIOTypes.st → `Code/IO管理/`

定义 ST_PLCIO 结构体，包含全部 X0~X57 和 Y0~Y57 位：
```
TYPE ST_PLCIO :
STRUCT
    // 数字量输入点 (对应 IN[0..57])
    X0..X57: BOOL;
    // 数字量输出点 (对应 OUT[0..57])
    Y0..Y57: BOOL;
END_STRUCT
END_TYPE
```
每个字段带行尾注释说明物理含义（示例：X0=安全门关到位，X50=启动，X51=停止，X52=复位，X53=急停等）。

### 2. FB_PLCDigitalInputBinder.st → `Code/IO管理/数字量输入/`

48 行硬编码绑定（IN[0]→X0 至 IN[47]→X47）：
```
gvl_stPLCIO.X0 := IN[0];  // 第 0 路数字量输入（安全门关到位信号）
...
gvl_stPLCIO.X47 := IN[47]; // 第 47 路数字量输入
```
每行必须带行尾注释。

### 3. FB_PLCMachineInputMapper.st → `Code/IO管理/数字量输入/`

将原始 X* 位翻译为语义传感器 ST_MachineSensor 和 PLC 数字量命令源：
- 安全门、液压就绪、急停等 → stSensor
- X50(启动)/X51(停止)/X52(复位)/X53(急停) → stPLCDigitalCommandSource
- 各模块行程开关 → stSensor 对应到位信号
- OR 组合左右托模停止信号
- 模拟量输入映射（当前全部以 0 占位）

### 4. FB_PLCDigitalOutputBinder.st → `Code/IO管理/数字量输出/`

48 行硬编码绑定（Y0→OUT[0] 至 Y47→OUT[47]）：
```
OUT[0] := gvl_stPLCIO.Y0;  // 第 0 路数字量输出（合模阀使能）
...
OUT[47] := gvl_stPLCIO.Y47; // 第 47 路数字量输出
```
每行必须带行尾注释。

### 5. FB_PLCMachineOutputMapper.st → `Code/IO管理/数字量输出/`

通过 uiActHint 将语义命令映射为 Y* 位输出：

**核心映射逻辑**（基于动作提示号）：
- Hint 18 → 泄压阀 (Y8)
- Hint 40/84/85/86 → 开模方向阀 (Y9)
- Hint 30/31/41/81/82/83 → 合模方向阀 (Y10)
- Hint 113 → 座进阀 (Y11)
- Hint 114 → 座退阀 (Y12)
- Hint 44/71/72 → 射胶阀 (Y16/Y17)
- Hint 11 → 储料阀 (Y20/Y21)
- Hint 28/31/92 → 托模阀 (Y18/Y19，Hint92 需方向锁存判断)
- Hint 19 → 调模阀 (Y14)
- Hint 1 → 报警灯 (Y0)

**显式清零的外围输出**（当前架构未建立模块命令边界）：
- Y13(倒带), Y15(拉带), Y24(拉带退), Y25(拉带进), Y26(吹气), Y27(吹气A)
- 润滑、定位等相关输出点

### 6. ModbusTypes.st → `Code/Modbus通讯/`

定义 ST_Modbus 统一结构：
- stPanelInput/Output: ST_PanelIO（面板 Modbus 镜像）
- stHMIInput/Output: ST_HMIProcessPara（HMI Modbus 镜像）
- 各区域起始地址常量注释

### 7. FB_Modbus.st → `Code/Modbus通讯/`

双向 Modbus 绑定功能块：
- InputBind 阶段：Modbus 寄存器 → PLC 内部数据（面板输入+HMI输入）
- OutputBind 阶段：PLC 内部数据 → Modbus 寄存器（面板输出+HMI输出）
- 内部面板 IO 与 Modbus 面板镜像的双向转换

### 8. FB_HMIParaInterface.st → `Code/HMI系统/`

HMI 参数安全接口。实现编辑缓冲区与在线参数的彻底解耦：

**核心机制**：
1. 初始加载：上电后从在线参数加载到编辑缓冲区
2. 读回同步：持续将在线参数同步到 HMI 显示
3. "应用到机器"：上升沿检测 + 机器忙碌互锁，只在空闲时写入
4. 脏标记管理：编辑缓冲区被修改时置位，应用后清位
5. 同步计数：每次成功应用递增，供 HMI 校验

**变量区**：
- VAR_IN_OUT: stOnlinePara, stEditBuffer
- VAR_INPUT: stCommand (ST_HMIParaCommand), bMachineBusy
- VAR_OUTPUT: stStatus (ST_HMIParaStatus)
- VAR: 上升沿缓存（bApplyLast, bReadBackLast, bClearDirtyLast, bLoadInitialLast）

## 关键规则

1. 所有硬编码 I/O 绑定点必须每行带行尾注释，说明物理含义
2. FB_PLCMachineOutputMapper 中未实现的外围输出必须显式清零并注释"当前架构尚未建立XX模块命令边界"
3. HMI 参数安全机制的核心："应用到机器"必须检查 bMachineBusy 互锁
4. 模拟量输入全部以 0 占位，注释标注"待接入真实模拟量采集链路"
