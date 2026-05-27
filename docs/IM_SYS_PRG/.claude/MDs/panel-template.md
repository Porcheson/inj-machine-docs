# 面板管理系统模板

## 架构设计

面板管理采用"型号块 + 公用层"分离设计：

```
E_PanelModel (型号选择)
    ↓
FB_PanelDispatcher (调度器)
    ├── FB_MK{xxx} (型号块 —— 仅维护排序号映射)
    ├── FB_PanelReader (公用读键器 —— 按排序号回写全部按键值)
    ├── 按键→命令路由 (手动点动键 → stCommandSource.stManual)
    ├── 状态→灯请求 (机器状态 → stPanelButtons.aButton[*].bLamp)
    └── FB_PanelLampEncoder (公用灯编码器 —— 按排序号编码输出字)
```

## 型号块模板 (FB_MKxxx.st)

每个型号块结构完全相同，仅排序号不同：

```
(* 
  FB_MK{xxx} 功能块
  功能：
  1. 只维护 MK{xxx} 面板的逻辑排序号定义。
  2. 当前块不再直接读键或写灯，读键与写灯统一交给面板公用层处理。
  3. 当 MK{xxx} 面板键位顺序调整时，只需要修改本块中的排序号定义。
  4. 当前块会先把全部按钮排序号清零，再只写 MK{xxx} 实际提供的键位；因此新增全局按钮时，若 MK{xxx} 不支持该键位，则本块通常不需要改动。
*)
FUNCTION_BLOCK FB_MK{xxx}
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // MK{xxx} 面板综合按键结构；本块只负责写入 MK{xxx} 的逻辑排序号。
END_VAR
VAR
    uiButtonIndex: UINT := 0;            // 通用按钮索引；用于先把全部按钮排序号统一清零。
END_VAR

(* 先把全部按钮排序号清零。
   这样一来，新增全局按钮后，MK{xxx} 若暂不支持该键位，则无需再额外补写 `uiPanelOrder := 0`。
*)
FOR uiButtonIndex := UINT#0 TO (TO_UINT(ePanelButton_Count) - UINT#1) DO
    stPanelButtons.aButton[uiButtonIndex].uiPanelOrder := UINT#0; // 先把当前按钮索引的排序号清零，表示默认未提供该键位。
END_FOR;

(* 再只写入 MK{xxx} 实际提供的逻辑排序号。
   同一逻辑键的键值和灯值都挂在同一个 `uiPanelOrder` 上，输入与输出都按该排序号映射到 `uiIN0..uiIN3` 与 `uiOUT0..uiOUT3`。
*)
stPanelButtons.aButton[TO_UINT(ePanelButton_Manual)].uiPanelOrder := UINT#{N};             // MK{xxx} 把手动键定义为排序号 {N}。
...
END_FUNCTION_BLOCK
```

## 四种面板型号排序号对照表

| 逻辑键 | MK110 | MK116 | MK150 | MK2030 |
|--------|-------|-------|-------|--------|
| Manual | 1 | 1 | 1 | 1 |
| SemiAuto | 2 | 7 | 2 | 2 |
| FullAuto | 3 | 14 | 3 | 3 |
| Motor | 4 | 24 | 6 | 4 |
| MoldOpen | 5 | 2 | 7 | 5 |
| MoldClose | 6 | 3 | 8 | 6 |
| Metering | 7 | 4 | 9 | 7 |
| CleanMaterial | 8 | 5 | 10 | 8 |
| JetLube | 9 | 6 | 11 | 9 |
| Injection | 10 | 10 | 12 | 10 |
| SuckBack | 11 | 11 | 13 | 11 |
| ZipperBwd | 12 | 19 | 14 | 12 |
| ZipperFwd | 13 | 20 | 15 | 13 |
| LockIn | 14 | 12 | 26 | 14 |
| LockOut | 15 | 13 | 27 | 15 |
| EjectIn | 16 | 8 | 18 | 16 |
| EjectOut | 17 | 9 | 19 | 17 |
| Ejector | 18 | 15 | 20 | 18 |
| AirBlow | 19 | 16 | 21 | 19 |
| ZipperClamp | 20 | 26 | 22 | 20 |
| ZipperMotor | 21 | 27 | 23 | 21 |
| NozzleIn | 22 | 17 | 24 | 22 |
| NozzleOut | 23 | 18 | 25 | 23 |
| MoldAdjust | 24 | 21 | 4 | 24 |
| Heater | 25 | 25 | 5 | 25 |
| CoreAIn | 26 | 22 | 28 | 26 |
| CoreAOut | 27 | 23 | 29 | 27 |
| PressRise | - | - | 16 | - |
| PressFall | - | - | 17 | - |
| AirBlowA | - | - | - | - |
| AirBlowB | - | - | - | - |

注：`-` 表示该面板型号不提供此键位，排序号为 0。

## 面板调度器 (FB_PanelDispatcher) 关键逻辑

### 按键→命令路由（手动点动键）
```
开模键 → bClampStart=TRUE, uiClampMode=3 (开模调试)
合模键 → bClampStart=TRUE, uiClampMode=4 (合模调试)
调模进键 → bMoldAdjustStart=TRUE, uiMoldAdjustMode=3
调模退键 → bMoldAdjustStart=TRUE, uiMoldAdjustMode=4
座进键 → bNozzleStart=TRUE, uiNozzleMode=3
座退键 → bNozzleStart=TRUE, uiNozzleMode=4
射出键 → bInjectStart=TRUE, uiInjectMode=3
射退键 → bInjectStart=TRUE, uiInjectMode=4
储料键 → bMeterStart=TRUE (直接跟随键值)
托模进键 → bEjectStart=TRUE, uiEjectMode=6
托模退键 → bEjectStart=TRUE, uiEjectMode=7
中子A进键 → bCoreStart=TRUE, uiCoreMode=3
中子A退键 → bCoreStart=TRUE, uiCoreMode=4
```

### 模式键（上升沿锁存）
```
手动键 → uiMachineMode=1
半自动键 → uiMachineMode=2
全自动键 → uiMachineMode=3
调模键 → uiMachineMode=4
```

### 马达/电热键（上升沿翻转）
```
马达键 → bMotorStart 翻转
电热键 → bTempStart 翻转
```

### 状态→灯映射
```
手动灯 = bManualModeActive
开模灯 = bMoldOpened
合模灯 = bMoldClosed
储料灯 = bMeterBusy OR bMetered
射出灯 = 按键值 OR bInjected
射退灯 = 按键值 OR bSuckBacked
座进灯 = 按键值 OR bNozzleIned
座退灯 = 按键值 OR bNozzleOuted
托模进灯 = 按键值 OR bEjectOuted
托模退灯 = 按键值 OR bEjectIned
中子A进灯 = 按键值 OR bCoreIned
中子A退灯 = 按键值 OR bCoreOuted
调模进灯 = 按键值 OR bMoldAdjustIned
调模退灯 = 按键值 OR bMoldAdjustOuted
中子B~H灯 = FALSE (未接入)
吹气灯/润滑灯/定位灯/拉带灯 = 暂时跟随按键值
```

## 公用层函数/功能块

### F_PanelGetBit (uiValue, uiBitIndex) → BOOL
按位索引从 UINT 中读取单个位值。越界返回 FALSE。

### F_PanelSetBit (uiValue, uiBitIndex, bBitValue) → UINT
按位索引对 UINT 置位或清位。越界返回原字不变。

### F_PanelReadKeyByOrder (uiPanelOrder, uiIN0..uiIN3) → BOOL
按排序号 1..64 映射到 uiIN0..uiIN3 的对应位读取键值。排序号 0 或越界返回 FALSE。

### FB_PanelReader
循环遍历全部按钮，调用 F_PanelReadKeyByOrder 回写 bValue。

### FB_PanelLampWriter
按排序号将单个灯请求写入对应输出字（uiOUT0: bit1-16, uiOUT1: bit17-32, uiOUT2: bit33-48, uiOUT3: bit49-64）。

### FB_PanelLampEncoder
循环遍历全部按钮，调用 FB_PanelLampWriter 汇总全部灯请求到 uiOUT0..uiOUT3。
