---
name: inj-arch
description: 生成注塑机 PLC 程序的主控制架构代码——主入口 PRG_MainControl、机器控制器 FB_MachineController、命令仲裁 FB_CommandArbiter、命令组合 FB_MachineCommandComposer、模式解析 FB_MachineModeResolver、状态汇总 FB_MachineStatusAggregator，以及顶层类型定义 MachineControlTypes.st。
---

# 注塑机主控制架构代码生成

调用此技能将生成 `Code/主程序入口/` 目录下的全部 7 个文件。请按顺序生成，每个文件写入正确的子目录。

## 前置要求

必须先读取以下参考文档以了解完整规范：
- `.claude/MDs/architecture.md` — 整体架构和调用链
- `.claude/MDs/naming-conventions.md` — 命名和注释规范
- `.claude/MDs/types-template.md` — 类型定义模板
- `.claude/MDs/fb-module-template.md` — 功能块模板

## 生成文件清单

### 1. MachineControlTypes.st → `Code/主程序入口/`

定义所有机器级类型。包含以下结构体和枚举：

**ST_MachineManualCommand** — 手动命令结构，包含所有执行模块的 Start + Mode 字段：
- bClampStart/uiClampMode, bMoldAdjustStart/uiMoldAdjustMode, bNozzleStart/uiNozzleMode, bInjectStart/uiInjectMode, bMeterStart, bEjectStart/uiEjectMode, bEjectModeStart/uiEjectPatternMode/uiEjectTimes, bCoreStart/uiCoreMode, bMotorStart, bTempStart, bR0~bR3, bBlowStart/bBlowAStart/bBlowBStart, bLubeStart, bZipperBwdStart/bZipperFwdStart/bZipperClampStart/bZipperMotorStart, bLockInStart/bLockOutStart

**ST_MachineCommand** — 机器命令结构：
- uiMachineMode: UINT
- stManual: ST_MachineManualCommand
- bStart/bStop/bEStop/bReset: BOOL

**ST_MachineSensor** — 传感器汇总（全部 BOOL + 模拟量）：
- bSafetyDoorClosed, bHydReady, bSystemNoAlarm
- bClampClosed, bClampOpened, bClampAlarm
- bNozzleIned, bNozzleOuted, bNozzleAlarm
- bInjected, bHeld, bSuckBacked, bInjectAlarm
- bMetered, bMeterAlarm
- bEjectIned, bEjectOuted, bEjectAlarm
- bCoreIned, bCoreOuted, bCoreAlarm
- bMoldAdjustIned, bMoldAdjustOuted, bMoldAdjustAlarm
- bMotorRunning, bTempReady
- udiClampElecRulerVal, rClampPressure, udiInjectElecRulerVal, rInjectPressure, udiMeterElecRulerVal, rMeterBackPressure, udiEjectElecRulerVal, rEjectPressure, udiCoreElecRulerVal, rCorePressure, udiNozzleElecRulerVal, rNozzlePressure, udiMoldAdjustElecRulerVal, rMoldAdjustPressure: UDINT/LREAL

**ST_MachineStatus** — 机器状态汇总（全部 BOOL）：
- bManualModeActive, bSemiAutoModeActive, bFullAutoModeActive, bMoldAdjustModeActive
- bMachineBusy, bMachineDone, bMachineAlarm, dwMachineAlarmID
- bMoldOpened, bMoldClosed, bClampBusy, bClampDone, bClampAlarm, dwClampAlarmID
- 类似字段覆盖 Nozzle, Inject, Meter, Eject, EjectMode, Core, MoldAdjust, Temp
- bMeterBusy, bEjectModeSelected, bMotorOn, bTempOn
- uiActHint, uiActTime (UINT)
- bEStopActive: BOOL

**ST_MachinePara** — 机器参数汇总（包含各模块参数子结构 + 自动周期参数）

**ST_MachineModeState** — 模式状态（bModeChanged, uiPrevMode, uiCurrentMode）

**ST_ModuleCommandSource** — 单模块命令源（bStart, bReset, uiMode）

**ST_MachineCommandSourceSet** — 全部模块命令源集合（stClamp, stMoldAdjust, stNozzle, stInject, stMeter, stEject, stEjectMode, stCore）

**ST_MachineModuleCommands** — 全部模块最终命令（展开的 Start/Reset/Mode + bMotorStart, bTempStart, bR0~bR3）

**ST_HMIProcessPara** — HMI 工艺参数（镜像 ST_MachinePara 但用于 HMI 缓冲区）

**ST_HMIParaCommand** — HMI 参数命令（bApplyToMachine, bReadBack, bClearDirty, bLoadInitial）

**ST_HMIParaStatus** — HMI 参数状态（bDirty, bSyncOK, uiSyncCount）

**ST_ModuleRuntimeStatus** — 模块运行状态（bBusy, bDone, bAlarm, dwAlarmID）

每个结构体成员必须带行尾注释 `// 中文说明`。文件以 `(*` 头注释块开始，说明功能。

### 2. PRG_MainControl.st → `Code/主程序入口/`

唯一 PROGRAM 入口，1ms 基础周期。

```pascal
PROGRAM PRG_MainControl
VAR
    // 节拍计数器
    uiTick10ms: UINT := 0;
    uiTick100ms: UINT := 0;
    bTick10ms: BOOL := FALSE;
    bTick100ms: BOOL := FALSE;
END_VAR
```

调用链（严格按此顺序）：
1. `fbPLCDigitalInputBinder(...)` — IN[] → X* 绑定
2. `fbPLCMachineInputMapper(...)` — X* → 语义传感器
3. `fbModbus.InputBind(...)` — Modbus 输入绑定
4. `fbHMIParaInterface(...)` — HMI 参数同步
5. `fbPanelDispatcher(...)` — 面板调度
6. `fbModbus.OutputBind(...)` — Modbus 输出绑定
7. `fbCommandArbiter(...)` — 命令仲裁
8. IF bTick100ms THEN `fbEK312(...)` — 温控（100ms 拍）
9. IF bTick10ms THEN `fbMachineController(...)` — 机器主控（10ms 拍）
10. `fbPLCMachineOutputMapper(...)` — 语义 → Y* 映射
11. `fbPLCDigitalOutputBinder(...)` — Y* → OUT[] 绑定

节拍分频逻辑：
- uiTick10ms 累加，到 10 时触发 bTick10ms 并清零
- uiTick100ms 累加，到 100 时触发 bTick100ms 并清零

### 3. FB_MachineController.st → `Code/主程序入口/`

机器主控制器。实例化全部子模块并协调执行。仅 10ms 拍消费。

包含：
- FB_MachineModeResolver 实例
- FB_ManualMode 实例  
- FB_MoldAdjustMode 实例
- FB_MachineCommandComposer 实例
- FB_AutoCycle 实例
- 全部 8 个执行模块实例（FB_Clamp, FB_MoldAdjust, FB_Inject, FB_Nozzle, FB_Meter, FB_Eject, FB_EjectMode, FB_Core）
- FB_MachineStatusAggregator 实例

内部流程：
1. 模式解析 → 手动/调模/自动模式判断
2. 手动模式命令路由
3. 调模模式命令约束
4. 命令组合器合并三源命令
5. 自动周期调度（仅在自动模式）
6. 执行模块逐一调用（传入合并后的命令 + 工艺参数 + 传感器）
7. 状态汇总

模拟量反馈全部以 0 占位传入：
```
udiClampElecRulerVal := UDINT#0,
rClampActualPosition := LREAL#0.0,
rClampActualVelocity := LREAL#0.0,
rClampActualPressure := LREAL#0.0,
```

### 4. FB_CommandArbiter.st → `Code/主程序入口/`

三级命令仲裁：
1. 基础快照：保留 MachineControlTypes 中定义的命令结构默认值
2. PLC 数字量命令源叠加：X50-X53 → 公共启动/停止/复位/急停
3. 面板命令源叠加：模式选择 + 手动点动命令

### 5. FB_MachineCommandComposer.st → `Code/主程序入口/`

合并手动/调模/自动三源命令为最终模块命令：
- 手动命令源直接透传到各模块
- 自动命令源从 FB_AutoCycle 输出获取
- 调模命令源约束后合并
- 托模双模块互斥：基础托模 (FB_Eject) 与组合托模 (FB_EjectMode) 互斥，只选一个输出

### 6. FB_MachineModeResolver.st → `Code/主程序入口/`

从命令源解析机器模式：手动=1, 半自动=2, 全自动=3, 调模=4。
检测模式变更时生成全局停止信号。

### 7. FB_MachineStatusAggregator.st → `Code/主程序入口/`

汇总全部模块状态为统一机器状态：
- 各模块 Busy/Done/Alarm 汇总
- 报警优先级链（EStop > 模块Alarm > 系统告警）
- 动作提示号 uiActHint 的汇总展示逻辑
- 到位状态传递

## 关键规则

1. 每个文件以 `(*` 头注释块开始，包含「功能」和「说明」两段
2. 每个变量声明必须带行尾 `// 注释`
3. 每个有副作用的代码行必须带行尾 `// 注释`
4. 使用 4 空格缩进
5. 类型名遵循前缀约定（ST_/E_/FB_）
6. 变量名遵循匈牙利前缀约定（b/ui/r/dw/st/e/n）
7. 数组上界与 e*_Count 哨兵保持一致性
