# 类型定义模板

## 文件结构

每个 Types 文件包含三类定义：

1. **状态枚举 (E_*State)** —— 该模块的状态机状态
2. **段结构 (ST_*Seg)** —— 单个工艺段的参数
3. **工艺参数结构 (ST_*Para)** —— 该模块完整工艺参数

## 状态枚举模板

```
TYPE E_{Module}State :
(
    eState_Idle,          // 空闲
    eState_Init,          // 初始化
    eState_{Action}ing,   // {动作}执行中
    eState_{Action}ed,    // {动作}完成
    eState_{Reverse}ing,  // {反向动作}执行中（如有）
    eState_{Reverse}ed,   // {反向动作}完成（如有）
    eState_Error          // 故障
);
END_TYPE
```

## 段结构模板

```
TYPE ST_{Module}Seg :
STRUCT
    uiPres: UINT;     // 段目标压力
    uiSpd: UINT;      // 段目标速度
    udiPos: UDINT;    // 段目标位置
    uiTime: UINT;     // 段最长执行时间
    uiPresGrad: UINT; // 压力渐进值
    uiSpdGrad: UINT;  // 速度渐进值
END_STRUCT
END_TYPE
```

注意：不同模块的段结构字段略有差异：
- ST_InjectSeg 和 ST_NozzleSeg 有全部 6 个字段
- ST_MeterSeg 的 `uiSPres` 替代 `uiPres`，额外有 `uiBackPres`
- ST_MoldAdjustSeg 只有 `uiPres`, `uiSpd`, `uiTime`（无位置、无渐进）
- ST_CoreSeg 额外有 `uiCount`

## 工艺参数结构模板

```
TYPE ST_{Module}Para :
STRUCT
    (* 动作参数组（每个方向一组） *)
    ui{Action}SegCnt: UINT;                    // 段数量
    ui{Action}Mode: UINT;                      // 控制模式
    ui{Action}LimitTime: UINT;                 // 最大允许时间
    a{Action}Seg: ARRAY[1..N] OF ST_{Module}Seg; // 段参数数组
    ui{Action}PresStartGrad: UINT;             // 压力起始渐进
    ui{Action}PresStopGrad: UINT;              // 压力停止渐进
    ui{Action}SpdStartGrad: UINT;              // 速度起始渐进
    ui{Action}SpdStopGrad: UINT;               // 速度停止渐进
    
    (* 反向动作参数组 *)
    ui{Reverse}SegCnt: UINT;
    ... (同上结构)

    (* 调试段参数 *)
    st{Action}DbgSeg: ST_{Module}Seg;          // 调试段
    st{Reverse}DbgSeg: ST_{Module}Seg;         // 反向调试段
END_STRUCT
END_TYPE
```

## 各模块具体 N 值

| 模块 | 正/反向动作数 | 段数组大小 |
|------|-------------|-----------|
| Clamp | 开模5段 + 合模3段 | aOpenSeg[1..5], aCloseSeg[1..3] |
| Inject | 射出10段 + 保压8段 + 射退1段 | aInjSeg[1..10], aHoldSeg[1..8] |
| Nozzle | 座进2段 + 座退2段 | aNozzleInSeg[1..2], aNozzleOutSeg[1..2] |
| Meter | 储料8段（单向） | aMeterSeg[1..8] |
| Eject | 托模进3段 + 托模退3段 | aEjectInSeg[1..3], aEjectOutSeg[1..3] |
| Core | 中子进1段 + 中子退1段 | stCoreInSeg, stCoreOutSeg |
| MoldAdjust | 调模进1段 + 调模退1段 | stMoldAdjustInSeg, stMoldAdjustOutSeg |

## 顶层机器控制类型 (MachineControlTypes.st)

定义在所有模块之上使用的统一类型：

```
ST_MachineCommand         // 机器级命令（模式+手动+启停）
ST_MachineSensor          // 机器传感器汇总
ST_MachinePara            // 机器参数汇总（包含各子模块参数）
ST_MachineStatus          // 机器状态汇总
ST_MachineManualCommand   // 手动命令结构（所有模块的 Start+Mode）
ST_MachineModeState       // 模式状态
ST_ModuleCommandSource    // 单个模块的命令源
ST_MachineCommandSourceSet // 全部模块的命令源集合
ST_MachineModuleCommands  // 全部模块的最终命令
ST_HMIProcessPara         // HMI 工艺参数
ST_HMIParaCommand         // HMI 参数命令
ST_HMIParaStatus          // HMI 参数状态
ST_ModuleRuntimeStatus    // 单个模块运行状态
ST_{Module}RuntimeStatus  // 各模块专用运行状态（7个）
```

## 轴层类型 (AxisTypes.st)

```
E_AxisState: (Idle, Running, Stop)
ST_PumpRequest: {bRequest, rFlowSet, rPressureSet}
ST_HydAxisStatus: {bEnabled, bReady, bCommandActive, bInPosition, bInVelocity, bInPressure, bAlarm, dwAlarmID, uiActTime, rCmdPosition, rCmdVelocity, rCmdPressure}
ST_AxisRefHyd: {bActive, eAxisState, nAxisID, rMaxCylinderStroke, rMaxVelocity, rMaxPressure, rPosTolerance, rVelTolerance, rPresTolerance, rSetPosition, rSetVelocity, rSetPressure, rActualPosition, rActualVelocity, rActualPressure, stStatus, stPumpRequest, nFaultCode}
```

## 面板类型 (PanelTypes.st)

```
E_PanelModel: (ePanel_None, ePanel_MK110, ePanel_MK116, ePanel_MK150, ePanel_MK2030)
ST_PanelIO: {uiIN0..uiIN3, uiOUT0..uiOUT3}
ST_PanelButton: {uiPanelOrder, bValue, bLamp}
E_PanelButtonID: (ePanelButton_Manual .. ePanelButton_ZipperMotor, ePanelButton_Count)
ST_PanelButtons: aButton: ARRAY[0..46] OF ST_PanelButton
    注：数组上界必须始终等于 TO_UINT(ePanelButton_Count) - 1
```
