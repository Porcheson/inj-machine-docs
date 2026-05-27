---
name: inj-module
description: 生成注塑机 PLC 程序的全部执行模块——合模 FB_Clamp、调模 FB_MoldAdjust、射胶 FB_Inject、座台 FB_Nozzle、储料 FB_Meter、托模 FB_Eject、组合托模 FB_EjectMode、中子 FB_Core，以及对应的类型定义文件 ClampTypes/InjectTypes/MeterTypes/NozzleTypes/MoldAdjustTypes/EjectTypes/CoreTypes。
---

# 注塑机执行模块代码生成

调用此技能将生成 8 个执行模块（15 个文件：8 个 FB + 7 个 Types）。所有模块遵循统一模式，生成时请严格参照模板。

## 前置要求

必须先读取以下参考文档：
- `.claude/MDs/fb-module-template.md` — 功能块模块完整模板
- `.claude/MDs/types-template.md` — 类型定义模板
- `.claude/MDs/naming-conventions.md` — 命名和注释规范
- `.claude/MDs/architecture.md` — 架构和目录结构

## 通用规则（所有模块必须遵守）

1. 状态机使用 `CASE eState OF`，每个状态有完整分支
2. 内部使用 TON (PT:=T#100MS) 进行时间累计
3. 使用内部 FB_HydAxis 实例处理轴层命令
4. 硬编码轴配置：stAxisConfigLocal（仅 nAxisID 各模块不同，其余字段全部相同）
5. 输出 Busy/Done/Alarm/dwAlarmID/uiActHint/uiActTime + 到位状态
6. 调试段回退逻辑：检查 3 个字段 (uiPres<>0 OR uiSpd<>0 OR udiPos<>0)
7. 头注释包含「功能」和「说明」两段
8. 每行必须有行尾注释

## 轴 ID 分配

| 模块 | nAxisID |
|------|---------|
| FB_Clamp | 1 |
| FB_MoldAdjust | 2 |
| FB_Inject | 3 |
| FB_Nozzle | 4 |
| FB_Meter | 5 |
| FB_Eject | 6 |
| FB_Core | 7 |

## 轴配置公共常量（所有模块相同，仅 nAxisID 不同）

```
rMaxCylinderStroke := 10000.0,
rMaxVelocity := 1000.0,
rMaxPressure := 1000.0,
rPosTolerance := 0.5,
rVelTolerance := 0.5,
rPresTolerance := 0.5
```

## 各模块详细规格

### FB_Clamp（合模/开模）→ `Code/合模系统/锁模/`

**状态机**: Idle → Init → OpenUnload（开模泄压）/ CloseUnload（合模泄压）→ Opening（5段）/ Closing（3段）→ Opened / Closed → Error

**模式号**:
- 0: 停止
- 1: 自动开模（多段开模）
- 2: 自动合模（低压保护+高压锁模）
- 3: 开模调试
- 4: 合模调试

**关键特性**:
- 低压合模保护（模式2的合模阶段检测压力突变，触发低压超时报警）
- 高压锁模（合模到位后切换高压保持）
- 开模分段控制 5 段
- 合模分段控制 3 段

**到位状态**: bMoldClosed, bMoldOpened

**ClampTypes.st** 内容：
- E_ClampState 枚举（含 OpenUnload/CloseUnload/Opening/Closing/Opened/Closed）
- ST_ClampSeg（uiPres/uiSpd/udiPos/uiTime/uiPresGrad/uiSpdGrad）
- ST_ClampPara 包含：
  - 开模参数组：uiOpenSegCnt, uiOpenMode, uiOpenLimitTime, aOpenSeg[1..5], 开模渐进参数
  - 合模参数组：uiCloseSegCnt, uiCloseMode, uiCloseLimitTime, aCloseSeg[1..3], 合模渐进参数
  - 低压保护参数：uiLowPresProtectTime, uiLowPresProtectPres
  - 高压锁模参数：uiHighPresClampTime, uiHighPresClampPres
  - 开模调试段 stOpenDbgSeg
  - 合模调试段 stCloseDbgSeg
  - **6 个中子相关数组** aCoreFn[1..8], aCoreInMode[1..8], aCoreInStroke[1..8], aCoreOutMode[1..8], aCoreOutStroke[1..8], aCoreAllowTime[1..8]

### FB_MoldAdjust（调模进/退）→ `Code/合模系统/调模/`

**状态机**: Idle → Init → MoldAdjustIning/MoldAdjustOuting → MoldAdjustIned/MoldAdjustOuted → Error

**模式号**: 0=停止, 1=自动调模进, 2=自动调模退, 3=手动调模进, 4=手动调模退

**到位状态**: bMoldAdjustIned, bMoldAdjustOuted

**MoldAdjustTypes.st**: E_MoldAdjustState, ST_MoldAdjustSeg(uiPres/uiSpd/uiTime), ST_MoldAdjustPara（进退各一组，每组1段+渐进参数+调试段）

### FB_Inject（射出+保压+射退）→ `Code/注射系统/射胶/`

**状态机**: Idle → Init → Injecting → Injected → Holding → Held → SuckBacking → SuckBacked → Error

**模式号**: 0=停止, 1=自动射出, 2=自动射退, 3=射出调试, 4=射退调试

**关键特性**:
- 多段射出（最多 10 段）
- 多段保压（最多 8 段）
- V/P 转换（时间/压力/位置三种判定模式，由 dwInjToHoldMode 控制）
- 射退控制

**到位状态**: bInjected, bHeld, bSuckBacked

**InjectTypes.st**: E_InjectState, ST_InjectSeg(uiPres/uiSpd/udiPos/uiTime/uiPresGrad/uiSpdGrad), ST_HoldSeg(uiPres/uiSpd/uiTime), ST_InjectPara（含射出10段+保压8段+射退1段+全部渐进+调试段）

### FB_Nozzle（座进/座退）→ `Code/注射系统/座台/`

**状态机**: Idle → Init → NozzleIning/NozzleOuting → NozzleIned/NozzleOuted → Error

**模式号**: 0=停止, 1=自动座进, 2=自动座退, 3=座进调试, 4=座退调试

**到位状态**: bNozzleIned, bNozzleOuted

**NozzleTypes.st**: E_NozzleState, ST_NozzleSeg(uiPres/uiSpd/udiPos/uiTime/uiPresGrad/uiSpdGrad), ST_NozzlePara（座进2段+座退2段+全部渐进+调试段）

### FB_Meter（储料）→ `Code/注射系统/储料/`

**状态机**: Idle → Init → Metering → Metered → Error

**模式号**: 0=停止, 1=自动储料（单向，bDir:=TRUE 固定）

**到位状态**: bMetered

**MeterTypes.st**: E_MeterState, ST_MeterSeg(uiSPres/uiBackPres/uiSpd/udiPos/uiPresGrad/uiSpdGrad), ST_MeterPara（储料8段+全部渐进，无调试段）

### FB_Eject（基础托模进/退）→ `Code/顶出系统/托模/`

**状态机**: Idle → Init → EjectIning/EjectOuting/EjectKeeping → EjectIned/EjectOuted → Error

**模式号**: 0=停止, 1=自动托模进, 2=自动托模退, 6=手动托模进, 7=手动托模退

**到位状态**: bEjectIned, bEjectOuted

**EjectTypes.st**: E_EjectState, ST_EjectSeg(uiPres/uiSpd/udiPos/uiTime/uiPresGrad/uiSpdGrad), ST_EjectPara（托模进3段+托模退3段+停留参数+全部渐进+调试段+组合模式参数 uiEjectMode/uiEjectTimes/bEjectVibrate）

### FB_EjectMode（组合托模）→ `Code/顶出系统/托模/`

复用 FB_Eject 实现组合托模模式：
- 定次模式：循环进退 N 次
- 震动模式：小幅进退震动
- 停留模式：托模进后保持一段时间再退

无独立 Types 文件（复用 EjectTypes.st）。

### FB_Core（中子进/退）→ `Code/顶出系统/中子/`

**状态机**: Idle → Init → CoreIning/CoreOuting → CoreIned/CoreOuted → Error

**模式号**: 0=停止, 1=自动中子进, 2=自动中子退, 3=手动中子进, 4=手动中子退

**停止模式**: 时间停止 / 停止信号停止 / 计数停止（由 uiCoreInStopMode/uiCoreOutStopMode 控制）

**到位状态**: bCoreIned, bCoreOuted

**注意**: FB_Core 的调试段回退逻辑只检查 2 个字段 (uiPres<>0 AND uiSpd<>0)，与其他模块的 3 字段检查不一致。

**CoreTypes.st**: E_CoreState, ST_CoreSeg(uiPres/uiSpd/uiTime/uiCount), ST_CorePara（进退各一组+启动模式/行程/位置/停止模式+渐进+调试段）

## 输出文件清单

1. `Code/合模系统/锁模/FB_Clamp.st`
2. `Code/合模系统/锁模/ClampTypes.st`
3. `Code/合模系统/调模/FB_MoldAdjust.st`
4. `Code/合模系统/调模/MoldAdjustTypes.st`
5. `Code/注射系统/射胶/FB_Inject.st`
6. `Code/注射系统/射胶/InjectTypes.st`
7. `Code/注射系统/座台/FB_Nozzle.st`
8. `Code/注射系统/座台/NozzleTypes.st`
9. `Code/注射系统/储料/FB_Meter.st`
10. `Code/注射系统/储料/MeterTypes.st`
11. `Code/顶出系统/托模/FB_Eject.st`
12. `Code/顶出系统/托模/FB_EjectMode.st`
13. `Code/顶出系统/托模/EjectTypes.st`
14. `Code/顶出系统/中子/FB_Core.st`
15. `Code/顶出系统/中子/CoreTypes.st`
