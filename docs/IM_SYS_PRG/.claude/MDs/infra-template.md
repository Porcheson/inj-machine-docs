# 基础设施模板（轴/温控/模式/全局变量/实例）

## FB_HydAxis（统一液压轴）

### 功能
- 统一液压轴抽象层，负责位置/速度/压力限幅保护
- 报警叠加（模块报警 + 轴层报警）
- 100ms 时间脉冲累计用于动作时长和超时保护

### 接口结构
```
FUNCTION_BLOCK FB_HydAxis
VAR_INPUT
    bEnable: BOOL;                   // 轴使能
    bEStop: BOOL;                    // 急停
    bStop: BOOL;                     // 停止
    stAxisConfig: ST_HydAxisConfig;  // 轴配置（能力边界+容差）
END_VAR
VAR_IN_OUT
    stAxisCmd: ST_AxisRefHyd;        // 轴命令（输入目标值+输出实际值）
END_VAR
```

### 核心处理逻辑
1. 模块报警继承 → 叠加到轴层报警
2. Enable/EStop/Stop 优先级链（EStop 最高）
3. 目标值限幅到 Max 范围
4. 到位判断（位置/速度/压力分别对容差）
5. 100ms 脉冲计时器驱动 uiActTime 累加
6. 泵请求整理

## FB_EK312（温控器）

### 双模设计
- **仿真模式**：内部模拟 12 路温度按 100ms 拍递增/递减
- **真实模式**：保留接口不变，替换内部驱动实现
- 支持 4 组人工加热命令 R0~R3
- 100ms 温控拍驱动

### 接口结构
```
FUNCTION_BLOCK FB_EK312
VAR_INPUT
    bTempStart: BOOL;                // 温控启动
    stTempPara: ST_EK312Para;        // 12路温度设定参数
    bR0..bR3: BOOL;                  // 人工加热组命令
END_VAR
VAR_OUTPUT
    stTempStatus: ST_EK312Status;    // 12路温度当前值+状态
END_VAR
```

## FB_AutoCycle（自动周期调度器）

### 状态机流程
```
Idle → Init → ClampClose → [NozzleIn] → [Inject] → PreCool 
→ [PreSuckBack] → [Meter] → [PostSuckBack] → PostCool 
→ [NozzleOut] → ClampOpen → [EjectIn] → [EjectOut] → CycleEnd
```

`[...]` 表示可由工艺使能位跳过的步骤。

### 关键设计
- 每个步骤先设 bBusy/bAlarm 状态
- 步骤切换条件：到位检测 OR 模块 Done
- 全自动模式 (uiAutoMode=2)：CycleEnd 后自动回到 ClampClose
- 半自动模式 (uiAutoMode=1)：CycleEnd 后等待 bStart 释放再重新触发
- 支持 uiAutoStopCount 自动停机计数

## AutoCycleTypes.st

```
TYPE E_AutoCycleState :
(
    eState_Idle, eState_Init, eState_ClampClose, eState_NozzleIn,
    eState_Inject, eState_PreCool, eState_PreSuckBack, eState_Meter,
    eState_PostSuckBack, eState_PostCool, eState_NozzleOut,
    eState_ClampOpen, eState_EjectIn, eState_EjectOut,
    eState_CycleEnd, eState_Error
);
END_TYPE

TYPE ST_AutoCyclePara :
STRUCT
    bUseNozzle: BOOL;
    bUseInject: BOOL;
    bUsePreSuckBack: BOOL;
    bUseMeter: BOOL;
    bUsePostSuckBack: BOOL;
    bUseEject: BOOL;
    uiPreCoolTime: UINT;
    uiPostCoolTime: UINT;
    uiAutoStopCount: UINT;
END_STRUCT
END_TYPE
```

## GlobalVars.st（全局变量统一收口）

```
// 全局变量采用 gvl_ 前缀
VAR_GLOBAL
    gvl_stPLCIO: ST_PLCIO;
    gvl_stModbus: ST_Modbus;
    gvl_stPara: ST_MachinePara;
    gvl_stHMIPara: ST_HMIProcessPara;
    gvl_stHMIParaCommand: ST_HMIParaCommand;
    gvl_stHMIParaStatus: ST_HMIParaStatus;
    gvl_stCommand: ST_MachineCommand;
    gvl_stPLCDigitalCommandSource: ST_MachineCommand;
    gvl_stPanelCommandSource: ST_MachineCommand;
    gvl_stSensor: ST_MachineSensor;
    gvl_stStatus: ST_MachineStatus;
    gvl_stPanelIO: ST_PanelIO;
    gvl_stPanelButtons: ST_PanelButtons;
    gvl_ePanelModel: E_PanelModel;
    gvl_aCoreAllow: ARRAY[1..8] OF BOOL;     // 8路中子互锁结果
    gvl_stTempOutPara: ST_EK312OutPara;
    gvl_stClampAxisMirror: ST_AxisRefHyd;     // 合模轴镜像
    gvl_stInjectAxisMirror: ST_AxisRefHyd;     // 射胶轴镜像
    gvl_stNozzleAxisMirror: ST_AxisRefHyd;     // 座台轴镜像
    gvl_stMeterAxisMirror: ST_AxisRefHyd;      // 储料轴镜像
    gvl_stEjectAxisMirror: ST_AxisRefHyd;      // 托模轴镜像
    gvl_stCoreAxisMirror: ST_AxisRefHyd;       // 中子轴镜像
    gvl_stMoldAdjustAxisMirror: ST_AxisRefHyd;  // 调模轴镜像
END_VAR
```

## Instances.st（全部顶层 FB 实例化）

```
VAR_GLOBAL
    fbPLCDigitalInputBinder: FB_PLCDigitalInputBinder;
    fbPLCMachineInputMapper: FB_PLCMachineInputMapper;
    fbModbus: FB_Modbus;
    fbHMIParaInterface: FB_HMIParaInterface;
    fbPanelDispatcher: FB_PanelDispatcher;
    fbCommandArbiter: FB_CommandArbiter;
    fbMachineController: FB_MachineController;
    fbPLCMachineOutputMapper: FB_PLCMachineOutputMapper;
    fbPLCDigitalOutputBinder: FB_PLCDigitalOutputBinder;
    fbEK312: FB_EK312;
END_VAR
```

## EK312Types.st（温控类型）

12 路温度，每路包含：
- 设定值 (uiSetTemp)
- 当前值 (uiActualTemp)  
- PID 参数 (uiP, uiI, uiD)
- 加热/冷却输出状态
- 报警上下限
- 4 组人工加热 R0~R3 的组分配

```
TYPE ST_EK312ZonePara :
STRUCT
    uiSetTemp: UINT;
    uiAlarmHigh: UINT;
    uiAlarmLow: UINT;
    uiP: UINT;
    uiI: UINT;
    uiD: UINT;
END_STRUCT
END_TYPE

TYPE ST_EK312Para :
STRUCT
    aZone: ARRAY[1..12] OF ST_EK312ZonePara;
END_STRUCT
END_TYPE
```

## ClampTypes.st 中的中子参数耦合

当前 `ST_ClampPara` 中包含 6 个中子相关数组（每个数组 1..8）：
```
aCoreFn[1..8]: BOOL;        // 中子功能启用
aCoreInMode[1..8]: UINT;     // 中子进模式
aCoreInStroke[1..8]: UINT;   // 中子进行程
aCoreOutMode[1..8]: UINT;    // 中子退模式
aCoreOutStroke[1..8]: UINT;  // 中子退行程
aCoreAllowTime[1..8]: UINT;  // 中子允许时间
```

这是架构上的耦合问题——中子参数应从合模类型解耦，但当前实现中这些字段就在 ClampTypes.st 中。
