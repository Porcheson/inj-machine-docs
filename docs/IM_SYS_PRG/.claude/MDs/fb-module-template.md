# 功能块模块模板

## 执行模块（FB_Clamp / FB_Inject / FB_Nozzle / FB_MoldAdjust / FB_Meter / FB_Eject / FB_Core）

每个执行模块遵循完全相同的结构范式：

### 1. 文件头注释

```
(* 
  {FB_Name} 功能块
  功能：
  1. {功能点1 —— 描述该模块负责什么工艺动作}
  2. {功能点2 —— 描述内部状态机怎么流转}
  3. 对外提供 Busy / Done / Alarm / 动作提示 / 到位状态 / 工艺命令输出。

  说明：
  1. {设计决策1 —— 为什么这样设计}
  2. {维护要点 —— 新增段/扩展时需要注意什么}
*)
```

### 2. VAR_INPUT 区（标准输入信号）

```
FUNCTION_BLOCK {FB_Name}
VAR_INPUT
    (* 启动停止信号 *)
    bStart: BOOL;              // TRUE=启动命令（上升沿有效或电平有效）
    bStop: BOOL;               // TRUE=模块级停止
    bEStop: BOOL;              // TRUE=急停，强制压停全部输出
    bReset: BOOL;              // TRUE=复位，回到空闲态并清空报警

    (* 模式号 *)
    uiMode: UINT;              // 0=空闲 1=自动 2=自动方向2 3=手动进/开 4=手动退/合 6=托模进 7=托模退

    (* 工艺参数。 *)
    stPara: ST_{Module}Para;   // 从 HMI 在线参数来的该模块工艺参数

    (* 液压就绪与安全。 *)
    bHydReady: BOOL;           // TRUE=液压站就绪，允许泄压输出
    bSafetyDoorClosed: BOOL;   // TRUE=安全门关闭，允许开合模高压动作

    (* 传感器反馈。 *)
    stSensor: ST_MachineSensor; // 机器传感器结构，从中取该模块需要的行程开关/电子尺
END_VAR
```

### 3. VAR_OUTPUT 区（标准输出信号）

```
VAR_OUTPUT
    (* 模块状态。 *)
    bBusy: BOOL;               // TRUE=当前模块正在执行动作
    bDone: BOOL;               // TRUE=当前模块已完成本轮动作
    bAlarm: BOOL;              // TRUE=当前模块报警
    dwAlarmID: DWORD;          // 当前模块报警码（位掩码）
    uiActHint: UINT;           // 当前动作提示号（供 HMI 显示和输出映射使用）
    uiActTime: UINT;           // 当前动作持续时长，单位 s

    (* 到位状态。 *)
    b{In}ed: BOOL;             // 前进到位（如 bMoldClosed / bNozzleIned / bInjected）
    b{Out}ed: BOOL;            // 后退到位（如 bMoldOpened / bNozzleOuted / bSuckBacked）
    ...                         // 根据模块实际的到位信号

    (* 工艺输出命令 —— 发给轴层的目标值。 *)
    rSetPosition: LREAL;        // 当前拍目标位置
    rSetVelocity: LREAL;        // 当前拍目标速度
    rSetPressure: LREAL;        // 当前拍目标压力
END_VAR
```

### 4. VAR 区（内部变量）

```
VAR
    eState: E_{Module}State := eState_Idle;  // 状态机当前状态
    ePrevState: E_{Module}State := eState_Idle; // 上一拍状态（用于检测状态进入）
    tPulse: TON;                              // 100ms 计时脉冲
    uiSegIndex: UINT := 0;                    // 当前段号
    stAxisConfigLocal: ST_HydAxisConfig := (  // 本地轴配置（nAxisID 不同，其余相同）
        nAxisID := {N},                        // 当前模块对应的轴号
        rMaxCylinderStroke := 10000.0,
        rMaxVelocity := 1000.0,
        rMaxPressure := 1000.0,
        rPosTolerance := 0.5,
        rVelTolerance := 0.5,
        rPresTolerance := 0.5
    );
    
    stAxisCmd: ST_AxisRefHyd;                 // 当前拍发给轴层的命令结构
    fbHydAxis: FB_HydAxis;                    // 内部液压轴实例
END_VAR
```

### 5. 状态机结构（CASE eState OF）

```
(* 每拍先把模块工艺输出命令清零，避免上一状态残留命令。 *)
rSetPosition := LREAL#0.0;
rSetVelocity := LREAL#0.0;
rSetPressure := LREAL#0.0;

(* 时间脉冲用于时间限幅和动作时长的统一计时。 *)
tPulse(IN := FALSE, PT := T#100MS);

IF bReset OR bEStop OR bStop THEN
    (* 复位/急停/停止的优先级处理链 *)
    ...
ELSE
    CASE eState OF
        eState_Idle:
            ...
        eState_Init:
            ...
        eState_{Action}ing:    // 动作执行中（如 Injecting / Metering / NozzleIning）
            ...
        eState_{Action}ed:     // 动作完成（如 Injected / Metered / NozzleIned）
            ...
        eState_Error:
            ...
    END_CASE;
END_IF;

(* 统一把本拍命令写入液压轴。 *)
fbHydAxis(
    bEnable := ...,
    bEStop := ...,
    bStop := ...,
    stAxisConfig := stAxisConfigLocal,
    stAxisCmd := stAxisCmd,
    ...
);
```

### 6. 调试段回退逻辑

每个模块在进入动作前检查调试段是否已配置：

```
IF (stPara.stDbgSeg.uiPres <> 0) OR (stPara.stDbgSeg.uiSpd <> 0) OR (stPara.stDbgSeg.udiPos <> 0) THEN
    (* 调试段已配置，使用调试参数 *)
    stTargetSeg := stPara.stDbgSeg;
ELSE
    (* 调试段未配置，回退到正式第一段 *)
    stTargetSeg := stPara.aSeg[1];
END_IF;
```

注意：部分模块（如 FB_Core）只检查 `uiPres <> 0 AND uiSpd <> 0` 两个字段，存在逻辑不一致。

### 7. 模式路由约定

```
CASE uiMode OF
    0:  // 停止，回到 Idle
    1:  // 自动正向（如自动合模）
    2:  // 自动反向（如自动开模）
    3:  // 手动正向调试（如开模调试）
    4:  // 手动反向调试（如合模调试）
    6:  // 手动托模进调试（仅 Eject）
    7:  // 手动托模退调试（仅 Eject）
END_CASE;
```

## 辅助功能块

### FB_ManualMode（手动模式透传器）
- 当手动模式激活时，直接透传 HMI 命令
- 手动模式失效/停机/急停/复位时，全部输出清零
- 不做工艺步骤保存，不驱动轴

### FB_MoldAdjustMode（调模模式约束器）
- 将锁模命令强制限制在调试方向（模式号 3/4）
- 透传调模模块命令

### FB_MachineModeResolver（模式解析器）
- 从最终命令源中解析当前机器模式号
- 检测模式变更，生成全局停止信号
