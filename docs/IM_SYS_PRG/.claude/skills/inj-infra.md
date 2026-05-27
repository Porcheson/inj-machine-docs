---
name: inj-infra
description: 生成注塑机 PLC 程序的基础设施层代码——液压轴 FB_HydAxis + AxisTypes、温控 FB_EK312 + EK312Types、手动模式 FB_ManualMode、调模模式 FB_MoldAdjustMode、自动周期 FB_AutoCycle + AutoCycleTypes、全局变量 GlobalVars、实例管理 Instances。
---

# 基础设施层代码生成

调用此技能将生成基础设施层的全部 8 个文件。

## 前置要求

必须先读取以下参考文档：
- `.claude/MDs/infra-template.md` — 基础设施完整模板
- `.claude/MDs/naming-conventions.md` — 命名和注释规范
- `.claude/MDs/architecture.md` — 架构和目录结构
- `.claude/MDs/fb-module-template.md` — 功能块模板（含 ManualMode/MoldAdjustMode）

## 生成文件清单

### 1. AxisTypes.st → `Code/伺服系统/液压轴/`

定义轴层全部类型：

**E_AxisState**: (Idle, Running, Stop)

**ST_PumpRequest**: bRequest(BOOL), rFlowSet(LREAL), rPressureSet(LREAL)

**ST_HydAxisStatus**:
- bEnabled, bReady, bCommandActive (BOOL)
- bInPosition, bInVelocity, bInPressure (BOOL — 到位判断)
- bAlarm (BOOL), dwAlarmID (DWORD), uiActTime (UINT)
- rCmdPosition, rCmdVelocity, rCmdPressure (LREAL — 限幅后最终输出)

**ST_AxisRefHyd**:
- bActive (BOOL), eAxisState (E_AxisState), nAxisID (INT)
- 能力边界：rMaxCylinderStroke, rMaxVelocity, rMaxPressure (LREAL)
- 容差：rPosTolerance, rVelTolerance, rPresTolerance (LREAL)
- 目标命令：rSetPosition, rSetVelocity, rSetPressure (LREAL)
- 实际反馈：rActualPosition, rActualVelocity, rActualPressure (LREAL)
- stStatus: ST_HydAxisStatus
- stPumpRequest: ST_PumpRequest
- nFaultCode: INT

每个字段带行尾注释说明语义。

### 2. FB_HydAxis.st → `Code/伺服系统/液压轴/`

统一液压轴功能块。

**输入**：bEnable(BOOL), bEStop(BOOL), bStop(BOOL), stAxisConfig(ST_HydAxisConfig)

**VAR_IN_OUT**：stAxisCmd(ST_AxisRefHyd)

**内部处理链**：
1. 模块报警继承（stAxisCmd.nFaultCode → stAxisCmd.stStatus）
2. EStop 优先级最高：bCommandActive=FALSE, eAxisState=Stop, 全部命令清零
3. Stop：类似 EStop 但不置报警
4. Enable 检查：bReady 判断，允许执行时设 bCommandActive=TRUE
5. 目标值限幅（Position/Velocity/Pressure 分别对 Max 做 MIN 限幅）
6. 到位判断（实际值与目标值的差值对容差）
7. 100ms TON 脉冲计时器驱动 uiActTime 累加
8. 泵请求整理（当 bCommandActive 时拉请求+整理流量/压力设定）

**VAR**：tPulse(TON), 限幅后中间变量

### 3. EK312Types.st → `Code/温度系统/EK312/`

**ST_EK312ZonePara**：uiSetTemp(UINT), uiAlarmHigh(UINT), uiAlarmLow(UINT), uiP(UINT), uiI(UINT), uiD(UINT)

**ST_EK312Para**：aZone: ARRAY[1..12] OF ST_EK312ZonePara

**ST_EK312OutPara**：aActualTemp: ARRAY[1..12] OF UINT, aHeating: ARRAY[1..12] OF BOOL, aAlarm: ARRAY[1..12] OF BOOL, bAnyAlarm(BOOL)

**ST_EK312Status**：同上 + bReady(BOOL)

### 4. FB_EK312.st → `Code/温度系统/EK312/`

12 路温控器功能块（控制/仿真双模）。

**输入**：bTempStart(BOOL), stTempPara(ST_EK312Para), bR0~bR3(BOOL)

**输出**：stTempStatus(ST_EK312Status)

**仿真逻辑**（100ms 拍驱动）：
- 当 bTempStart=TRUE 且对应加热组使能时，温度每拍递增固定步长
- 未加热时温度自然递减（模拟散热）
- 温度限幅到设定值
- 报警判断（超过上限或低于下限）

**人工加热组**：R0→Zone 1-3, R1→Zone 4-6, R2→Zone 7-9, R3→Zone 10-12

**注释明确标注**："若后续接入真实温控器，可保留本接口不变，仅替换内部驱动实现"

### 5. FB_ManualMode.st → `Code/模式管理/手动模式/`

手动模式命令透传器。

**输入**：bStop, bEStop, bReset, bActive(BOOL), stManual(ST_MachineManualCommand)

**输出**：所有模块的 b*Start + ui*Mode（展开的全部字段）

**逻辑**：
- 失效时（Reset/Stop/EStop/NOT Active）：全部输出清零
- 生效时：直接透传 stManual 中的各模块命令

### 6. FB_MoldAdjustMode.st → `Code/模式管理/调模模式/`

调模模式命令约束器。

**输入**：bStop, bEStop, bReset, bActive(BOOL), stManual(ST_MachineManualCommand)

**输出**：bClampStart/uiClampMode, bMoldAdjustStart/uiMoldAdjustMode

**逻辑**：
- 失效时：全部输出清零
- 生效时：
  - 锁模调试方向约束：uiClampMode 1/3→3, 2/4→4, 其他→0
  - 调模块直接透传

### 7. FB_AutoCycle.st → `Code/模式管理/自动模式/`

自动周期调度器。

完整状态机流程（16 个状态）：
```
Idle → Init → ClampClose → [NozzleIn] → [Inject] → PreCool 
→ [PreSuckBack] → [Meter] → [PostSuckBack] → PostCool 
→ [NozzleOut] → ClampOpen → [EjectIn] → EjectOut → CycleEnd → (循环或停止)
```

步骤切换条件表：
| 步骤 | 等待条件 | 完成后去向 |
|------|---------|-----------|
| ClampClose | bMoldClosed OR bClampDone | NozzleIn 或 Inject 或 PreCool |
| NozzleIn | bNozzleIned OR bNozzleDone | Inject 或 PreCool |
| Inject | bHeld OR bInjectDone | PreCool |
| PreCool | 计时到 uiPreCoolTime | PreSuckBack 或 Meter 或 PostSuckBack 或 PostCool |
| PreSuckBack | bSuckBacked OR bInjectDone | Meter 或 PostSuckBack 或 PostCool |
| Meter | bMetered OR bMeterDone | PostSuckBack 或 PostCool |
| PostSuckBack | bSuckBacked OR bInjectDone | PostCool |
| PostCool | 计时到 uiPostCoolTime | NozzleOut 或 ClampOpen |
| NozzleOut | bNozzleOuted OR bNozzleDone | ClampOpen |
| ClampOpen | bMoldOpened OR bClampDone | EjectIn 或 CycleEnd |
| EjectIn | bEjectIned OR bEjectDone | EjectOut |
| EjectOut | bEjectOuted OR bEjectDone | CycleEnd |
| CycleEnd | 周期计数+1 | 全自动→ClampClose(需ReadyOK)，半自动→Idle(需释放Start) |

**输入**：bStart/bStop/bEStop/bReset, uiAutoMode, stAutoPara, bDoorClosed/bHydReady/bSystemNoAlarm, 各模块 Done/Alarm/到位信号

**输出**：bBusy/bDone/bAlarm/dwAlarmID/uiActHint/uiActTime/uiCycleCount, 各模块 Start/Reset/Mode

**内部**：eState(E_AutoCycleState), ePrevState, tPulse(TON), udiElapsedMs(UDINT), bStateEntry(BOOL), bReadyOk(BOOL)

每个状态内部模式：
- bStateEntry 时发 Reset 脉冲
- 否则设 Mode + Start
- 检测 Alarm → eState_Error
- 检测完成条件 → 下一状态

**uiActHint 分配**：
- Init: 1000
- ClampClose: 81
- NozzleIn: 113
- Inject: 44
- PreCool: 69
- PreSuckBack: 71
- Meter: 11
- PostSuckBack: 72
- PostCool: 70
- NozzleOut: 114
- ClampOpen: 19
- EjectIn: 28
- EjectOut: 31
- CycleEnd: 1000
- Error: 1

### 8. AutoCycleTypes.st → `Code/模式管理/自动模式/`

E_AutoCycleState 枚举（16 状态 + Error）和 ST_AutoCyclePara 结构（7 个使能位 + 2 个时间 + 停机计数）。

### 9. GlobalVars.st → `Code/全局变量/`

全部全局变量统一收口。VAR_GLOBAL 中包含：
- gvl_stPLCIO: ST_PLCIO
- gvl_stModbus: ST_Modbus
- gvl_stPara: ST_MachinePara
- gvl_stHMIPara/Command/Status: 对应 HMI 类型
- gvl_stCommand: ST_MachineCommand
- gvl_stPLCDigitalCommandSource: ST_MachineCommand
- gvl_stPanelCommandSource: ST_MachineCommand
- gvl_stSensor: ST_MachineSensor
- gvl_stStatus: ST_MachineStatus
- gvl_ePanelModel: E_PanelModel
- gvl_stPanelIO: ST_PanelIO
- gvl_stPanelButtons: ST_PanelButtons
- gvl_aCoreAllow: ARRAY[1..8] OF BOOL
- gvl_stTempOutPara: ST_EK312OutPara
- 7 个轴镜像：gvl_st{Module}AxisMirror: ST_AxisRefHyd

头注释包含维护规则说明。

### 10. Instances.st → `Code/实例管理/`

全部顶层 FB 实例化 VAR_GLOBAL：
- fbPLCDigitalInputBinder
- fbPLCMachineInputMapper
- fbModbus
- fbHMIParaInterface
- fbPanelDispatcher
- fbCommandArbiter
- fbMachineController
- fbPLCMachineOutputMapper
- fbPLCDigitalOutputBinder
- fbEK312

每个实例带行尾注释说明其职责。

## 关键规则

1. FB_HydAxis 的 EStop 优先级最高，其次是 Stop，最后是 Enable 检查
2. FB_EK312 仿真模式中温度递增/递减步长要合理（建议每秒 1-2 度对应 100ms 拍）
3. FB_AutoCycle 每个状态先清零所有模块输出再设置当前状态的命令
4. FB_AutoCycle 使用 bStateEntry 检测状态切换，用于发出一次性 Reset 脉冲
5. GlobalVars.st 头注释包含维护规则：「任何改动都须同步更新 3 份 MD 文档」
6. Instances.st 中实例顺序与 PRG_MainControl 中调用顺序一致
