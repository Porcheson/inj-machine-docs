(* 
  FB_MachineController 功能块
  功能：
  1. 提供真正的机器级执行层，负责实例化并周期调用所有模块级功能块。
  2. 在同一处完成手动、调模、半自动、全自动四类命令来源的切换与分发。
  3. 把模块状态、轴命令和自动流程状态汇总为统一的机器级状态输出。

  调用关系：
  1. `FB_AutoCycle` 只负责调度，不直接驱动任何轴。
  2. 本功能块负责把 `FB_AutoCycle` 的启动/复位/模式输出接到实际执行模块。
  3. 各执行模块内部各自持有 `FB_HydAxis` 并自行处理轴使能、轴配置和轴状态并入。
  4. `FB_EK312` 由 `PROGRAM PRG_MainControl` 顶层独立调用，本功能块不处理温控块接口和温控状态。
  5. 必须由 `PROGRAM PRG_MainControl` 以 1ms 基础任务调用本功能块；10ms 工艺节拍也必须由顶层生成后通过输入接口送入本块。
*)
FUNCTION_BLOCK FB_MachineController
VAR_INPUT
    stCommand: ST_MachineCommand;    // 顶层下发的机器公共命令集合，包含启动/停止/复位/模式号以及手动动作命令。
    stPara: ST_MachinePara;          // 顶层下发的机器在线工艺参数全集，由主控分发给各执行模块使用。
    stSensor: ST_MachineSensor;      // 顶层采集的现场条件、限位和轴反馈，供主控与子模块做互锁和状态判断。
    bLogicTick10msIn: BOOL;          // 顶层当前扫描周期给出的 10ms 工艺逻辑节拍，本块只在该拍刷新模式路由和自动流程。
END_VAR
VAR_OUTPUT
    stStatus: ST_MachineStatus;      // 主控汇总后的机器级总状态，供 HMI、上位机和其他顶层逻辑统一读取。

    (* 各轴输出。
       这些结构体同时包含模块下发的设定值与主控层回写的实际反馈值，
       便于后续继续接入真实轴控或液压阀控层。
    *)
    stClampAxis: ST_AxisRefHyd;          // 合模模块输出的最终轴命令与反馈镜像，对外暴露为锁模轴边界。
    stMoldAdjustAxis: ST_AxisRefHyd;     // 调模模块输出的最终轴命令与反馈镜像，对外暴露为调模轴边界。
    stNozzleAxis: ST_AxisRefHyd;         // 座台模块输出的最终轴命令与反馈镜像，对外暴露为座台轴边界。
    stInjectAxis: ST_AxisRefHyd;         // 射胶模块输出的最终轴命令与反馈镜像，对外暴露为射胶轴边界。
    stMeterAxis: ST_AxisRefHyd;          // 储料模块输出的最终轴命令与反馈镜像，对外暴露为储料轴边界。
    stEjectAxis: ST_AxisRefHyd;          // 托模模块当前被选中的最终轴命令与反馈镜像，可能来自基础托模或托模模式。
    stCoreAxis: ST_AxisRefHyd;           // 中子模块输出的最终轴命令与反馈镜像，对外暴露为中子轴边界。

    (* 透传关键组合输出。 *)
    aCoreAllow: ARRAY[1..8] OF BOOL;     // 合模模块回写的 8 路中子允许位，供其他模块和上位系统读取联锁结果。
END_VAR
VAR
    (* 子模块实例。 *)
    fbManualMode: FB_ManualMode;                  // 手动模式命令路由实例，把手动按钮翻译成各执行模块可直接消费的命令。
    fbAutoCycle: FB_AutoCycle;                    // 自动流程调度实例，只负责自动步骤编排，不直接操作任何轴。
    fbMoldAdjustMode: FB_MoldAdjustMode;          // 调模模式命令路由实例，把调模专用命令收口到锁模和调模块。
    fbClamp: FB_Clamp;                            // 合模执行模块实例，内部自带锁模轴层处理。
    fbMoldAdjust: FB_MoldAdjust;                  // 调模执行模块实例，内部自带调模轴层处理。
    fbNozzle: FB_Nozzle;                          // 座台执行模块实例，内部自带座台轴层处理。
    fbInject: FB_Inject;                          // 射胶执行模块实例，内部自带射胶轴层处理。
    fbMeter: FB_Meter;                            // 储料执行模块实例，内部自带储料轴层处理。
    fbEject: FB_Eject;                            // 基础托模执行模块实例，内部自带基础托模轴层处理。
    fbEjectMode: FB_EjectMode;                    // 托模模式执行模块实例，内部复用 `FB_Eject` 做组合动作封装。
    fbCore: FB_Core;                              // 中子执行模块实例，内部自带中子轴层处理。

    bManualClampStart: BOOL := FALSE;             // 手动模式输出的合模启动命令缓存，10ms 节拍刷新后再路由到合模块。
    uiManualClampMode: UINT := 0;                 // 手动模式输出的合模动作模式号缓存。
    bManualMoldAdjustStart: BOOL := FALSE;        // 手动/调模模式输出的调模启动命令缓存。
    uiManualMoldAdjustMode: UINT := 0;            // 手动/调模模式输出的调模动作模式号缓存。
    bManualNozzleStart: BOOL := FALSE;            // 手动模式输出的座台启动命令缓存。
    uiManualNozzleMode: UINT := 0;                // 手动模式输出的座台动作模式号缓存。
    bManualInjectStart: BOOL := FALSE;            // 手动模式输出的射胶启动命令缓存。
    uiManualInjectMode: UINT := 0;                // 手动模式输出的射胶动作模式号缓存。
    bManualMeterStart: BOOL := FALSE;             // 手动模式输出的储料启动命令缓存。
    bManualEjectStart: BOOL := FALSE;             // 手动模式输出的基础托模启动命令缓存。
    uiManualEjectMode: UINT := 0;                 // 手动模式输出的基础托模动作模式号缓存。
    bManualEjectModeStart: BOOL := FALSE;         // 手动模式输出的托模组合模式启动命令缓存。
    uiManualEjectPatternMode: UINT := 0;          // 手动模式输出的托模组合模式号缓存，例如定次/震动/停留。
    uiManualEjectTimes: UINT := 0;                // 手动模式输出的托模组合次数缓存，供定次或震动模式使用。
    bManualCoreStart: BOOL := FALSE;              // 手动模式输出的中子启动命令缓存。
    uiManualCoreMode: UINT := 0;                  // 手动模式输出的中子动作模式号缓存。

    (* 托模基础块和托模模式块不能同时写同一根轴。
       因此各自使用独立的内部轴缓存，最后由主控层按模式择一输出到 stEjectAxis。
    *)
    stEjectAxisBase: ST_AxisRefHyd;               // 基础托模块独占使用的托模轴缓存，避免与托模模式块直接争抢同一输出结构。
    stEjectAxisMode: ST_AxisRefHyd;               // 托模模式块独占使用的托模轴缓存，最终再由主控择一输出到 `stEjectAxis`。

    (* 模式判定。
       bModeChanged 用于在模式切换的当个扫描周期统一打一拍停止，
       防止某个模块沿用上一模式留下的执行状态继续动作。
    *)
    bManualModeActive: BOOL := FALSE;             // TRUE=当前主控解析出的机器模式为手动模式。
    bMoldAdjustModeActive: BOOL := FALSE;         // TRUE=当前主控解析出的机器模式为调模模式。
    bSemiAutoModeActive: BOOL := FALSE;           // TRUE=当前主控解析出的机器模式为半自动模式。
    bFullAutoModeActive: BOOL := FALSE;           // TRUE=当前主控解析出的机器模式为全自动模式。
    bModeChanged: BOOL := FALSE;                  // TRUE=本拍检测到机器模式发生切换，用于打一拍全局停止保护。
    uiLastMachineMode: UINT := 0;                 // 上一扫描周期保存的机器模式号，用于与当前模式比较判断是否切模。
    uiResolvedAutoMode: UINT := 0;                // 解析后的自动模式号，0=非自动 1=半自动 2=全自动，专供 `FB_AutoCycle` 使用。
    bGlobalStop: BOOL := FALSE;                   // 主控内部统一停止位，收口停机命令、停机模式和切模保护停止。
    bAutoReadyLocal: BOOL := FALSE;               // 自动循环可启动条件综合结果，最终写入 `stStatus.bAutoReady`。
    bUseEjectModeManual: BOOL := FALSE;           // TRUE=当前手动命令应切换到托模组合模式而不是基础托模块。

    (* 自动流程输出命令缓存。 *)
    bAutoBusy: BOOL := FALSE;                     // 自动流程 Busy 状态缓存，用于机器级状态汇总。
    bAutoDone: BOOL := FALSE;                     // 自动流程 Done 状态缓存，用于机器级状态汇总。
    bAutoAlarm: BOOL := FALSE;                    // 自动流程 Alarm 状态缓存，用于机器级状态汇总。
    dwAutoAlarmID: DWORD := 0;                    // 自动流程报警码缓存。
    uiAutoActHint: UINT := 0;                     // 自动流程动作提示号缓存，用于优先显示机器当前自动步骤。
    uiAutoActTime: UINT := 0;                     // 自动流程当前动作持续时间缓存。
    uiAutoCycleCount: UINT := 0;                  // 自动流程累计循环次数缓存。
    bAutoClampStart: BOOL := FALSE;               // 自动流程输出的合模启动命令缓存。
    bAutoClampReset: BOOL := FALSE;               // 自动流程输出的合模复位命令缓存。
    uiAutoClampMode: UINT := 0;                   // 自动流程输出的合模动作模式号缓存。
    bAutoNozzleStart: BOOL := FALSE;              // 自动流程输出的座台启动命令缓存。
    bAutoNozzleReset: BOOL := FALSE;              // 自动流程输出的座台复位命令缓存。
    uiAutoNozzleMode: UINT := 0;                  // 自动流程输出的座台动作模式号缓存。
    bAutoInjectStart: BOOL := FALSE;              // 自动流程输出的射胶启动命令缓存。
    bAutoInjectReset: BOOL := FALSE;              // 自动流程输出的射胶复位命令缓存。
    uiAutoInjectMode: UINT := 0;                  // 自动流程输出的射胶动作模式号缓存。
    bAutoMeterStart: BOOL := FALSE;               // 自动流程输出的储料启动命令缓存。
    bAutoMeterReset: BOOL := FALSE;               // 自动流程输出的储料复位命令缓存。
    bAutoEjectStart: BOOL := FALSE;               // 自动流程输出的托模启动命令缓存。
    bAutoEjectReset: BOOL := FALSE;               // 自动流程输出的托模复位命令缓存。
    uiAutoEjectMode: UINT := 0;                   // 自动流程输出的托模动作模式号缓存。

    (* 主控层下发给各模块的最终命令。 *)
    bClampStartCmd: BOOL := FALSE;                // 主控最终下发给合模块的启动命令。
    bClampResetCmd: BOOL := FALSE;                // 主控最终下发给合模块的复位命令。
    uiClampModeCmd: UINT := 0;                    // 主控最终下发给合模块的动作模式号。
    bMoldAdjustStartCmd: BOOL := FALSE;           // 主控最终下发给调模块的启动命令。
    bMoldAdjustResetCmd: BOOL := FALSE;           // 主控最终下发给调模块的复位命令。
    uiMoldAdjustModeCmd: UINT := 0;               // 主控最终下发给调模块的动作模式号。
    bNozzleStartCmd: BOOL := FALSE;               // 主控最终下发给座台模块的启动命令。
    bNozzleResetCmd: BOOL := FALSE;               // 主控最终下发给座台模块的复位命令。
    uiNozzleModeCmd: UINT := 0;                   // 主控最终下发给座台模块的动作模式号。
    bInjectStartCmd: BOOL := FALSE;               // 主控最终下发给射胶模块的启动命令。
    bInjectResetCmd: BOOL := FALSE;               // 主控最终下发给射胶模块的复位命令。
    uiInjectModeCmd: UINT := 0;                   // 主控最终下发给射胶模块的动作模式号。
    bMeterStartCmd: BOOL := FALSE;                // 主控最终下发给储料模块的启动命令。
    bMeterResetCmd: BOOL := FALSE;                // 主控最终下发给储料模块的复位命令。
    bEjectStartCmd: BOOL := FALSE;                // 主控最终下发给基础托模块的启动命令。
    bEjectResetCmd: BOOL := FALSE;                // 主控最终下发给基础托模块的复位命令。
    uiEjectModeCmd: UINT := 0;                    // 主控最终下发给基础托模块的动作模式号。
    bEjectModeStartCmd: BOOL := FALSE;            // 主控最终下发给托模模式块的启动命令。
    bEjectModeResetCmd: BOOL := FALSE;            // 主控最终下发给托模模式块的复位命令。
    uiEjectPatternModeCmd: UINT := 0;             // 主控最终下发给托模模式块的组合模式号。
    uiEjectTimesCmd: UINT := 0;                   // 主控最终下发给托模模式块的循环次数/震动次数。
    bCoreStartCmd: BOOL := FALSE;                 // 主控最终下发给中子模块的启动命令。
    bCoreResetCmd: BOOL := FALSE;                 // 主控最终下发给中子模块的复位命令。
    uiCoreModeCmd: UINT := 0;                     // 主控最终下发给中子模块的动作模式号。

    (* 子模块状态缓存。 *)
    bClampBusy: BOOL := FALSE;                    // 合模块 Busy 状态缓存。
    bClampDone: BOOL := FALSE;                    // 合模块 Done 状态缓存。
    bClampAlarm: BOOL := FALSE;                   // 合模块 Alarm 状态缓存。
    dwClampAlarmID: DWORD := 0;                   // 合模块报警码缓存。
    uiClampActHint: UINT := 0;                    // 合模块动作提示号缓存。
    uiClampActTime: UINT := 0;                    // 合模块当前动作持续时间缓存。
    bMoldOpened: BOOL := FALSE;                   // 合模块“已开模到位”状态缓存。
    bMoldClosed: BOOL := FALSE;                   // 合模块“已合模到位”状态缓存。
    aCoreAllowLocal: ARRAY[1..8] OF BOOL;         // 合模块内部给出的 8 路中子允许位缓存，稍后透传到输出数组。

    bMoldAdjustBusy: BOOL := FALSE;               // 调模块 Busy 状态缓存。
    bMoldAdjustDone: BOOL := FALSE;               // 调模块 Done 状态缓存。
    bMoldAdjustAlarm: BOOL := FALSE;              // 调模块 Alarm 状态缓存。
    dwMoldAdjustAlarmID: DWORD := 0;              // 调模块报警码缓存。
    uiMoldAdjustActHint: UINT := 0;               // 调模块动作提示号缓存。
    uiMoldAdjustActTime: UINT := 0;               // 调模块当前动作持续时间缓存。
    bMoldAdjustIned: BOOL := FALSE;               // 调模块“调模进到位”状态缓存。
    bMoldAdjustOuted: BOOL := FALSE;              // 调模块“调模退到位”状态缓存。

    bNozzleBusy: BOOL := FALSE;                   // 座台模块 Busy 状态缓存。
    bNozzleDone: BOOL := FALSE;                   // 座台模块 Done 状态缓存。
    bNozzleAlarm: BOOL := FALSE;                  // 座台模块 Alarm 状态缓存。
    dwNozzleAlarmID: DWORD := 0;                  // 座台模块报警码缓存。
    uiNozzleActHint: UINT := 0;                   // 座台模块动作提示号缓存。
    uiNozzleActTime: UINT := 0;                   // 座台模块当前动作持续时间缓存。
    bNozzleIned: BOOL := FALSE;                   // 座台模块“进到位”状态缓存。
    bNozzleOuted: BOOL := FALSE;                  // 座台模块“退到位”状态缓存。

    bInjectBusy: BOOL := FALSE;                   // 射胶模块 Busy 状态缓存。
    bInjectDone: BOOL := FALSE;                   // 射胶模块 Done 状态缓存。
    bInjectAlarm: BOOL := FALSE;                  // 射胶模块 Alarm 状态缓存。
    dwInjectAlarmID: DWORD := 0;                  // 射胶模块报警码缓存。
    uiInjectActHint: UINT := 0;                   // 射胶模块动作提示号缓存。
    uiInjectActTime: UINT := 0;                   // 射胶模块当前动作持续时间缓存。
    bInjected: BOOL := FALSE;                     // 射胶模块“射出完成”状态缓存。
    bHeld: BOOL := FALSE;                         // 射胶模块“保压完成”状态缓存。
    bSuckBacked: BOOL := FALSE;                   // 射胶模块“射退完成”状态缓存。

    bMeterBusy: BOOL := FALSE;                    // 储料模块 Busy 状态缓存。
    bMeterDone: BOOL := FALSE;                    // 储料模块 Done 状态缓存。
    bMeterAlarm: BOOL := FALSE;                   // 储料模块 Alarm 状态缓存。
    dwMeterAlarmID: DWORD := 0;                   // 储料模块报警码缓存。
    uiMeterActHint: UINT := 0;                    // 储料模块动作提示号缓存。
    uiMeterActTime: UINT := 0;                    // 储料模块当前动作持续时间缓存。
    bMetered: BOOL := FALSE;                      // 储料模块“储料完成”状态缓存。

    bEjectBaseBusy: BOOL := FALSE;                // 基础托模块 Busy 状态缓存。
    bEjectBaseDone: BOOL := FALSE;                // 基础托模块 Done 状态缓存。
    bEjectBaseAlarm: BOOL := FALSE;               // 基础托模块 Alarm 状态缓存。
    dwEjectBaseAlarmID: DWORD := 0;               // 基础托模块报警码缓存。
    uiEjectBaseActHint: UINT := 0;                // 基础托模块动作提示号缓存。
    uiEjectBaseActTime: UINT := 0;                // 基础托模块当前动作持续时间缓存。
    bEjectBaseIned: BOOL := FALSE;                // 基础托模块“退回到位/内位到位”状态缓存。
    bEjectBaseOuted: BOOL := FALSE;               // 基础托模块“顶出到位/外位到位”状态缓存。

    bEjectModeBusy: BOOL := FALSE;                // 托模模式块 Busy 状态缓存。
    bEjectModeDone: BOOL := FALSE;                // 托模模式块 Done 状态缓存。
    bEjectModeAlarm: BOOL := FALSE;               // 托模模式块 Alarm 状态缓存。
    dwEjectModeAlarmID: DWORD := 0;               // 托模模式块报警码缓存。
    uiEjectModeActHint: UINT := 0;                // 托模模式块动作提示号缓存。
    uiEjectModeActTime: UINT := 0;                // 托模模式块当前动作持续时间缓存。
    bEjectModeIned: BOOL := FALSE;                // 托模模式块“退回到位/内位到位”状态缓存。
    bEjectModeOuted: BOOL := FALSE;               // 托模模式块“顶出到位/外位到位”状态缓存。

    bSelectedEjectBusy: BOOL := FALSE;            // 当前被主控选中的托模来源 Busy 状态缓存。
    bSelectedEjectDone: BOOL := FALSE;            // 当前被主控选中的托模来源 Done 状态缓存。
    bSelectedEjectAlarm: BOOL := FALSE;           // 当前被主控选中的托模来源 Alarm 状态缓存。
    dwSelectedEjectAlarmID: DWORD := 0;           // 当前被主控选中的托模来源报警码缓存。
    uiSelectedEjectActHint: UINT := 0;            // 当前被主控选中的托模来源动作提示号缓存。
    uiSelectedEjectActTime: UINT := 0;            // 当前被主控选中的托模来源动作持续时间缓存。
    bSelectedEjectIned: BOOL := FALSE;            // 当前被主控选中的托模来源“内位到位”状态缓存。
    bSelectedEjectOuted: BOOL := FALSE;           // 当前被主控选中的托模来源“外位到位”状态缓存。

    bCoreBusy: BOOL := FALSE;                     // 中子模块 Busy 状态缓存。
    bCoreDone: BOOL := FALSE;                     // 中子模块 Done 状态缓存。
    bCoreAlarm: BOOL := FALSE;                    // 中子模块 Alarm 状态缓存。
    dwCoreAlarmID: DWORD := 0;                    // 中子模块报警码缓存。
    uiCoreActHint: UINT := 0;                     // 中子模块动作提示号缓存。
    uiCoreActTime: UINT := 0;                     // 中子模块当前动作持续时间缓存。
    bCoreIned: BOOL := FALSE;                     // 中子模块“进到位”状态缓存。
    bCoreOuted: BOOL := FALSE;                    // 中子模块“退到位”状态缓存。

    uiIndex: UINT := 0;                           // 通用数组循环索引，当前用于拷贝 `aCoreAllowLocal` 到输出数组。
END_VAR

(* 运行模式先统一解析，后续所有模块都只看这一组结果。
   其中“调模模式”是机器级独立模式，不等同于普通手动模式：
   1. 只开放锁模调试与调模动作。
   2. 不参与自动循环。
   3. 其他模块保持停机或复位状态，避免试模阶段误动作。
*)
bManualModeActive := (stCommand.uiMachineMode = 1);                                   // 模式号为 1 时，主控标记当前进入手动模式。
bMoldAdjustModeActive := (stCommand.uiMachineMode = 4);                               // 模式号为 4 时，主控标记当前进入调模模式。
bSemiAutoModeActive := (stCommand.uiMachineMode = 2);                                 // 模式号为 2 时，主控标记当前进入半自动模式。
bFullAutoModeActive := (stCommand.uiMachineMode = 3);                                 // 模式号为 3 时，主控标记当前进入全自动模式。
bModeChanged := (uiLastMachineMode <> stCommand.uiMachineMode);                       // 当前模式号与上一拍不同则认为发生了模式切换。
uiLastMachineMode := stCommand.uiMachineMode;                                          // 保存本拍模式号，供下一拍继续检测是否切模。
bGlobalStop := stCommand.bStop OR (stCommand.uiMachineMode = 0) OR bModeChanged;      // 停止命令、停机模式或切模保护任一出现，都统一触发主控总停止。

IF bSemiAutoModeActive THEN                                                            // 半自动模式时，把自动流程工作模式解析为 1。
    uiResolvedAutoMode := 1;                                                            // `FB_AutoCycle` 用 1 表示半自动。
ELSIF bFullAutoModeActive THEN                                                          // 全自动模式时，把自动流程工作模式解析为 2。
    uiResolvedAutoMode := 2;                                                            // `FB_AutoCycle` 用 2 表示全自动。
ELSE
    uiResolvedAutoMode := 0;                                                            // 非自动模式时，明确告知自动流程当前不参与调度。
END_IF;

IF bLogicTick10msIn THEN                                                      // 手动路由、调模路由和自动流程只在顶层送来的 10ms 逻辑拍到来时刷新一次。
    fbManualMode(
        bStop := bGlobalStop,                                                 // 把主控统一停止位送给手动路由块，切模或停机时立即撤销手动动作。
        bEStop := stCommand.bEStop,                                           // 把急停信号送给手动路由块，确保急停时手动命令立刻失效。
        bReset := stCommand.bReset,                                           // 把顶层复位信号送给手动路由块，便于清空手动命令状态。
        bActive := bManualModeActive,                                         // 只有机器处于手动模式时，手动路由块才输出有效动作命令。
        stManual := stCommand.stManual,                                       // 把完整手动命令结构送给手动路由块解析。
        bClampStart => bManualClampStart,                                     // 回收手动路由块给出的合模启动命令。
        uiClampMode => uiManualClampMode,                                     // 回收手动路由块给出的合模模式号。
        bMoldAdjustStart => bManualMoldAdjustStart,                           // 回收手动路由块给出的调模启动命令。
        uiMoldAdjustMode => uiManualMoldAdjustMode,                           // 回收手动路由块给出的调模模式号。
        bNozzleStart => bManualNozzleStart,                                   // 回收手动路由块给出的座台启动命令。
        uiNozzleMode => uiManualNozzleMode,                                   // 回收手动路由块给出的座台模式号。
        bInjectStart => bManualInjectStart,                                   // 回收手动路由块给出的射胶启动命令。
        uiInjectMode => uiManualInjectMode,                                   // 回收手动路由块给出的射胶模式号。
        bMeterStart => bManualMeterStart,                                     // 回收手动路由块给出的储料启动命令。
        bEjectStart => bManualEjectStart,                                     // 回收手动路由块给出的基础托模启动命令。
        uiEjectMode => uiManualEjectMode,                                     // 回收手动路由块给出的基础托模模式号。
        bEjectModeStart => bManualEjectModeStart,                             // 回收手动路由块给出的托模组合模式启动命令。
        uiEjectPatternMode => uiManualEjectPatternMode,                       // 回收手动路由块给出的托模组合模式号。
        uiEjectTimes => uiManualEjectTimes,                                   // 回收手动路由块给出的托模组合次数。
        bCoreStart => bManualCoreStart,                                       // 回收手动路由块给出的中子启动命令。
        uiCoreMode => uiManualCoreMode                                        // 回收手动路由块给出的中子模式号。
    );

    fbMoldAdjustMode(
        bStop := bGlobalStop,                                                 // 把主控统一停止位送给调模路由块，切模或停机时立即撤销调模动作。
        bEStop := stCommand.bEStop,                                           // 把急停信号送给调模路由块，确保急停时调模命令立刻失效。
        bReset := stCommand.bReset,                                           // 把顶层复位信号送给调模路由块，便于清空调模命令状态。
        bActive := bMoldAdjustModeActive,                                     // 只有机器处于调模模式时，调模路由块才输出有效动作命令。
        stManual := stCommand.stManual,                                       // 把完整手动/调模命令结构送给调模路由块解析。
        bClampStart => bManualClampStart,                                     // 回收调模路由块给出的锁模启动命令。
        uiClampMode => uiManualClampMode,                                     // 回收调模路由块给出的锁模模式号。
        bMoldAdjustStart => bManualMoldAdjustStart,                           // 回收调模路由块给出的调模启动命令。
        uiMoldAdjustMode => uiManualMoldAdjustMode                            // 回收调模路由块给出的调模模式号。
    );
END_IF;

IF bLogicTick10msIn THEN                                                      // 自动流程也只在顶层送来的 10ms 逻辑拍到来时刷新一次。
    (* 自动流程只在半自动/全自动模式下参与调度。
       一旦退出自动模式，就用 bStop 把自动流程拉回空闲态。
    *)
    fbAutoCycle(
        bStart := stCommand.bStart AND (uiResolvedAutoMode > 0),
        bStop := stCommand.bStop OR (uiResolvedAutoMode = 0),
        bEStop := stCommand.bEStop,
        bReset := stCommand.bReset,
        uiAutoMode := uiResolvedAutoMode,
        stAutoPara := stPara.stAutoPara,
        bDoorClosed := stSensor.bDoorClosed,
        bHydReady := stSensor.bHydReady,
        bSystemNoAlarm := stSensor.bSystemNoAlarm AND (NOT bClampAlarm) AND (NOT bMoldAdjustAlarm) AND
            (NOT bNozzleAlarm) AND (NOT bInjectAlarm) AND (NOT bMeterAlarm) AND
            (NOT bEjectBaseAlarm) AND (NOT bEjectModeAlarm) AND (NOT bCoreAlarm),
        bClampDone := bClampDone,
        bClampAlarm := bClampAlarm,
        bMoldOpened := bMoldOpened,
        bMoldClosed := bMoldClosed,
        bNozzleDone := bNozzleDone,
        bNozzleAlarm := bNozzleAlarm,
        bNozzleIned := bNozzleIned,
        bNozzleOuted := bNozzleOuted,
        bInjectDone := bInjectDone,
        bInjectAlarm := bInjectAlarm,
        bHeld := bHeld,
        bSuckBacked := bSuckBacked,
        bMeterDone := bMeterDone,
        bMeterAlarm := bMeterAlarm,
        bMetered := bMetered,
        bEjectDone := bEjectBaseDone,
        bEjectAlarm := bEjectBaseAlarm,
        bEjectIned := bEjectBaseIned,
        bEjectOuted := bEjectBaseOuted,
        bBusy => bAutoBusy,
        bDone => bAutoDone,
        bAlarm => bAutoAlarm,
        dwAlarmID => dwAutoAlarmID,
        uiActHint => uiAutoActHint,
        uiActTime => uiAutoActTime,
        uiCycleCount => uiAutoCycleCount,
        bClampStart => bAutoClampStart,
        bClampReset => bAutoClampReset,
        uiClampMode => uiAutoClampMode,
        bNozzleStart => bAutoNozzleStart,
        bNozzleReset => bAutoNozzleReset,
        uiNozzleMode => uiAutoNozzleMode,
        bInjectStart => bAutoInjectStart,
        bInjectReset => bAutoInjectReset,
        uiInjectMode => uiAutoInjectMode,
        bMeterStart => bAutoMeterStart,
        bMeterReset => bAutoMeterReset,
        bEjectStart => bAutoEjectStart,
        bEjectReset => bAutoEjectReset,
        uiEjectMode => uiAutoEjectMode
    );

    (* 先给各模块命令做安全缺省值。
       这样在模式切换时，未被当前模式接管的模块会自然保持停止/复位，不会沿用旧命令。
    *)
    bClampStartCmd := FALSE;                      // 默认不给合模块启动命令，避免未被接管时沿用旧动作。
    bClampResetCmd := stCommand.bReset;           // 合模块默认只响应顶层复位命令。
    uiClampModeCmd := 0;                          // 合模块默认模式号清零，表示当前无有效动作。

    bMoldAdjustStartCmd := FALSE;                 // 默认不给调模块启动命令，避免未被接管时沿用旧动作。
    bMoldAdjustResetCmd := stCommand.bReset;      // 调模块默认只响应顶层复位命令。
    uiMoldAdjustModeCmd := 0;                     // 调模块默认模式号清零，表示当前无有效动作。

    bNozzleStartCmd := FALSE;                     // 默认不给座台模块启动命令，避免未被接管时沿用旧动作。
    bNozzleResetCmd := stCommand.bReset;          // 座台模块默认只响应顶层复位命令。
    uiNozzleModeCmd := 0;                         // 座台模块默认模式号清零，表示当前无有效动作。

    bInjectStartCmd := FALSE;                     // 默认不给射胶模块启动命令，避免未被接管时沿用旧动作。
    bInjectResetCmd := stCommand.bReset;          // 射胶模块默认只响应顶层复位命令。
    uiInjectModeCmd := 0;                         // 射胶模块默认模式号清零，表示当前无有效动作。

    bMeterStartCmd := FALSE;                      // 默认不给储料模块启动命令，避免未被接管时沿用旧动作。
    bMeterResetCmd := stCommand.bReset;           // 储料模块默认只响应顶层复位命令。

    bEjectStartCmd := FALSE;                      // 默认不给基础托模块启动命令，避免未被接管时沿用旧动作。
    bEjectResetCmd := stCommand.bReset;           // 基础托模块默认只响应顶层复位命令。
    uiEjectModeCmd := 0;                          // 基础托模块默认模式号清零，表示当前无有效动作。

    bEjectModeStartCmd := FALSE;                  // 默认不给托模模式块启动命令，避免组合模式在切模后残留。
    bEjectModeResetCmd := TRUE;                   // 默认把托模模式块拉在复位态，只有明确使用时才释放。
    uiEjectPatternModeCmd := 0;                   // 托模模式块默认模式号清零，表示当前不执行组合动作。
    uiEjectTimesCmd := 0;                         // 托模模式块默认次数清零，避免沿用上一轮次数设定。

    bCoreStartCmd := FALSE;                       // 默认不给中子模块启动命令，避免未被接管时沿用旧动作。
    bCoreResetCmd := stCommand.bReset;            // 中子模块默认只响应顶层复位命令。
    uiCoreModeCmd := 0;                           // 中子模块默认模式号清零，表示当前无有效动作。

    (* 把不同来源的命令合并为“最终执行命令”。
       1. 手动模式：手动命令由 `FB_ManualMode` 路由。
       2. 调模模式：命令由 `FB_MoldAdjustMode` 路由，锁模强制进入调试方向，其他模块保持停机。
       3. 自动模式：命令来自 `FB_AutoCycle` 的调度输出。
    *)
    IF bManualModeActive THEN
        bClampStartCmd := bManualClampStart;          // 手动模式下，合模块直接接收手动命令路由结果。
        uiClampModeCmd := uiManualClampMode;          // 手动模式下，合模块直接接收手动动作模式号。

        bMoldAdjustStartCmd := bManualMoldAdjustStart;    // 手动模式下，调模块直接接收手动命令路由结果。
        uiMoldAdjustModeCmd := uiManualMoldAdjustMode;    // 手动模式下，调模块直接接收手动动作模式号。

        bNozzleStartCmd := bManualNozzleStart;        // 手动模式下，座台模块直接接收手动命令路由结果。
        uiNozzleModeCmd := uiManualNozzleMode;        // 手动模式下，座台模块直接接收手动动作模式号。

        bInjectStartCmd := bManualInjectStart;        // 手动模式下，射胶模块直接接收手动命令路由结果。
        uiInjectModeCmd := uiManualInjectMode;        // 手动模式下，射胶模块直接接收手动动作模式号。

        bMeterStartCmd := bManualMeterStart;          // 手动模式下，储料模块直接接收手动启动命令。

        bCoreStartCmd := bManualCoreStart;            // 手动模式下，中子模块直接接收手动命令路由结果。
        uiCoreModeCmd := uiManualCoreMode;            // 手动模式下，中子模块直接接收手动动作模式号。
    ELSIF bMoldAdjustModeActive THEN
        bClampStartCmd := bManualClampStart;          // 调模模式下，锁模动作仍由调模命令路由结果接管。
        uiClampModeCmd := uiManualClampMode;          // 调模模式下，锁模模式号仍取自调模命令路由结果。

        bMoldAdjustStartCmd := bManualMoldAdjustStart;    // 调模模式下，调模块直接接收调模命令路由结果。
        uiMoldAdjustModeCmd := uiManualMoldAdjustMode;    // 调模模式下，调模块直接接收调模动作模式号。
    ELSE
        bClampStartCmd := bAutoClampStart;            // 自动模式下，合模块启动命令由自动流程输出接管。
        bClampResetCmd := stCommand.bReset OR bAutoClampReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位合模块。
        uiClampModeCmd := uiAutoClampMode;            // 自动模式下，合模块动作模式号由自动流程给定。

        bNozzleStartCmd := bAutoNozzleStart;          // 自动模式下，座台模块启动命令由自动流程输出接管。
        bNozzleResetCmd := stCommand.bReset OR bAutoNozzleReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位座台模块。
        uiNozzleModeCmd := uiAutoNozzleMode;          // 自动模式下，座台模块动作模式号由自动流程给定。

        bInjectStartCmd := bAutoInjectStart;          // 自动模式下，射胶模块启动命令由自动流程输出接管。
        bInjectResetCmd := stCommand.bReset OR bAutoInjectReset; // 自动模式下，顶层复位与自动步骤复位任一成立都可复位射胶模块。
        uiInjectModeCmd := uiAutoInjectMode;          // 自动模式下，射胶模块动作模式号由自动流程给定。

        bMeterStartCmd := bAutoMeterStart;            // 自动模式下，储料模块启动命令由自动流程输出接管。
        bMeterResetCmd := stCommand.bReset OR bAutoMeterReset;   // 自动模式下，顶层复位与自动步骤复位任一成立都可复位储料模块。

        bEjectStartCmd := bAutoEjectStart;            // 自动模式下，基础托模块启动命令由自动流程输出接管。
        bEjectResetCmd := stCommand.bReset OR bAutoEjectReset;   // 自动模式下，顶层复位与自动步骤复位任一成立都可复位基础托模块。
        uiEjectModeCmd := uiAutoEjectMode;            // 自动模式下，基础托模块动作模式号由自动流程给定。
    END_IF;

    (* 托模既有基础动作块，也有组合模式块。
       这里把两类命令拆开，避免两个功能块同时争抢同一输出轴。
    *)
    bUseEjectModeManual := bManualModeActive AND bManualEjectModeStart AND   // 只有手动模式下明确发起托模模式命令时，才允许切到组合托模块。
        (uiManualEjectPatternMode >= 1) AND                                   // 模式号下限必须落在当前支持的托模组合模式范围内。
        (uiManualEjectPatternMode <= 3);                                      // 模式号上限必须落在当前支持的托模组合模式范围内。

    IF bManualModeActive AND (NOT bUseEjectModeManual) THEN
        bEjectStartCmd := bManualEjectStart;          // 纯手动基础托模时，把基础托模启动命令路由给 `FB_Eject`。
        bEjectResetCmd := stCommand.bReset;           // 纯手动基础托模时，基础托模块只响应顶层复位命令。
        uiEjectModeCmd := uiManualEjectMode;          // 纯手动基础托模时，把手动托模模式号路由给 `FB_Eject`。
    ELSIF NOT bManualModeActive THEN
        bEjectStartCmd := bAutoEjectStart;            // 非手动模式下，基础托模块启动命令由自动流程输出接管。
        bEjectResetCmd := stCommand.bReset OR bAutoEjectReset;   // 非手动模式下，顶层复位与自动步骤复位任一成立都可复位基础托模块。
        uiEjectModeCmd := uiAutoEjectMode;            // 非手动模式下，基础托模块动作模式号由自动流程给定。
    ELSE
        bEjectStartCmd := FALSE;                      // 进入托模组合模式时，强制撤销基础托模块启动命令，避免双块抢轴。
        bEjectResetCmd := TRUE;                       // 进入托模组合模式时，强制把基础托模块拉回复位态。
        uiEjectModeCmd := 0;                          // 进入托模组合模式时，基础托模块模式号清零。
    END_IF;

    IF bUseEjectModeManual THEN
        bEjectModeStartCmd := bManualEjectModeStart;      // 仅在手动组合托模生效时，把启动命令路由给 `FB_EjectMode`。
        bEjectModeResetCmd := stCommand.bReset;           // 仅在手动组合托模生效时，把顶层复位命令路由给 `FB_EjectMode`。
        uiEjectPatternModeCmd := uiManualEjectPatternMode; // 仅在手动组合托模生效时，把托模组合模式号路由给 `FB_EjectMode`。
        uiEjectTimesCmd := uiManualEjectTimes;            // 仅在手动组合托模生效时，把循环次数/震动次数路由给 `FB_EjectMode`。
    END_IF;
END_IF;

(* 依次调用执行模块。 *)
fbClamp(
    ClampAxis := stClampAxis,
    bStart := bClampStartCmd,
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := bClampResetCmd,
    bManualMode := bManualModeActive,
    uiClampMode := uiClampModeCmd,
    stClampPara := stPara.stClampPara,
    bOpenStop := stSensor.bOpenStop,
    bCloseLowPres := stSensor.bCloseLowPres,
    bCloseHighPres := stSensor.bCloseHighPres,
    bCloseStop := stSensor.bCloseStop,
    udiClampElecRulerVal := stSensor.udiClampElecRulerVal,
    uiClampPresElecRulerVal := stSensor.uiClampPresElecRulerVal,
    rClampActualPosition := stSensor.rClampActualPosition,
    rClampActualVelocity := stSensor.rClampActualVelocity,
    rClampActualPressure := stSensor.rClampActualPressure,
    bBusy => bClampBusy,
    bDone => bClampDone,
    bAlarm => bClampAlarm,
    dwAlarmID => dwClampAlarmID,
    uiActHint => uiClampActHint,
    uiActTime => uiClampActTime,
    bMoldOpened => bMoldOpened,
    bMoldClosed => bMoldClosed,
    aCoreAllow => aCoreAllowLocal
);

fbMoldAdjust(
    stMoldAdjustAxis := stMoldAdjustAxis,
    bStart := bMoldAdjustStartCmd,
    bStop := bGlobalStop OR (NOT (bManualModeActive OR bMoldAdjustModeActive)),
    bEStop := stCommand.bEStop,
    bReset := bMoldAdjustResetCmd,
    (* 这里只在“机器手动模式”下把整个调模块切到手动点动。
       当机器处于“调模模式”时，仍允许 uiMoldAdjustMode=1/2 按工艺段自动进退，
       也允许 uiMoldAdjustMode=3/4 进入手动点动，因此这里不直接把调模模式映射为 bManualMode=TRUE。
    *)
    bManualMode := bManualModeActive,
    uiMoldAdjustMode := uiMoldAdjustModeCmd,
    stMoldAdjustPara := stPara.stMoldAdjustPara,
    bMoldAdjustInStop := stSensor.bMoldAdjustInStop,
    bMoldAdjustOutStop := stSensor.bMoldAdjustOutStop,
    uiClampPresElecRulerVal := stSensor.uiClampPresElecRulerVal,
    rMoldAdjustActualPosition := stSensor.rMoldAdjustActualPosition,
    rMoldAdjustActualVelocity := stSensor.rMoldAdjustActualVelocity,
    rMoldAdjustActualPressure := stSensor.rMoldAdjustActualPressure,
    bBusy => bMoldAdjustBusy,
    bDone => bMoldAdjustDone,
    bAlarm => bMoldAdjustAlarm,
    dwAlarmID => dwMoldAdjustAlarmID,
    uiActHint => uiMoldAdjustActHint,
    uiActTime => uiMoldAdjustActTime,
    bMoldAdjustIned => bMoldAdjustIned,
    bMoldAdjustOuted => bMoldAdjustOuted
);

fbNozzle(
    stNozzleAxis := stNozzleAxis,
    bStart := bNozzleStartCmd,
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := bNozzleResetCmd,
    bManualMode := bManualModeActive,
    uiNozzleMode := uiNozzleModeCmd,
    stNozzlePara := stPara.stNozzlePara,
    bNozzleInStop := stSensor.bNozzleInStop,
    bNozzleOutStop := stSensor.bNozzleOutStop,
    udiNozzleElecRulerVal := stSensor.udiNozzleElecRulerVal,
    rNozzleActualPosition := stSensor.rNozzleActualPosition,
    rNozzleActualVelocity := stSensor.rNozzleActualVelocity,
    rNozzleActualPressure := stSensor.rNozzleActualPressure,
    bBusy => bNozzleBusy,
    bDone => bNozzleDone,
    bAlarm => bNozzleAlarm,
    dwAlarmID => dwNozzleAlarmID,
    uiActHint => uiNozzleActHint,
    uiActTime => uiNozzleActTime,
    bNozzleIned => bNozzleIned,
    bNozzleOuted => bNozzleOuted
);

fbInject(
    stInjectAxis := stInjectAxis,
    bStart := bInjectStartCmd,
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := bInjectResetCmd,
    bManualMode := bManualModeActive,
    uiInjectMode := uiInjectModeCmd,
    stInjectPara := stPara.stInjectPara,
    bInjSeg1Stop := stSensor.bInjSeg1Stop,
    bInjSeg2Stop := stSensor.bInjSeg2Stop,
    bInjStop := stSensor.bInjStop,
    bSuckBackStop := stSensor.bSuckBackStop,
    udiInjElecRulerVal := stSensor.udiInjElecRulerVal,
    rInjectActualPosition := stSensor.rInjectActualPosition,
    rInjectActualVelocity := stSensor.rInjectActualVelocity,
    rInjectActualPressure := stSensor.rInjectActualPressure,
    bBusy => bInjectBusy,
    bDone => bInjectDone,
    bAlarm => bInjectAlarm,
    dwAlarmID => dwInjectAlarmID,
    uiActHint => uiInjectActHint,
    uiActTime => uiInjectActTime,
    bInjected => bInjected,
    bHeld => bHeld,
    bSuckBacked => bSuckBacked
);

fbMeter(
    stMeterAxis := stMeterAxis,
    bStart := bMeterStartCmd,
    bStop := bGlobalStop,
    bEStop := stCommand.bEStop,
    bReset := bMeterResetCmd,
    bManualMode := bManualModeActive,
    stMeterPara := stPara.stMeterPara,
    bMeterStop := stSensor.bMeterStop,
    udiInjElecRulerVal := stSensor.udiInjElecRulerVal,
    rMeterActualPosition := stSensor.rMeterActualPosition,
    rMeterActualVelocity := stSensor.rMeterActualVelocity,
    rMeterActualPressure := stSensor.rMeterActualPressure,
    bBusy => bMeterBusy,
    bDone => bMeterDone,
    bAlarm => bMeterAlarm,
    dwAlarmID => dwMeterAlarmID,
    uiActHint => uiMeterActHint,
    uiActTime => uiMeterActTime,
    bMetered => bMetered
);

fbEject(
    stEjectAxis := stEjectAxisBase,
    bStart := bEjectStartCmd,
    bStop := bGlobalStop OR bUseEjectModeManual,
    bEStop := stCommand.bEStop,
    bReset := bEjectResetCmd,
    bManualMode := bManualModeActive,
    uiEjectMode := uiEjectModeCmd,
    stEjectPara := stPara.stEjectPara,
    bEjectInStop := stSensor.bEjectInStop,
    bEjectOutStop := stSensor.bEjectOutStop,
    udiEjectElecRulerVal := stSensor.udiEjectElecRulerVal,
    rEjectActualPosition := stSensor.rEjectActualPosition,
    rEjectActualVelocity := stSensor.rEjectActualVelocity,
    rEjectActualPressure := stSensor.rEjectActualPressure,
    bBusy => bEjectBaseBusy,
    bDone => bEjectBaseDone,
    bAlarm => bEjectBaseAlarm,
    dwAlarmID => dwEjectBaseAlarmID,
    uiActHint => uiEjectBaseActHint,
    uiActTime => uiEjectBaseActTime,
    bEjectIned => bEjectBaseIned,
    bEjectOuted => bEjectBaseOuted
);

fbEjectMode(
    stEjectAxis := stEjectAxisMode,
    bStart := bEjectModeStartCmd,
    bStop := bGlobalStop OR (NOT bUseEjectModeManual),
    bEStop := stCommand.bEStop,
    bReset := bEjectModeResetCmd,
    uiEjectMode := uiEjectPatternModeCmd,
    uiEjectTimes := uiEjectTimesCmd,
    stEjectPara := stPara.stEjectPara,
    bEjectInStop := stSensor.bEjectInStop,
    bEjectOutStop := stSensor.bEjectOutStop,
    udiEjectElecRulerVal := stSensor.udiEjectElecRulerVal,
    rEjectActualPosition := stSensor.rEjectActualPosition,
    rEjectActualVelocity := stSensor.rEjectActualVelocity,
    rEjectActualPressure := stSensor.rEjectActualPressure,
    bBusy => bEjectModeBusy,
    bDone => bEjectModeDone,
    bAlarm => bEjectModeAlarm,
    dwAlarmID => dwEjectModeAlarmID,
    uiActHint => uiEjectModeActHint,
    uiActTime => uiEjectModeActTime,
    bEjectIned => bEjectModeIned,
    bEjectOuted => bEjectModeOuted
);

fbCore(
    stCoreAxis := stCoreAxis,
    bStart := bCoreStartCmd,
    bStop := bGlobalStop OR (NOT bManualModeActive),
    bEStop := stCommand.bEStop,
    bReset := bCoreResetCmd,
    bManualMode := bManualModeActive,
    uiCoreMode := uiCoreModeCmd,
    stCorePara := stPara.stCorePara,
    bCoreInStop := stSensor.bCoreInStop,
    bCoreOutStop := stSensor.bCoreOutStop,
    rCoreActualPosition := stSensor.rCoreActualPosition,
    rCoreActualVelocity := stSensor.rCoreActualVelocity,
    rCoreActualPressure := stSensor.rCoreActualPressure,
    bBusy => bCoreBusy,
    bDone => bCoreDone,
    bAlarm => bCoreAlarm,
    dwAlarmID => dwCoreAlarmID,
    uiActHint => uiCoreActHint,
    uiActTime => uiCoreActTime,
    bCoreIned => bCoreIned,
    bCoreOuted => bCoreOuted
);

(* 由主控层统一选择当前托模输出来源。 *)
IF bUseEjectModeManual THEN
    stEjectAxis := stEjectAxisMode;                       // 手动组合托模生效时，对外输出切换为 `FB_EjectMode` 的轴结果。
    bSelectedEjectBusy := bEjectModeBusy;                 // 手动组合托模生效时，托模 Busy 状态取自 `FB_EjectMode`。
    bSelectedEjectDone := bEjectModeDone;                 // 手动组合托模生效时，托模 Done 状态取自 `FB_EjectMode`。
    bSelectedEjectAlarm := bEjectModeAlarm;               // 手动组合托模生效时，托模 Alarm 状态取自 `FB_EjectMode`。
    dwSelectedEjectAlarmID := dwEjectModeAlarmID;         // 手动组合托模生效时，托模报警码取自 `FB_EjectMode`。
    uiSelectedEjectActHint := uiEjectModeActHint;         // 手动组合托模生效时，托模动作提示号取自 `FB_EjectMode`。
    uiSelectedEjectActTime := uiEjectModeActTime;         // 手动组合托模生效时，托模动作时间取自 `FB_EjectMode`。
    bSelectedEjectIned := bEjectModeIned;                 // 手动组合托模生效时，托模内位到位状态取自 `FB_EjectMode`。
    bSelectedEjectOuted := bEjectModeOuted;               // 手动组合托模生效时，托模外位到位状态取自 `FB_EjectMode`。
ELSE
    stEjectAxis := stEjectAxisBase;                       // 未启用手动组合托模时，对外输出保持为基础托模块的轴结果。
    bSelectedEjectBusy := bEjectBaseBusy;                 // 未启用手动组合托模时，托模 Busy 状态取自基础托模块。
    bSelectedEjectDone := bEjectBaseDone;                 // 未启用手动组合托模时，托模 Done 状态取自基础托模块。
    bSelectedEjectAlarm := bEjectBaseAlarm;               // 未启用手动组合托模时，托模 Alarm 状态取自基础托模块。
    dwSelectedEjectAlarmID := dwEjectBaseAlarmID;         // 未启用手动组合托模时，托模报警码取自基础托模块。
    uiSelectedEjectActHint := uiEjectBaseActHint;         // 未启用手动组合托模时，托模动作提示号取自基础托模块。
    uiSelectedEjectActTime := uiEjectBaseActTime;         // 未启用手动组合托模时，托模动作时间取自基础托模块。
    bSelectedEjectIned := bEjectBaseIned;                 // 未启用手动组合托模时，托模内位到位状态取自基础托模块。
    bSelectedEjectOuted := bEjectBaseOuted;               // 未启用手动组合托模时，托模外位到位状态取自基础托模块。
END_IF;

FOR uiIndex := 1 TO 8 DO
    aCoreAllow[uiIndex] := aCoreAllowLocal[uiIndex];      // 逐路把合模块给出的中子允许位复制到对外输出数组。
END_FOR;

(* 机器级状态汇总。 *)
bAutoReadyLocal := stSensor.bDoorClosed AND stSensor.bHydReady AND                           // 自动准备就绪必须满足门已关和液压已就绪两项基础前提。
    stSensor.bSystemNoAlarm AND (NOT bClampAlarm) AND (NOT bMoldAdjustAlarm) AND            // 自动准备就绪还要求系统级与合模/调模块无报警。
    (NOT bNozzleAlarm) AND (NOT bInjectAlarm) AND (NOT bMeterAlarm) AND                      // 自动准备就绪还要求座台/射胶/储料模块无报警。
    (NOT bSelectedEjectAlarm) AND (NOT bCoreAlarm) AND (NOT bAutoAlarm);                     // 自动准备就绪还要求托模/中子/自动流程本身均无报警。

stStatus.uiMachineMode := stCommand.uiMachineMode;
stStatus.bManualModeActive := bManualModeActive;
stStatus.bMoldAdjustModeActive := bMoldAdjustModeActive;
stStatus.bSemiAutoModeActive := bSemiAutoModeActive;
stStatus.bFullAutoModeActive := bFullAutoModeActive;
stStatus.bAutoReady := bAutoReadyLocal;
stStatus.uiCycleCount := uiAutoCycleCount;

stStatus.bAutoBusy := bAutoBusy;
stStatus.bAutoDone := bAutoDone;
stStatus.bAutoAlarm := bAutoAlarm;
stStatus.dwAutoAlarmID := dwAutoAlarmID;

stStatus.bClampBusy := bClampBusy;
stStatus.bClampDone := bClampDone;
stStatus.bClampAlarm := bClampAlarm;
stStatus.dwClampAlarmID := dwClampAlarmID;
stStatus.bMoldOpened := bMoldOpened;
stStatus.bMoldClosed := bMoldClosed;

stStatus.bMoldAdjustBusy := bMoldAdjustBusy;
stStatus.bMoldAdjustDone := bMoldAdjustDone;
stStatus.bMoldAdjustAlarm := bMoldAdjustAlarm;
stStatus.dwMoldAdjustAlarmID := dwMoldAdjustAlarmID;
stStatus.bMoldAdjustIned := bMoldAdjustIned;
stStatus.bMoldAdjustOuted := bMoldAdjustOuted;

stStatus.bNozzleBusy := bNozzleBusy;
stStatus.bNozzleDone := bNozzleDone;
stStatus.bNozzleAlarm := bNozzleAlarm;
stStatus.dwNozzleAlarmID := dwNozzleAlarmID;
stStatus.bNozzleIned := bNozzleIned;
stStatus.bNozzleOuted := bNozzleOuted;

stStatus.bInjectBusy := bInjectBusy;
stStatus.bInjectDone := bInjectDone;
stStatus.bInjectAlarm := bInjectAlarm;
stStatus.dwInjectAlarmID := dwInjectAlarmID;
stStatus.bInjected := bInjected;
stStatus.bHeld := bHeld;
stStatus.bSuckBacked := bSuckBacked;

stStatus.bMeterBusy := bMeterBusy;
stStatus.bMeterDone := bMeterDone;
stStatus.bMeterAlarm := bMeterAlarm;
stStatus.dwMeterAlarmID := dwMeterAlarmID;
stStatus.bMetered := bMetered;

stStatus.bEjectModeSelected := bUseEjectModeManual;
stStatus.bEjectBusy := bSelectedEjectBusy;
stStatus.bEjectDone := bSelectedEjectDone;
stStatus.bEjectAlarm := bSelectedEjectAlarm;
stStatus.dwEjectAlarmID := dwSelectedEjectAlarmID;
stStatus.bEjectIned := bSelectedEjectIned;
stStatus.bEjectOuted := bSelectedEjectOuted;

stStatus.bCoreBusy := bCoreBusy;
stStatus.bCoreDone := bCoreDone;
stStatus.bCoreAlarm := bCoreAlarm;
stStatus.dwCoreAlarmID := dwCoreAlarmID;
stStatus.bCoreIned := bCoreIned;
stStatus.bCoreOuted := bCoreOuted;

stStatus.bMachineBusy := bAutoBusy OR bClampBusy OR bMoldAdjustBusy OR bNozzleBusy OR bInjectBusy OR
    bMeterBusy OR bSelectedEjectBusy OR bCoreBusy;

IF uiResolvedAutoMode > 0 THEN
    stStatus.bMachineDone := bAutoDone;
ELSE
    stStatus.bMachineDone := bClampDone OR bMoldAdjustDone OR bNozzleDone OR bInjectDone OR
        bMeterDone OR bSelectedEjectDone OR bCoreDone;
END_IF;

stStatus.bMachineAlarm := bAutoAlarm OR bClampAlarm OR bMoldAdjustAlarm OR bNozzleAlarm OR
    bInjectAlarm OR bMeterAlarm OR bSelectedEjectAlarm OR bCoreAlarm;

IF bAutoAlarm THEN
    stStatus.dwMachineAlarmID := dwAutoAlarmID;
ELSIF bClampAlarm THEN
    stStatus.dwMachineAlarmID := dwClampAlarmID;
ELSIF bMoldAdjustAlarm THEN
    stStatus.dwMachineAlarmID := dwMoldAdjustAlarmID;
ELSIF bNozzleAlarm THEN
    stStatus.dwMachineAlarmID := dwNozzleAlarmID;
ELSIF bInjectAlarm THEN
    stStatus.dwMachineAlarmID := dwInjectAlarmID;
ELSIF bMeterAlarm THEN
    stStatus.dwMachineAlarmID := dwMeterAlarmID;
ELSIF bSelectedEjectAlarm THEN
    stStatus.dwMachineAlarmID := dwSelectedEjectAlarmID;
ELSIF bCoreAlarm THEN
    stStatus.dwMachineAlarmID := dwCoreAlarmID;
ELSE
    stStatus.dwMachineAlarmID := DWORD#0;
END_IF;

(* 当前动作提示优先显示自动流程；若不在自动流程中，则显示当前实际运行的模块。 *)
stStatus.uiMachineActHint := 0;
stStatus.uiMachineActTime := 0;

IF (uiResolvedAutoMode > 0) AND (bAutoBusy OR bAutoDone OR bAutoAlarm) THEN
    stStatus.uiMachineActHint := uiAutoActHint;
    stStatus.uiMachineActTime := uiAutoActTime;
ELSIF bClampBusy OR bClampDone OR bClampAlarm THEN
    stStatus.uiMachineActHint := uiClampActHint;
    stStatus.uiMachineActTime := uiClampActTime;
ELSIF bMoldAdjustBusy OR bMoldAdjustDone OR bMoldAdjustAlarm THEN
    stStatus.uiMachineActHint := uiMoldAdjustActHint;
    stStatus.uiMachineActTime := uiMoldAdjustActTime;
ELSIF bNozzleBusy OR bNozzleDone OR bNozzleAlarm THEN
    stStatus.uiMachineActHint := uiNozzleActHint;
    stStatus.uiMachineActTime := uiNozzleActTime;
ELSIF bInjectBusy OR bInjectDone OR bInjectAlarm THEN
    stStatus.uiMachineActHint := uiInjectActHint;
    stStatus.uiMachineActTime := uiInjectActTime;
ELSIF bMeterBusy OR bMeterDone OR bMeterAlarm THEN
    stStatus.uiMachineActHint := uiMeterActHint;
    stStatus.uiMachineActTime := uiMeterActTime;
ELSIF bSelectedEjectBusy OR bSelectedEjectDone OR bSelectedEjectAlarm THEN
    stStatus.uiMachineActHint := uiSelectedEjectActHint;
    stStatus.uiMachineActTime := uiSelectedEjectActTime;
ELSIF bCoreBusy OR bCoreDone OR bCoreAlarm THEN
    stStatus.uiMachineActHint := uiCoreActHint;
    stStatus.uiMachineActTime := uiCoreActTime;
END_IF;
END_FUNCTION_BLOCK
