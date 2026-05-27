---
name: inj-all
description: 一键生成注塑机 PLC 控制系统的全部代码——包含主控制架构、执行模块、IO 管理、面板管理、基础设施层的所有 50+ 个 .st 源文件。调用此技能相当于依次调用 inj-arch → inj-module → inj-io → inj-panel → inj-infra。
---

# 注塑机 PLC 控制系统完整代码生成（一键全部）

调用此技能将按正确顺序依次触发所有子技能，生成完整的 CODE 文件夹全部 50+ 个 .st 源文件。

## 生成顺序

必须严格按以下顺序生成（后面的模块依赖前面的类型定义）：

### 第一阶段：基础设施类型
1. 调用 `inj-infra` 生成 AxisTypes.st, EK312Types.st, AutoCycleTypes.st
2. 调用 `inj-arch` 生成 MachineControlTypes.st（顶层类型，所有模块依赖）

### 第二阶段：各子系统类型 + 功能块
3. 调用 `inj-module` 生成全部执行模块的 Types + FB（15 个文件）
4. 调用 `inj-panel` 生成全部面板管理文件（11 个文件，含 PanelTypes.st）
5. 调用 `inj-io` 生成 IO/Modbus/HMI 文件（8 个文件，含 PLCIOTypes.st, ModbusTypes.st）

### 第三阶段：系统入口与全局
6. 继续 `inj-infra` 生成 FB_HydAxis.st, FB_EK312.st, FB_ManualMode.st, FB_MoldAdjustMode.st, FB_AutoCycle.st
7. 继续 `inj-arch` 生成 PRG_MainControl.st, FB_MachineController.st, FB_CommandArbiter.st, FB_MachineCommandComposer.st, FB_MachineModeResolver.st, FB_MachineStatusAggregator.st
8. 继续 `inj-infra` 生成 GlobalVars.st, Instances.st

## 目录结构校验

生成完成后，核对以下目录结构必须存在：

```
Code/
├── 主程序入口/        (7 文件)
├── 合模系统/锁模/     (2 文件)
├── 合模系统/调模/     (2 文件)
├── 注射系统/射胶/     (2 文件)
├── 注射系统/储料/     (2 文件)
├── 注射系统/座台/     (2 文件)
├── 顶出系统/托模/     (3 文件)
├── 顶出系统/中子/     (2 文件)
├── 模式管理/手动模式/ (1 文件)
├── 模式管理/调模模式/ (1 文件)
├── 模式管理/自动模式/ (2 文件)
├── 面板管理/面板调度/ (1 文件)
├── 面板管理/面板通用/ (7 文件)
├── 面板管理/MK110/    (1 文件)
├── 面板管理/MK116/    (1 文件)
├── 面板管理/MK150/    (1 文件)
├── 面板管理/MK2030/   (1 文件)
├── IO管理/            (1 文件)
├── IO管理/数字量输入/ (2 文件)
├── IO管理/数字量输出/ (2 文件)
├── Modbus通讯/        (2 文件)
├── HMI系统/           (1 文件)
├── 伺服系统/液压轴/   (2 文件)
├── 温度系统/EK312/    (2 文件)
├── 全局变量/          (1 文件)
└── 实例管理/          (1 文件)
```

共计 50 个 .st 文件。

## 依赖关系图

```
AxisTypes.st ← FB_HydAxis.st
            ← 所有执行模块 (通过 ST_AxisRefHyd)

MachineControlTypes.st ← FB_MachineController.st
                       ← FB_CommandArbiter.st
                       ← FB_MachineCommandComposer.st
                       ← FB_MachineModeResolver.st
                       ← FB_MachineStatusAggregator.st
                       ← FB_PLCMachineInputMapper.st
                       ← FB_PLCMachineOutputMapper.st
                       ← FB_ManualMode.st
                       ← FB_MoldAdjustMode.st
                       ← FB_AutoCycle.st
                       ← FB_HMIParaInterface.st
                       ← GlobalVars.st

ClampTypes.st ← FB_Clamp.st
InjectTypes.st ← FB_Inject.st, FB_AutoCycle.st
MeterTypes.st ← FB_Meter.st
NozzleTypes.st ← FB_Nozzle.st
MoldAdjustTypes.st ← FB_MoldAdjust.st
EjectTypes.st ← FB_Eject.st, FB_EjectMode.st
CoreTypes.st ← FB_Core.st
AutoCycleTypes.st ← FB_AutoCycle.st
EK312Types.st ← FB_EK312.st
PanelTypes.st ← 全部面板管理文件
PLCIOTypes.st ← IO管理文件
ModbusTypes.st ← FB_Modbus.st

GlobalVars.st ← PRG_MainControl.st (通过实例引用)
Instances.st ← PRG_MainControl.st (通过实例引用)
PRG_MainControl.st ← (顶层，依赖所有其他文件)
```

## 全局一致性检查

生成完成后须核对：
1. ✅ 所有模块的 nAxisID 唯一（1-7）
2. ✅ 所有轴配置的 rMax*/r*Tolerance 值统一
3. ✅ ST_PanelButtons.aButton 数组上界 = TO_UINT(ePanelButton_Count)-1
4. ✅ GlobalVars 中变量名与各模块使用的全局变量名一致
5. ✅ Instances 中实例类型与 PRG_MainControl 中调用的实例一致
6. ✅ 所有报警码 dwAlarmID 在全系统中无冲突
7. ✅ 所有 uiActHint 值在全系统中无歧义
8. ✅ E_PanelModel 枚举中 ePanel_MK150 后无逗号（保持与 PanelTypes.st 一致）
