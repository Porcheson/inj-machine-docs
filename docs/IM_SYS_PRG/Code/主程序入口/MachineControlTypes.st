(* 
  MachineControlTypes.st
  功能：
  1. 定义机器级主控入口使用的命令、参数、传感器和状态结构。
  2. 统一手动、调模、半自动、全自动四类运行方式的上层接口。
  3. 为 `FB_MachineController` 和 `PRG_MainControl` 提供稳定的数据边界。

  说明：
  1. 现有各 `FB_*` 子模块仍然保持模块级职责，不在这里重复定义工艺细节。
  2. 机器级接口只负责把分散的模块输入输出汇总成“可实例化、可调用、可监控”的主控层。
  3. 后续若增加新轴、新模块或新工艺模式，应优先扩展本文件，再扩展主控逻辑。
*)

TYPE ST_MachineManualCommand :
STRUCT
    (* 合模模块手动命令。uiClampMode 沿用模块定义：1/2 自动开合模，3/4 调试开合模。 *)
    bClampStart: BOOL;
    uiClampMode: UINT;

    (* 调模模块手动命令。uiMoldAdjustMode 沿用模块定义：1/2 进退，3/4 手动进退。 *)
    bMoldAdjustStart: BOOL;
    uiMoldAdjustMode: UINT;

    (* 座台模块手动命令。uiNozzleMode 沿用模块定义：1/2 进退，3/4 调试进退。 *)
    bNozzleStart: BOOL;
    uiNozzleMode: UINT;

    (* 射胶模块手动命令。uiInjectMode 沿用模块定义：1/2 射出与射退，3/4 调试。 *)
    bInjectStart: BOOL;
    uiInjectMode: UINT;

    (* 储料模块手动命令。储料块没有独立模式号，手动时只需要启动命令。 *)
    bMeterStart: BOOL;

    (* 托模基础模块手动命令。uiEjectMode 沿用模块定义：1/2 进退，6/7 调试。 *)
    bEjectStart: BOOL;
    uiEjectMode: UINT;

    (* 托模组合模式命令。用于定次、震动、停留等更高层动作。 *)
    bEjectModeStart: BOOL;
    uiEjectPatternMode: UINT;   // 1=定次 2=震动 3=停留
    uiEjectTimes: UINT;         // 定次/震动次数；震动模式下 0 表示持续循环

    (* 中子模块手动命令。uiCoreMode 沿用模块定义：1/2 进退，3/4 调试。 *)
    bCoreStart: BOOL;
    uiCoreMode: UINT;

    (* 温控顶层命令。bTempStart 启动温控；bR0~bR3 可直接下发 4 组加热命令。 *)
    bTempStart: BOOL;          // TRUE=顶层温控块进入执行态。
    bR0: BOOL;                 // TRUE=人工直接驱动第 0 组加热输出。
    bR1: BOOL;                 // TRUE=人工直接驱动第 1 组加热输出。
    bR2: BOOL;                 // TRUE=人工直接驱动第 2 组加热输出。
    bR3: BOOL;                 // TRUE=人工直接驱动第 3 组加热输出。
END_STRUCT
END_TYPE

TYPE ST_MachineCommand :
STRUCT
    (* 机器级公共命令。 *)
    bStart: BOOL;               // 周期启动/当前模块启动
    bStop: BOOL;                // 正常停止
    bEStop: BOOL;               // 急停
    bReset: BOOL;               // 复位所有模块

    (* 运行模式。
       0=停机/待机
       1=手动
       2=半自动
       3=全自动
       4=调模模式

       说明：
       1. 手动模式允许人工点动各模块。
       2. 调模模式是独立机器模式，只开放锁模调试与调模相关动作，
          用于装模、试模和模厚调整，不参与自动循环。
    *)
    uiMachineMode: UINT;

    (* 手动模式与调模模式下的分模块命令集合。
       说明：
       1. 手动模式会读取整套人工命令。
       2. 调模模式只会读取其中与锁模调试、调模和温控相关的命令。
    *)
    stManual: ST_MachineManualCommand;
END_STRUCT
END_TYPE

TYPE ST_MachineSensor :
STRUCT
    (* 机器公共条件。自动流程会优先检查这些前提是否满足。 *)
    bDoorClosed: BOOL;
    bHydReady: BOOL;
    bSystemNoAlarm: BOOL;

    (* 合模模块过程信号。 *)
    bOpenStop: BOOL;
    bCloseLowPres: BOOL;
    bCloseHighPres: BOOL;
    bCloseStop: BOOL;
    udiClampElecRulerVal: UDINT;
    uiClampPresElecRulerVal: UINT;

    (* 调模模块过程信号。 *)
    bMoldAdjustInStop: BOOL;
    bMoldAdjustOutStop: BOOL;

    (* 座台模块过程信号。 *)
    bNozzleInStop: BOOL;
    bNozzleOutStop: BOOL;
    udiNozzleElecRulerVal: UDINT;

    (* 射胶与储料模块过程信号。 *)
    bInjSeg1Stop: BOOL;
    bInjSeg2Stop: BOOL;
    bInjStop: BOOL;
    bSuckBackStop: BOOL;
    bMeterStop: BOOL;
    udiInjElecRulerVal: UDINT;

    (* 托模模块过程信号。 *)
    bEjectInStop: BOOL;
    bEjectOutStop: BOOL;
    udiEjectElecRulerVal: UDINT;

    (* 中子模块过程信号。 *)
    bCoreInStop: BOOL;
    bCoreOutStop: BOOL;

    (* 轴反馈。
       这些反馈值会经由子模块接口写回各自的 `ST_AxisRefHyd`，让模块层同时看到“设定值”和“实际值”。
    *)
    rClampActualPosition: LREAL;
    rClampActualVelocity: LREAL;
    rClampActualPressure: LREAL;

    rMoldAdjustActualPosition: LREAL;
    rMoldAdjustActualVelocity: LREAL;
    rMoldAdjustActualPressure: LREAL;

    rNozzleActualPosition: LREAL;
    rNozzleActualVelocity: LREAL;
    rNozzleActualPressure: LREAL;

    rInjectActualPosition: LREAL;
    rInjectActualVelocity: LREAL;
    rInjectActualPressure: LREAL;

    rMeterActualPosition: LREAL;
    rMeterActualVelocity: LREAL;
    rMeterActualPressure: LREAL;

    rEjectActualPosition: LREAL;
    rEjectActualVelocity: LREAL;
    rEjectActualPressure: LREAL;

    rCoreActualPosition: LREAL;
    rCoreActualVelocity: LREAL;
    rCoreActualPressure: LREAL;
END_STRUCT
END_TYPE

TYPE ST_MachinePara :
STRUCT
    (* 子模块工艺参数全集。
       说明：
       1. 这是机器当前在线运行参数。
       2. `FB_MachineController` 只读取并分发，不在内部改写这些工艺值。
       3. 若 HMI 需要统一配方编辑入口，建议通过专用 HMI 参数接口先写入编辑缓冲区，
          再由上层执行“应用到机器”动作，避免画面直接改动在线参数。
    *)
    stClampPara: ST_ClampPara;
    stMoldAdjustPara: ST_MoldAdjustPara;
    stNozzlePara: ST_NozzlePara;
    stInjectPara: ST_InjectPara;
    stMeterPara: ST_MeterPara;
    stEjectPara: ST_EjectPara;
    stCorePara: ST_CorePara;
    stEK312InPara: ST_EK312InPara;
    stAutoPara: ST_AutoCyclePara;
END_STRUCT
END_TYPE

TYPE ST_HMIRecipeMeta :
STRUCT
    (* HMI 配方基础信息。
       这些字段不直接参与动作控制，但便于画面做配方编号、名称、版本和脏数据管理。
    *)
    uiRecipeID: UINT;             // HMI 配方号/工艺号
    sRecipeName: STRING[40];      // HMI 显示用配方名称
    uiRecipeVersion: UINT;        // HMI 自管版本号，可在每次保存后自增
    bDirty: BOOL;                 // TRUE=HMI 编辑缓冲区已改动但还未下发到机器
END_STRUCT
END_TYPE

TYPE ST_HMIProcessPara :
STRUCT
    (* HMI 统一工艺参数接口。
       说明：
       1. HMI 只需要绑定这一套结构，就能覆盖整机全部工艺参数。
       2. 内部仍复用各模块原生参数结构，避免为了画面再拆一层重复字段。
       3. `stMachinePara` 是 HMI 编辑缓冲区，不等同于当前在线运行参数。
          只有执行“应用到机器”后，内容才会写入在线参数。
       4. HMI 画面在用户改动任意字段后，建议同步把 `stMeta.bDirty` 置为 TRUE，
          便于配方页显示“已编辑未下发/未保存”状态。
    *)
    stMeta: ST_HMIRecipeMeta;
    stMachinePara: ST_MachinePara;
END_STRUCT
END_TYPE

TYPE ST_HMIParaCommand :
STRUCT
    (* HMI 参数同步命令。
       这些信号建议由按钮上升沿触发，不建议长时间保持 TRUE。
    *)
    bReadMachinePara: BOOL;       // 把当前在线运行参数读回到 HMI 编辑缓冲区
    bApplyToMachine: BOOL;        // 把 HMI 编辑缓冲区参数应用到机器在线参数
    bClearDirty: BOOL;            // 人工清除 HMI 编辑脏标记
END_STRUCT
END_TYPE

TYPE ST_HMIParaStatus :
STRUCT
    (* HMI 参数接口状态。
       这些状态用于给 HMI 做按钮反馈、提示灯和下发拦截提示。
    *)
    bInitialized: BOOL;           // TRUE=已完成首次把在线参数装载到 HMI 缓冲区
    bMachineParaLocked: BOOL;     // TRUE=机器正在运行/忙碌，禁止下发工艺参数
    bReadDone: BOOL;              // 本扫描周期完成了一次在线参数读回
    bApplyDone: BOOL;             // 本扫描周期完成了一次工艺参数下发
    bClearDone: BOOL;             // 本扫描周期完成了一次脏标记清除
    bApplyBlocked: BOOL;          // 本扫描周期收到下发命令但被拦截
    uiLastAction: UINT;           // 0=无 1=首次装载 2=读取在线参数 3=应用到机器 4=清除脏标记 5=下发被拦截
    uiLastRejectReason: UINT;     // 0=无 1=机器忙碌
    uiSyncCount: UINT;            // 成功同步次数统计
    uiRecipeID: UINT;             // 当前 HMI 缓冲区配方号镜像
    uiRecipeVersion: UINT;        // 当前 HMI 缓冲区版本号镜像
    sRecipeName: STRING[40];      // 当前 HMI 缓冲区名称镜像
    bDirty: BOOL;                 // 当前 HMI 缓冲区脏标记镜像
END_STRUCT
END_TYPE

TYPE ST_MachineStatus :
STRUCT
    (* 机器级总状态。 *)
    uiMachineMode: UINT;
    bManualModeActive: BOOL;
    bMoldAdjustModeActive: BOOL;
    bSemiAutoModeActive: BOOL;
    bFullAutoModeActive: BOOL;
    bAutoReady: BOOL;
    bMachineBusy: BOOL;
    bMachineDone: BOOL;
    bMachineAlarm: BOOL;
    dwMachineAlarmID: DWORD;
    uiMachineActHint: UINT;
    uiMachineActTime: UINT;
    uiCycleCount: UINT;

    (* 自动流程状态。 *)
    bAutoBusy: BOOL;
    bAutoDone: BOOL;
    bAutoAlarm: BOOL;
    dwAutoAlarmID: DWORD;

    (* 合模模块状态。 *)
    bClampBusy: BOOL;
    bClampDone: BOOL;
    bClampAlarm: BOOL;
    dwClampAlarmID: DWORD;
    bMoldOpened: BOOL;
    bMoldClosed: BOOL;

    (* 调模模块状态。 *)
    bMoldAdjustBusy: BOOL;
    bMoldAdjustDone: BOOL;
    bMoldAdjustAlarm: BOOL;
    dwMoldAdjustAlarmID: DWORD;
    bMoldAdjustIned: BOOL;
    bMoldAdjustOuted: BOOL;

    (* 座台模块状态。 *)
    bNozzleBusy: BOOL;
    bNozzleDone: BOOL;
    bNozzleAlarm: BOOL;
    dwNozzleAlarmID: DWORD;
    bNozzleIned: BOOL;
    bNozzleOuted: BOOL;

    (* 射胶模块状态。 *)
    bInjectBusy: BOOL;
    bInjectDone: BOOL;
    bInjectAlarm: BOOL;
    dwInjectAlarmID: DWORD;
    bInjected: BOOL;
    bHeld: BOOL;
    bSuckBacked: BOOL;

    (* 储料模块状态。 *)
    bMeterBusy: BOOL;
    bMeterDone: BOOL;
    bMeterAlarm: BOOL;
    dwMeterAlarmID: DWORD;
    bMetered: BOOL;

    (* 托模模块状态。
       bEjectModeSelected=TRUE 时表示当前输出来自 `FB_EjectMode`；
       否则当前输出来自基础 `FB_Eject`。
    *)
    bEjectModeSelected: BOOL;
    bEjectBusy: BOOL;
    bEjectDone: BOOL;
    bEjectAlarm: BOOL;
    dwEjectAlarmID: DWORD;
    bEjectIned: BOOL;
    bEjectOuted: BOOL;

    (* 中子模块状态。 *)
    bCoreBusy: BOOL;
    bCoreDone: BOOL;
    bCoreAlarm: BOOL;
    dwCoreAlarmID: DWORD;
    bCoreIned: BOOL;
    bCoreOuted: BOOL;

END_STRUCT
END_TYPE
