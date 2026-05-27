# 注塑机 PLC 控制系统架构

## 目录结构

```
Code/
├── 主程序入口/           # 程序入口 + 机器控制核心 + 命令仲裁
│   ├── PRG_MainControl.st              # 唯一 PROGRAM，1ms 基础周期
│   ├── FB_MachineController.st         # 机器主控制器，实例化所有子模块
│   ├── FB_CommandArbiter.st            # 三级命令仲裁（基础→PLC数字量→面板）
│   ├── FB_MachineCommandComposer.st    # 命令组合器（手/自/调模合并）
│   ├── FB_MachineModeResolver.st       # 模式解析器
│   ├── FB_MachineStatusAggregator.st   # 状态汇总器（报警优先级+动作提示）
│   └── MachineControlTypes.st          # 机器级全部类型定义
├── 合模系统/
│   ├── 锁模/
│   │   ├── FB_Clamp.st                 # 合模/开模状态机
│   │   └── ClampTypes.st               # 合模类型（含中子参数耦合）
│   └── 调模/
│       ├── FB_MoldAdjust.st            # 调模进/退状态机
│       └── MoldAdjustTypes.st          # 调模类型
├── 注射系统/
│   ├── 射胶/
│   │   ├── FB_Inject.st                # 射出+保压+射退状态机
│   │   └── InjectTypes.st              # 射胶类型
│   ├── 储料/
│   │   ├── FB_Meter.st                 # 储料状态机
│   │   └── MeterTypes.st               # 储料类型
│   └── 座台/
│       ├── FB_Nozzle.st                # 座进/座退状态机
│       └── NozzleTypes.st              # 座台类型
├── 顶出系统/
│   ├── 托模/
│   │   ├── FB_Eject.st                 # 基础托模进/退
│   │   ├── FB_EjectMode.st             # 组合托模（定次/震动/停留）
│   │   └── EjectTypes.st               # 托模类型
│   └── 中子/
│       ├── FB_Core.st                  # 中子进/退状态机
│       └── CoreTypes.st                # 中子类型
├── 模式管理/
│   ├── 手动模式/FB_ManualMode.st       # 手动命令透传
│   ├── 调模模式/FB_MoldAdjustMode.st   # 调模命令约束
│   └── 自动模式/
│       ├── FB_AutoCycle.st             # 全自动+半自动周期调度
│       └── AutoCycleTypes.st           # 自动周期类型
├── 面板管理/
│   ├── 面板调度/FB_PanelDispatcher.st  # 面板型号调度+键→命令+状态→灯
│   ├── 面板通用/                        # 公用读键/写灯/位操作
│   │   ├── PanelTypes.st
│   │   ├── FB_PanelReader.st
│   │   ├── FB_PanelLampEncoder.st
│   │   ├── FB_PanelLampWriter.st
│   │   ├── F_PanelGetBit.st
│   │   ├── F_PanelReadKeyByOrder.st
│   │   └── F_PanelSetBit.st
│   ├── MK110/FB_MK110.st               # MK110 排序号定义
│   ├── MK116/FB_MK116.st               # MK116 排序号定义
│   ├── MK150/FB_MK150.st               # MK150 排序号定义
│   └── MK2030/FB_MK2030.st             # MK2030 排序号定义
├── IO管理/
│   ├── PLCIOTypes.st                   # 原始 IO 结构定义
│   ├── 数字量输入/
│   │   ├── FB_PLCDigitalInputBinder.st  # IN[x]→X* 绑定
│   │   └── FB_PLCMachineInputMapper.st  # X*→语义传感器
│   └── 数字量输出/
│       ├── FB_PLCDigitalOutputBinder.st # Y*→OUT[x] 绑定
│       └── FB_PLCMachineOutputMapper.st # 语义命令→Y* 映射
├── Modbus通讯/
│   ├── FB_Modbus.st                    # Modbus 双向绑定
│   └── ModbusTypes.st                  # Modbus 类型定义
├── HMI系统/
│   └── FB_HMIParaInterface.st          # HMI 参数安全机制
├── 伺服系统/液压轴/
│   ├── FB_HydAxis.st                   # 统一液压轴（限幅+保护）
│   └── AxisTypes.st                    # 轴类型定义
├── 温度系统/EK312/
│   ├── FB_EK312.st                     # 温控12路+仿真
│   └── EK312Types.st                   # 温控类型
├── 全局变量/GlobalVars.st              # 全部全局变量收口
└── 实例管理/Instances.st               # 全部 FB 实例化收口
```

## 主调用链（PRG_MainControl 内部）

```
1. IN[x] 原始绑定     → FB_PLCDigitalInputBinder
2. 输入语义映射       → FB_PLCMachineInputMapper
3. Modbus 输入绑定    → FB_Modbus (InputBind)
4. HMI 参数同步       → FB_HMIParaInterface
5. 面板调度           → FB_PanelDispatcher
6. Modbus 输出绑定    → FB_Modbus (OutputBind)
7. 命令仲裁           → FB_CommandArbiter
8. 温控处理           → FB_EK312
9. 机器主控           → FB_MachineController
   ├── 模式解析       → FB_MachineModeResolver
   ├── 手动模式命令   → FB_ManualMode
   ├── 调模模式命令   → FB_MoldAdjustMode
   ├── 命令组合       → FB_MachineCommandComposer
   ├── 自动周期       → FB_AutoCycle
   ├── 执行模块调用   → FB_Clamp / FB_MoldAdjust / FB_Inject / FB_Nozzle / FB_Meter / FB_Eject / FB_EjectMode / FB_Core
   └── 状态汇总       → FB_MachineStatusAggregator
10. 输出语义映射      → FB_PLCMachineOutputMapper
11. OUT[x] 原始下发   → FB_PLCDigitalOutputBinder
```

## 双节拍机制

- **1ms 基础周期**：PRG_MainControl 每个扫描周期都执行
- **10ms 工艺拍**：驱动 FB_MachineController（模式路由+自动流程+模块执行）
- **100ms 温控拍**：驱动 FB_EK312 温度计算

节拍由 PRG_MainControl 内部通过分频计数器生成。

## 命令流架构

```
面板按键 → FB_PanelDispatcher → stPanelCommandSource (ST_MachineCommand)
PLC X点  → FB_PLCMachineInputMapper → stPLCDigitalCommandSource (ST_MachineCommand)
                              ↓
                    FB_CommandArbiter (基础快照→PLC叠加→面板叠加)
                              ↓
                    gvl_stCommand (最终机器命令)
                              ↓
                    FB_MachineController
                      ├── FB_MachineModeResolver (模式号解析)
                      ├── FB_ManualMode (手动透传)
                      ├── FB_MoldAdjustMode (调模约束)
                      ├── FB_MachineCommandComposer (三源合并)
                      └── FB_AutoCycle (自动周期)
                              ↓
                    各执行模块 (FB_Clamp/FB_Inject/...)
                              ↓
                    FB_MachineStatusAggregator (状态汇总)
```

## 执行模块统一接口

每个执行模块（FB_Clamp, FB_Inject, FB_Nozzle, FB_MoldAdjust, FB_Meter, FB_Eject, FB_Core）遵循统一接口：

**输入**：Start / Stop / EStop / Reset + 模式号 + 工艺参数 + 现场传感器
**内部**：状态机 (CASE OF) + 时间累计 (TON 100ms) + 内部 FB_HydAxis
**输出**：Busy / Done / Alarm / dwAlarmID / uiActHint / uiActTime + 到位状态 + 工艺命令

## 模式号约定

| 模式号 | 含义 |
|--------|------|
| 0 | 停止/空闲 |
| 1 | 自动合模/自动开模 |
| 2 | 自动合模 |
| 3 | 调试进/开模调试 |
| 4 | 调退/合模调试 |
| 6 | 托模进调试 |
| 7 | 托模退调试 |

## 数据边界

所有模块间数据交换使用 TYPE STRUCT 定义：
- 机器级：MachineControlTypes.st
- 工艺级：ClampTypes.st, InjectTypes.st, MeterTypes.st, NozzleTypes.st, MoldAdjustTypes.st, EjectTypes.st, CoreTypes.st
- 轴层：AxisTypes.st
- 通讯：ModbusTypes.st
- 面板：PanelTypes.st
- IO：PLCIOTypes.st
- 温控：EK312Types.st
- 全局变量收口：GlobalVars.st
- 实例收口：Instances.st
