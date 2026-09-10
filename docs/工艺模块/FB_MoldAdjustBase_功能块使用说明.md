# 《FB_MoldAdjustBase 功能块使用说明》

| 项目 | 内容 |
|---|---|
| 模块名称 | `FB_MoldAdjustBase` |
| 适用场景 | 注塑机调模进、调模退的单段工艺控制 |
| 版本信息 | 文档版本 1.1；库版本  `PlasticLibs` 1.0.26.908；更新日期 2026-09-10 |
| 依赖库信息 | `HydTechnology` 0.1.1.0，提供 `FB_HydAxis`、`ST_HydAxisRef` 等液压轴相关类型和功能块|
| 事实原则 | 以下描述以当前 ST 执行逻辑为准；注释与实际逻辑不一致时标注“需协议确认” | 

## 1. 功能概述

### 功能职责

`FB_MoldAdjustBase` 组织调模进和调模退的启动、单段执行、结束、完成及错误流程，将调模工艺参数和数字停止反馈转换为轴控制命令，并输出动作状态、完成状态和报警结果。功能块支持：

- 调模进和调模退两种动作请求；
- 每个方向一段压力、速度和时间参数；
- 按时间或对应数字停止反馈结束动作；
- 调模进、调模退独立总限时；
- 速度模式轴命令以及压力/速度斜率输出；
- 调模进完成、调模退完成、动作提示和报警代码输出。

### 输入与输出

| 调用者提供 | 功能块输出 |
|---|---|
| `bStart`、`bStop`、`bEStop`、`bReset`、`uiMoldAdjustMode` | `bBusy`、`bDone`、`bAlarm`、`dwAlarmID` |
| `stMoldAdjustPara`、`stParaRef` | `uiActHint`、`uiActTime`、`bMoldAdjustIned`、`bMoldAdjustOuted` |
| `stHydAxisRef`、调模进/退停止信号、`uiClampPresElecRulerVal` | `stHydAxisCtrl` 轴命令和轴状态包；`stHydAxisRef` 调用后回写 |

### 主要执行流程

~~~text
读取 uiMoldAdjustMode 并确定调模进/调模退请求
  -> 按优先级处理复位、急停和正常停止（含 bStart 下降沿）
  -> Idle 接收 bStart 上升沿后进入 Init
  -> Init 设置轴方向，进入调模进或调模退单段状态
  -> 按时间或对应数字停止反馈结束单段并进入方向完成状态
  -> 方向总限时、无效顶层模式或未知状态进入 Error
  -> 每次调用末尾执行轴实例，并把轴命令和轴状态转存到 stHydAxisCtrl
~~~

### 功能边界

本功能块生成调模工艺状态和轴命令，并在当前固定分支内调用内部 `FB_HydAxis`；不直接访问通信报文、全局变量、`%I/%Q` 或物理 I/O，不替代轴闭环、独立急停、安全联锁、机械限位、轴故障处理或物理能量切断。`FB_EleAxis` 分支虽然保留在 ST 中，但当前 `IF TRUE` 条件下不会执行；电动轴接入需要依据实际 POU 和轴库接口另行核对。

## 2. 自定义数据类型

### 2.1 `E_MoldAdjustState`

| 枚举成员 | 用途 |
|---|---|
| `eMoldAdjustState_Idle` | 空闲 |
| `eMoldAdjustState_Init` | 初始化 |
| `eMoldAdjustState_MoldAdjustIning` | 调模进 |
| `eMoldAdjustState_MoldAdjustIned` | 调模进完成 |
| `eMoldAdjustState_MoldAdjustOuting` | 调模退 |
| `eMoldAdjustState_MoldAdjustOuted` | 调模退完成 |
| `eMoldAdjustState_Error` | 错误 |

### 2.2 `ST_MoldAdjustSeg`

| 成员 | 类型 | 读写属性 | 用途 |
|---|---|---|---|
| `uiPres` | `UINT` | 只读 | 压力命令 |
| `uiSpd` | `UINT` | 只读 | 速度命令 |
| `uiTime` | `UINT` | 只读 | 时间阈值 |

### 2.3 `ST_MoldAdjustPara`

| 成员 | 类型 | 读写属性 | 用途 |
|---|---|---|---|
| `uiMoldAdjustInMode` | `UINT` | 只读 | 调模进方式：`0` 时间、`1` 行程 |
| `uiMoldAdjustInLimitTime` | `UINT` | 只读 | 调模进总限时；`0` 时不启用 |
| `stMoldAdjustInSeg` | `ST_MoldAdjustSeg` | 只读 | 调模进单段参数 |
| `uiMoldAdjustInPresStartGrad` | `UINT` | 只读 | 调模进压力启动斜率 |
| `uiMoldAdjustInPresStopGrad` | `UINT` | 只读 | 调模进压力停止斜率 |
| `uiMoldAdjustInSpdStartGrad` | `UINT` | 只读 | 调模进速度启动斜率 |
| `uiMoldAdjustInSpdStopGrad` | `UINT` | 只读 | 调模进速度停止斜率 |
| `uiMoldAdjustOutMode` | `UINT` | 只读 | 调模退方式：`0` 时间、`1` 行程 |
| `uiMoldAdjustOutLimitTime` | `UINT` | 只读 | 调模退总限时；`0` 时不启用 |
| `stMoldAdjustOutSeg` | `ST_MoldAdjustSeg` | 只读 | 调模退单段参数 |
| `uiMoldAdjustOutPresStartGrad` | `UINT` | 只读 | 调模退压力启动斜率 |
| `uiMoldAdjustOutPresStopGrad` | `UINT` | 只读 | 调模退压力停止斜率 |
| `uiMoldAdjustOutSpdStartGrad` | `UINT` | 只读 | 调模退速度启动斜率 |
| `uiMoldAdjustOutSpdStopGrad` | `UINT` | 只读 | 调模退速度停止斜率 |

### 2.4 `ST_ParaRef`

| 成员 | 类型 | 读写属性 | 用途 |
|---|---|---|---|
| `udiPosToleranceValue` | `UDINT` | 读写 | 位置容差值 |

### 2.5 `ST_HydAxisRef`

该类型由液压轴库定义。本功能块将 `stHydAxisRef` 传入内部 `FB_HydAxis`，调用后用轴功能块返回值回写；结构成员请查阅 HydTechnology 技术库使用说明书。

### 2.6 `ST_HydAxisCtrl`

| 成员 | 类型 | 读写属性 | 用途 |
|---|---|---|---|
| `bAxisStart` | `BOOL` | 只写 | 轴启动信号 |
| `uiAxisDir` | `UINT` | 只写 | 轴方向；调模进写 `2`，调模退写 `1` |
| `uiAxisMode` | `UINT` | 只写 | 轴控制模式：`1` 位置、`2` 速度、`3` 压力 |
| `uiPresCmd` | `UINT` | 只写 | 压力命令 |
| `uiSpdCmd` | `UINT` | 只写 | 速度命令 |
| `uiEndSpdCmd` | `UINT` | 只写 | 结束速度 |
| `udiPosCmd` | `UDINT` | 只写 | 位置命令 |
| `uiAxisPresAcc` | `UINT` | 只写 | 压力加速参数 |
| `uiAxisPresDec` | `UINT` | 只写 | 压力减速参数 |
| `uiAxisSpdAcc` | `UINT` | 只写 | 速度加速参数 |
| `uiAxisSpdDec` | `UINT` | 只写 | 速度减速参数 |
| `uiAxisJerk` | `UINT` | 只写 | 加加速度参数 |
| `bBusy` | `BOOL` | 内部轴功能块写入 | 液压轴忙状态 |
| `bDone` | `BOOL` | 内部轴功能块写入 | 液压轴完成状态 |
| `bInVelocity` | `BOOL` | 内部轴功能块写入 | 液压轴速度到位状态 |
| `bInPressure` | `BOOL` | 内部轴功能块写入 | 液压轴压力到位状态 |
| `bAlarm` | `BOOL` | 内部轴功能块写入 | 液压轴报警状态 |
| `dwAlarmID` | `DWORD` | 内部轴功能块写入 | 液压轴报警代码 |

## 3. 功能块接口

![FB_MoldAdjustBase LD 功能块接口图](image/FB_MoldAdjustBase_功能块LD.png)
![FB_MoldAdjustBase ST 调用图](image/FB_MoldAdjustBase_功能块ST.png)

### 3.1 `VAR_IN_OUT`

| 名称 | 类型 | 当前行为 | 信号含义 |
|---|---|---|---|
| `stHydAxisRef` | `ST_HydAxisRef` | 传入内部 `FB_HydAxis`，调用后回写 | 液压轴参数引用参考 |
| `stParaRef` | `ST_ParaRef` | 引用位置容差值 | 工艺参数引用参考 |

### 3.2 `VAR_INPUT`

| 名称 | 类型 | 当前行为 | 信号含义 |
|---|---|---|---|
| `bStart` | `BOOL` | 在 `Idle` 中检测上升沿后进入初始化；下降沿触发正常停止 | 启动命令 |
| `bStop` | `BOOL` | 优先级低于复位和急停；回到空闲并清主要轴命令和计时 | 正常停止 |
| `bEStop` | `BOOL` | 进入错误状态并按位加入 `16#0001` | 急停请求 |
| `bReset` | `BOOL` | 最高优先级；清状态、报警、主要轴命令和计时并回到空闲 | 复位命令 |
| `uiMoldAdjustMode` | `UINT` | `1` 调模进，`2` 调模退；其他值在 `Init` 产生无效模式报警 | 调模方向模式 |
| `stMoldAdjustPara` | `ST_MoldAdjustPara` | 按周期读取结束方式、单段参数、总限时和斜率 | 调模工艺参数 |
| `bMoldAdjustInStop` | `BOOL` | 调模进方式为 `1` 时参与调模进结束判断 | 调模进数字停止反馈 |
| `bMoldAdjustOutStop` | `BOOL` | 调模退方式为 `1` 时参与调模退结束判断 | 调模退数字停止反馈 |
| `uiClampPresElecRulerVal` | `UINT` | 声明但当前暂未使用 | 锁模压力 |

### 3.3 `VAR_OUTPUT`

| 名称 | 类型 | 当前行为 | 信号含义 |
|---|---|---|---|
| `bBusy` | `BOOL` | `bStart` 上升沿启动后置位；停止、完成、急停或错误状态清除 | 工艺忙状态 |
| `bDone` | `BOOL` | 方向完成状态中置位并保持；停止、急停、错误和复位通过 `ClearStatus()` 清除 | 工艺完成状态 |
| `bAlarm` | `BOOL` | 无效模式、急停或错误状态置位；仅复位明确清除，停止、完成和空闲不自动清除 | 工艺报警状态 |
| `dwAlarmID` | `DWORD` | 报警代码按位 OR 累积；仅复位清零，其他分支不自动清除 | 工艺报警代码 |
| `uiActHint` | `UINT` | 输出空闲、报警、调模进、调模退或对应完成提示 | 当前动作提示 |
| `uiActTime` | `UINT` | 活动阶段输出阶段累计调用值；清状态时置 `0` | 当前动作运行时间 |
| `bMoldAdjustIned` | `BOOL` | 调模进完成状态中置位；停止、急停、错误和复位清除 | 调模进完成 |
| `bMoldAdjustOuted` | `BOOL` | 调模退完成状态中置位；停止、急停、错误和复位清除 | 调模退完成 |
| `stHydAxisCtrl` | `ST_HydAxisCtrl` | 每次调用末尾转存本地轴命令和内部 `FB_HydAxis` 状态 | 轴命令和轴状态包 |

`stHydAxisCtrl.bBusy`、`bDone`、`bInVelocity`、`bInPressure`、`bAlarm` 和 `dwAlarmID` 来自内部 `FB_HydAxis`，与本功能块自身的 `bBusy`、`bDone`、`bAlarm` 和 `dwAlarmID` 分属不同层级，外部读取和汇总时不得直接互换。

## 4. 报警和状态码

### 4.1 报警代码与报警信息

| 报警代码 | 报警信息 |
|---|---|
| `16#0000` | 无报警 |
| `16#0001` | 紧急停止 |
| `16#0002` | `uiMoldAdjustMode` 参数无效 |
| `16#0004` | 调模进总限时报警 |
| `16#0008` | 调模退总限时报警 |

### 4.2 动作状态码

| `uiActHint` | 含义 |
|---:|---|
| `0` | 空闲 |
| `1` | 报警状态 |
| `2` | 调模进完成 |
| `3` | 调模退完成 |
| `11` | 调模进 |
| `21` | 调模退 |

## 5. 调用规范和注意事项

1. **固定周期调用和计时。** 在稳定、已知周期内每周期调用一次，并在调用前刷新模式、调模参数和数字停止反馈。当前工程任务周期为 `T#1ms`；代码在活动阶段每次调用将阶段计时和总计时各增加 `1`，时间结束和方向总限时都按参数值乘 `100` 次调用比较，`uiActTime` 为阶段计时转换结果，实际时间仍取决于调用周期。
2. **调用顺序和轴层边界。** 先准备 `stHydAxisRef`、`stMoldAdjustPara`、`uiMoldAdjustMode` 和停止反馈，再调用 `FB_MoldAdjustBase`，最后读取 `stHydAxisCtrl`、动作输出和回写后的 `stHydAxisRef`。当前 POU 每次调用末尾已执行内部 `FB_HydAxis`，调用者不应为同一动作重复调用外部轴功能块。
3. **模式、范围和未使用输入。** 顶层 `uiMoldAdjustMode` 只允许 `1` 调模进或 `2` 调模退；活动过程中改变该值不会切换已进入的状态。`uiMoldAdjustInMode` 和 `uiMoldAdjustOutMode` 只有 `0`（时间）和 `1`（数字停止）有实际分支，其他值没有独立报警。总限时为 `0` 时禁用；结束方式为时间且对应 `uiTime=0` 时，活动阶段第一次扫描即可满足结束条件。`stParaRef.udiPosToleranceValue`、`uiClampPresElecRulerVal` 和电子尺位置均未参与本功能块判断。
4. **启动、停止、急停与复位。** 处理优先级为 `bReset` > `bEStop` > (`bStop` 或 `bStart` 下降沿) > 状态机。`bStart` 上升沿只在 `Idle` 中启动；正常停止回到 `Idle`，清主要轴命令、阶段/总计时和两个方向完成输出，但不自动清 `bAlarm` 或 `dwAlarmID`。急停清主要状态并进入错误态、置 `16#0001`；复位清报警并回到空闲。急停输入保持有效时，复位后的下一次调用仍会重新进入急停分支。
5. **结束、清状态和限时优先级。** `ClearStatus()` 清 `bBusy`、`bDone`、`uiActHint`、`uiActTime`、阶段/总计时以及全部本地轴命令缓存；调模进/退完成分支随后分别置 `bDone`、方向完成输出和提示 `2/3`，错误分支随后置 `bAlarm` 和提示 `1`。调模进/退限时判断与结束判断是两个独立的 `IF`；若同一扫描同时满足限时和结束条件，后执行的结束赋值可能覆盖错误状态，调用者应避免把两者设为同一边界。完成或错误状态的清状态发生在进入该状态后的扫描，轴命令在状态切换当次可能仍保持上一周期缓存。
6. **轴命令、状态分层和安全边界。** 活动阶段 `bAxisStart=TRUE`、`uiAxisMode=2`；调模进写 `uiAxisDir=2`，调模退写 `uiAxisDir=1`。内部 `FB_HydAxis` 接收启动、停止（含 `bStart` 下降沿）、急停、复位、方向、模式、压力、速度、结束速度、位置、速度加减速和加加速度字段；当前调用实际把 `uiAxisSpdAcc`/`uiAxisSpdDec` 映射到 `uiAcc`/`uiDec`，未传入 `uiAxisPresAcc`/`uiAxisPresDec`。`uiEndSpdCmd`、`udiPosCmd` 和 `uiAxisJerk` 没有本 POU 的工艺赋值。`stHydAxisCtrl` 的轴层状态与工艺层状态应分层读取；本功能块不替代独立急停、安全门/光幕、调模互锁、机械限位、轴故障处理或物理能量切断。

## 6. 外部交互边界

| 方向 | 交互对象 | 数据边界 |
|---|---|---|
| 输入 | HMI、配方和上层工艺逻辑 | `uiMoldAdjustMode`、`stMoldAdjustPara`、启动/停止/急停/复位命令 |
| 输入 | 现场信号转换层 | `bMoldAdjustInStop`、`bMoldAdjustOutStop` |
| 输入 | 接口预留信号 | `stParaRef`、`uiClampPresElecRulerVal` 当前未被本功能块读取 |
| 输入/输出 | `stHydAxisRef` | 传入内部 `FB_HydAxis`，调用后回写液压轴配置和反馈结构 |
| 内部调用 | `FB_HydAxis` | 接收本功能块生成的启停/急停/复位、方向、模式、压力、速度、结束速度、位置和斜率命令，并将轴状态转存到 `stHydAxisCtrl` |
| 保留分支 | `FB_EleAxis` | 当前固定 `IF TRUE` 分支不会执行，切换电动轴前需修改并核对实际接口 |
| 输出 | HMI、诊断和报警逻辑 | `bBusy`、`bDone`、`uiActHint`、`uiActTime`、调模进/退完成状态、功能块报警及轴报警 |

当前 ST 不直接访问通信报文、全局变量、`%I/%Q` 或物理 I/O。功能块报警和轴报警是两层输出，外部逻辑应按系统报警策略分别读取并汇总。

## 7. 最小调用示例

以下示例使用通用占位符，工程师需将其替换为真实对象。上层逻辑先准备模式、调模参数和停止反馈，再调用调模功能块；轴功能块已在本功能块内部调用，示例不重复调用外部轴功能块。

### 7.1 调用调模功能块

~~~ST
(* 上层逻辑先准备 uiMoldAdjustMode、stMoldAdjustPara 和停止反馈。 *)

fbExample(
    stHydAxisRef := stHydAxisRef,
    stParaRef := stParaRef,
    bStart := bStart,
    bStop := bStop,
    bEStop := bEStop,
    bReset := bReset,
    uiMoldAdjustMode := uiMoldAdjustMode,
    stMoldAdjustPara := stMoldAdjustPara,
    bMoldAdjustInStop := bMoldAdjustInStop,
    bMoldAdjustOutStop := bMoldAdjustOutStop,
    uiClampPresElecRulerVal := uiClampPresElecRulerVal,
    bBusy => bMoldAdjustBusy,
    bDone => bMoldAdjustDone,
    bAlarm => bMoldAdjustAlarm,
    dwAlarmID => dwMoldAdjustAlarmID,
    uiActHint => uiMoldAdjustActHint,
    uiActTime => uiMoldAdjustActTime,
    bMoldAdjustIned => bMoldAdjustIned,
    bMoldAdjustOuted => bMoldAdjustOuted,
    stHydAxisCtrl => stMoldAdjustHydAxisCtrl
);

(* 工艺层报警与内部液压轴报警分层读取。 *)
bHydAxisAlarm := stMoldAdjustHydAxisCtrl.bAlarm;
dwHydAxisAlarmID := stMoldAdjustHydAxisCtrl.dwAlarmID;
~~~
