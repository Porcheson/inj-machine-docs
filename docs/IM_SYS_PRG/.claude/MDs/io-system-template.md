# IO 管理 / Modbus / HMI 系统模板

## IO 管理层架构

```
IN[0..47] 原始硬件输入
    ↓
FB_PLCDigitalInputBinder (IN[x] → X0..X47 绑定，48 个硬编码行)
    ↓
FB_PLCMachineInputMapper (X* 语义 → ST_MachineSensor + 数字量命令源)
    ↓
[全局 stSensor / stPLCDigitalCommandSource]
    ↓
... 业务逻辑处理 ...
    ↓
[全局 stCommand / stStatus]
    ↓
FB_PLCMachineOutputMapper (命令+状态 → Y0..Y57 语义输出，通过 uiActHint 判定)
    ↓
FB_PLCDigitalOutputBinder (Y0..Y57 → OUT[0..47] 绑定，48 个硬编码行)
    ↓
OUT[0..47] 原始硬件输出
```

## FB_PLCDigitalInputBinder 结构

48 行硬编码绑定（每个输入点一行）：
```
gvl_stPLCIO.X0 := IN[0];   // ...
gvl_stPLCIO.X1 := IN[1];   // ...
...
gvl_stPLCIO.X47 := IN[47]; // ...
```

## FB_PLCMachineInputMapper 结构

将原始 X* 位映射为语义含义，示例：
```
// 安全门
stSensor.bSafetyDoorClosed := stPLCIO.X0;

// 合模到位 / 开模到位
stSensor.bClampClosed := stPLCIO.X1 OR stPLCIO.X2;   // 双开关冗余
stSensor.bClampOpened := stPLCIO.X3 OR stPLCIO.X4;

// 射出电子尺 / 压力尺
stSensor.udiInjectPosition := udiInjectElecRulerVal;
stSensor.rInjectPressure := rInjectPressureVal;

// 急停
stPLCDigitalCommandSource.bEStop := stPLCIO.X56 OR stPLCIO.X57;   // 双通道急停
```

## FB_PLCMachineOutputMapper 结构

通过动作提示号 (uiActHint) 判定输出 Y* 位，核心映射逻辑：
```
// 合模阀方向
IF stStatus.uiActHint IN [18] THEN Y8 := TRUE;   // 泄压
IF stStatus.uiActHint IN [40,84,85,86] THEN Y9 := TRUE;  // 开模方向
IF stStatus.uiActHint IN [30,31,41,81,82,83] THEN Y10 := TRUE; // 合模方向

// 托模方向
IF stStatus.uiActHint = 92 THEN    // Hint 92 需额外判断
    Y18 := NOT bEjectDirLatch;
    Y19 := bEjectDirLatch;
END_IF;

// 暂未实现的外围功能 —— 显式清零
Y13 := FALSE;  // 倒带
Y15 := FALSE;  // 拉带
Y24 := FALSE;  // 拉带退
Y25 := FALSE;  // 拉带进
Y26 := FALSE;  // 吹气
Y27 := FALSE;  // 吹气A
```

## FB_PLCDigitalOutputBinder 结构

48 行硬编码绑定：
```
OUT[0] := gvl_stPLCIO.Y0;
OUT[1] := gvl_stPLCIO.Y1;
...
OUT[47] := gvl_stPLCIO.Y47;
```

## PLCIOTypes.st 结构

```
TYPE ST_PLCIO :
STRUCT
    X0..X57: BOOL;  // 输入点，对应 IN[0..57]
    Y0..Y57: BOOL;  // 输出点，对应 OUT[0..57]
END_STRUCT
END_TYPE
```

## Modbus 通讯

### FB_Modbus 结构

双向绑定，分输入和输出两个阶段：
```
FUNCTION_BLOCK FB_Modbus
VAR_IN_OUT
    stModbus: ST_Modbus;
    stPanelIO: ST_PanelIO;
    stHMIPara: ST_HMIProcessPara;
    ...
END_VAR
// InputBind 阶段：Modbus 寄存器 → PLC 内部数据
// OutputBind 阶段：PLC 内部数据 → Modbus 寄存器
```

### ModbusTypes.st 结构

```
TYPE ST_Modbus :
STRUCT
    stPanelInput: ST_PanelIO;      // 面板输入镜像
    stPanelOutput: ST_PanelIO;     // 面板输出镜像
    stHMIInput: ST_HMIProcessPara;  // HMI 输入镜像
    stHMIOutput: ST_HMIProcessPara; // HMI 输出镜像
END_STRUCT
END_TYPE
```

## HMI 参数接口

### FB_HMIParaInterface 核心设计

实现了机器在线参数与 HMI 编辑缓冲区的彻底解耦：

1. **读回**：机器在线参数 → HMI 显示缓冲区（持续同步）
2. **编辑**：HMI 只能修改编辑缓冲区
3. **应用**：经上升沿检测 + 机器忙碌互锁后才写入在线参数
4. **状态反馈**：读回标志、脏标记、同步计数

```
FUNCTION_BLOCK FB_HMIParaInterface
VAR_IN_OUT
    stOnlinePara: ST_MachinePara;    // 机器在线参数
    stEditBuffer: ST_HMIProcessPara; // HMI 编辑缓冲区
    stCommand: ST_HMIParaCommand;     // HMI 参数命令
    stStatus: ST_HMIParaStatus;       // HMI 参数状态
END_VAR
```

### 参数安全机制

```
// "应用到机器" 命令处理
IF stCommand.bApplyToMachine THEN
    IF NOT bMachineBusy THEN         // 机器忙碌时禁止写入
        stOnlinePara := stEditBuffer; // 从编辑缓冲区复制到在线参数
        stStatus.bDirty := FALSE;
        stStatus.uiSyncCount := stStatus.uiSyncCount + 1;
    END_IF;
END_IF;
```
