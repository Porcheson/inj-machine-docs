# 注塑机 PLC 代码命名与注释规范

## 文件命名

| 前缀 | 类型 | 示例 |
|------|------|------|
| `PRG_` | 主程序入口 (PROGRAM) | `PRG_MainControl.st` |
| `FB_` | 功能块 (FUNCTION_BLOCK) | `FB_Clamp.st`, `FB_HydAxis.st` |
| `F_` | 函数 (FUNCTION) | `F_PanelGetBit.st`, `F_PanelReadKeyByOrder.st` |
| `*Types.st` | 类型定义集合 | `MachineControlTypes.st`, `PanelTypes.st` |
| `*Vars.st` | 全局变量 | `GlobalVars.st` |
| `*Instances.st` | 实例管理 | `Instances.st` |

## 类型命名

| 前缀 | 类型 | 示例 |
|------|------|------|
| `E_` | 枚举 (ENUM) | `E_PanelModel`, `E_ClampState`, `E_AxisState` |
| `ST_` | 结构体 (STRUCT) | `ST_MachineCommand`, `ST_PanelButtons`, `ST_AxisRefHyd` |
| `eState_` | 状态枚举值 | `eState_Idle`, `eState_ClampClose` |
| `ePanel_` | 面板枚举值 | `ePanel_None`, `ePanel_MK2030` |
| `ePanelButton_` | 按钮枚举值 | `ePanelButton_Manual`, `ePanelButton_Count` |

## 变量命名（匈牙利前缀）

| 前缀 | 类型 | 示例 |
|------|------|------|
| `b` | BOOL | `bStart`, `bBusy`, `bDone`, `bAlarm` |
| `ui` | UINT | `uiClampMode`, `uiActHint`, `uiActTime` |
| `udi` | UDINT | `udiElapsedMs`, `udiInjToHoldPos` |
| `dw` | DWORD | `dwAlarmID`, `dwInjToHoldMode` |
| `r` | LREAL | `rMaxVelocity`, `rSetPosition` |
| `n` | INT | `nAxisID`, `nFaultCode` |
| `st` | STRUCT | `stStatus`, `stPanelButtons` |
| `a` | ARRAY | `aButton`, `aCoreFn`, `aInjSeg` |
| `e` | ENUM | `eAxisState`, `ePanelModel` |
| `fb` | FB实例 | `fbMK110`, `fbPanelReader` |
| `gvl_` | 全局变量 | `gvl_stPara`, `gvl_stCommand` |
| `t` | TON/定时器 | `tPulse` |

## 注释模板

### 文件头注释（每个 .st 文件必须以 `(*` 开头）
```
(* 
  {文件名} {类型}
  功能：
  1. {功能点1}
  2. {功能点2}
  ...

  说明：
  1. {说明点1}
  2. {说明点2}
  ...
*)
```

### 结构体成员注释（行尾 `// `）
```
    bActive: BOOL;               // TRUE=该轴在当前模块、本扫描周期内参与机器控制。
    uiPanelOrder: UINT;          // 当前逻辑键在当前面板型号中的统一排序号；`0` 表示当前型号不提供该键位。
```

### 代码行注释（行尾 `// `）
```
    bClampStart := FALSE;          // 每拍默认清空合模手动启动位，只在当前按键有效时重新拉起。
    FOR uiButtonIndex := UINT#0 TO (TO_UINT(ePanelButton_Count) - UINT#1) DO
```

### 段注释（多行 `(* ... *)`）
```
    (* 先把全部按钮排序号清零。
       这样一来，新增全局按钮后，MK2030 若暂不支持该键位，则无需再额外补写。
    *)
```

### 分支注释
```
    IF bReset THEN
        (* 复位时统一回到空闲态 *)
    ELSIF bEStop THEN
        (* 急停直接切入故障态 *)
    ELSIF uiBitIndex > 15 THEN
        (* 位索引越界时保持原字不变 *)
    END_IF;
```

## 代码格式规则

1. **对齐**：变量声明区中，类型和注释各自对齐到固定列
2. **缩进**：4 空格
3. **空行**：VAR 区之间一个空行，逻辑段之间一个空行
4. **每行一个语句**：禁止在同一行写多个赋值
5. **行尾注释必须存在**：每一行有副作用的代码必须有行尾注释
6. **枚举值分隔符**：最后一个枚举值后面不加逗号（IEC 61131-3 兼容）
