---
name: inj-panel
description: 生成注塑机 PLC 程序的面板管理系统代码——PanelTypes 类型定义、面板调度器 FB_PanelDispatcher、公用读键/写灯层（FB_PanelReader/FB_PanelLampEncoder/FB_PanelLampWriter）、位操作函数（F_PanelGetBit/F_PanelSetBit/F_PanelReadKeyByOrder）、四个面板型号映射块（FB_MK110/FB_MK116/FB_MK150/FB_MK2030）。
---

# 面板管理系统代码生成

调用此技能将生成面板管理系统的全部 11 个文件。

## 前置要求

必须先读取以下参考文档：
- `.claude/MDs/panel-template.md` — 面板管理完整模板（含排序号对照表）
- `.claude/MDs/naming-conventions.md` — 命名和注释规范
- `.claude/MDs/architecture.md` — 架构和目录结构

## 生成文件清单

### 1. PanelTypes.st → `Code/面板管理/面板通用/`

完整定义面板管理的全部类型。

**E_PanelModel** 枚举（注意：最后一个枚举值后不加逗号）：
```
ePanel_None,
ePanel_MK110,
ePanel_MK116,
ePanel_MK150
ePanel_MK2030
```
注意：ePanel_MK150 后缺少逗号（IEC 61131-3 兼容性，部分编译器允许）。

**ST_PanelIO** 结构：uiIN0..uiIN3 + uiOUT0..uiOUT3，每个字段带行尾注释说明承载的排序号范围。

**ST_PanelButton** 结构：uiPanelOrder (UINT), bValue (BOOL), bLamp (BOOL)。

**E_PanelButtonID** 枚举（47 个按钮 ID + 1 个 Count 哨兵）：
```
ePanelButton_Manual, ePanelButton_SemiAuto, ePanelButton_FullAuto,
ePanelButton_MoldAdjust, ePanelButton_Heater, ePanelButton_Motor,
ePanelButton_MoldOpen, ePanelButton_MoldClose, ePanelButton_Metering,
ePanelButton_CleanMaterial, ePanelButton_Injection, ePanelButton_SuckBack,
ePanelButton_EjectIn, ePanelButton_EjectOut, ePanelButton_NozzleIn,
ePanelButton_NozzleOut, ePanelButton_CoreAIn..ePanelButton_CoreHOut,
ePanelButton_MoldAdjustIn, ePanelButton_MoldAdjustOut,
ePanelButton_AirBlow, ePanelButton_AirBlowA, ePanelButton_AirBlowB,
ePanelButton_JetLube, ePanelButton_Ejector,
ePanelButton_LockIn, ePanelButton_LockOut,
ePanelButton_PressRise, ePanelButton_PressFall,
ePanelButton_ZipperBwd, ePanelButton_ZipperFwd,
ePanelButton_ZipperClamp, ePanelButton_ZipperMotor,
ePanelButton_Count
```
每个枚举值带行尾注释说明对应工艺语义。

**ST_PanelButtons** 结构：aButton: ARRAY[0..46] OF ST_PanelButton（上界 = Count-1）。

### 2. F_PanelGetBit.st → `Code/面板管理/面板通用/`

函数：从 UINT 中按位索引读取单个 BOOL。
- 越界返回 FALSE
- 使用 SHR + AND 实现位读取

### 3. F_PanelSetBit.st → `Code/面板管理/面板通用/`

函数：按位索引对 UINT 做置位或清位。
- 越界返回原字不变
- 置位：uiValue OR SHL(UINT#1, uiBitIndex)
- 清位：uiValue AND NOT SHL(UINT#1, uiBitIndex)

### 4. F_PanelReadKeyByOrder.st → `Code/面板管理/面板通用/`

函数：按排序号 1..64 从 uiIN0..uiIN3 读取键值。
- 排序号 1..16 → uiIN0
- 排序号 17..32 → uiIN1
- 排序号 33..48 → uiIN2
- 排序号 49..64 → uiIN3
- 排序号 0 或越界 → FALSE

### 5. FB_PanelLampWriter.st → `Code/面板管理/面板通用/`

功能块：按排序号将单个灯请求写入对应输出字。
- 排序号 1..16 → uiOUT0
- 排序号 17..32 → uiOUT1
- 排序号 33..48 → uiOUT2
- 排序号 49..64 → uiOUT3
- bLampValue=FALSE 时不做任何写入（依赖上层在每拍开始清零输出字）

### 6. FB_PanelReader.st → `Code/面板管理/面板通用/`

功能块：循环遍历全部按钮（0..Count-1），按 stPanelButtons.aButton[i].uiPanelOrder 调用 F_PanelReadKeyByOrder 回写 bValue。

### 7. FB_PanelLampEncoder.st → `Code/面板管理/面板通用/`

功能块：循环遍历全部按钮，调用 FB_PanelLampWriter 将全部灯请求编码到 uiOUT0..uiOUT3。每拍先清零四个输出字再重新编码。

### 8. FB_PanelDispatcher.st → `Code/面板管理/面板调度/`

面板总调度器。

**调度逻辑**：
1. 根据 ePanelModel 选择对应的型号块（FB_MK110/MK116/MK150/MK2030）写入排序号定义
2. 未选择型号时（ELSE）：清零全部输出字 + 清零全部按钮排序号/键值/灯请求
3. 调用 FB_PanelReader 统一读键
4. 清零手动命令（每拍默认清空，只在按键有效时重新拉起）
5. 模式键上升沿锁存（手动/半自动/全自动/调模）
6. 马达/电热键上升沿翻转
7. 手动点动键 → stCommandSource.stManual 路由（开模/合模/调模进/调模退/座进/座退/射出/射退/储料/托模进/托模退/中子A进/中子A退）
8. 状态 → 灯请求映射（模式灯+动作灯+完成灯+临时灯）
9. 调用 FB_PanelLampEncoder 统一写灯
10. 更新上升沿缓存（bManualKeyLast 等 6 个缓存变量）

详细按键→命令路由和状态→灯映射表见 `panel-template.md`。

### 9. FB_MK110.st → `Code/面板管理/MK110/`

MK110 面板排序号定义块（28 个键位）。
结构：先循环清零全部按钮排序号，再写入 MK110 实际键位排序号。
排序号见 `panel-template.md` 中的四面板对照表。

### 10. FB_MK116.st → `Code/面板管理/MK116/`

MK116 面板排序号定义块（28 个键位）。
结构与 FB_MK110 完全一致，仅排序号不同。
排序号见 `panel-template.md` 中的四面板对照表。

### 11. FB_MK150.st → `Code/面板管理/MK150/`

MK150 面板排序号定义块（30 个键位，多 PressRise/PressFall）。
结构与 FB_MK110 完全一致，仅排序号不同。
排序号见 `panel-template.md` 中的四面板对照表。

### 12. FB_MK2030.st → `Code/面板管理/MK2030/`

MK2030 面板排序号定义块（28 个键位）。
结构与 FB_MK110 完全一致，仅排序号不同。
排序号见 `panel-template.md` 中的四面板对照表。

## 关键规则

1. PanelTypes.st 中 E_PanelModel 的 ePanel_MK150 后不加逗号
2. 所有型号块先循环清零再写入，新增按钮无需额外修改型号块
3. 面板调度器中每拍先清空手动命令，避免残留
4. 模式键和马达/电热键使用上升沿检测
5. 灯映射中未接入的模块灯固定为 FALSE（中子B~H、未实现的清料/吹气/润滑/定位等暂跟按键值）
6. ST_PanelButtons.aButton 数组上界 = TO_UINT(ePanelButton_Count) - 1
