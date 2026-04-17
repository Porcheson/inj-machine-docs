(*
  PRG_MainControl 程序
  功能：
  1. 作为 PLC 工程唯一有效的主任务入口，统一调度 HMI 参数同步、顶层温控和机器主控。
  2. 本程序必须绑定到 1ms 基础任务；工艺逻辑由本程序在顶层生成固定 10ms 节拍后送给 `FB_MachineController`。
  3. 温控块 `FB_EK312` 必须由本程序在顶层直接调用，并由本程序在顶层生成固定 100ms 节拍后送给温控块刷新计算。
  4. 所有共享数据都通过 `全局变量\GlobalVars.st` 访问，不再拆分到多个顶层入口。

  维护要求：
  1. 工程任务配置只应绑定本程序，且基础周期固定为 1ms。
  2. 任何涉及主控流程、接口或架构的改动，都必须同步更新 3 份 MD 文档。
*)
PROGRAM PRG_MainControl
VAR
    (* `PRG_MainControl` 必须绑定到 1ms 基础任务；
       工艺逻辑按 10 拍执行一次，形成固定 10ms 逻辑节拍；
       温控系统按 100 拍执行一次，形成固定 100ms 逻辑节拍。
    *)
    uiLogicTickDiv: UINT := 0;                    // 10ms 逻辑节拍分频计数器，按 1ms 基础调用累加到第 10 拍后清零。
    bLogicTick10ms: BOOL := FALSE;                // TRUE=当前扫描周期命中一次 10ms 逻辑拍，允许主控刷新模式路由和自动流程。
    uiTempTickDiv: UINT := 0;                     // 100ms 温控节拍分频计数器，按 1ms 逻辑拍累加到第 100 拍后清零。
    bTempTick100ms: BOOL := FALSE;               // TRUE=当前扫描周期命中一次 100ms 逻辑拍，允许温控系统刷新一轮计算。
END_VAR


(* 基础调用周期固定按 1ms 设计；
   这里在顶层统一生成 10ms 工艺节拍和 100ms 温控节拍，
   让执行模块与其内部轴层仍然保持每拍 1ms 调用。
*)
bLogicTick10ms := FALSE;                        // 先把 10ms 节拍标志清零，只有命中分频点时才在当前扫描周期拉高一次。
IF uiLogicTickDiv >= 9 THEN                     // 当 1ms 基础拍累计满 10 次时，输出一次 10ms 逻辑节拍。
    uiLogicTickDiv := 0;                        // 10ms 分频计数器清零，开始统计下一轮 10ms 周期。
    bLogicTick10ms := TRUE;                     // 标记本扫描周期允许刷新一次主控工艺逻辑。
ELSE
    uiLogicTickDiv := uiLogicTickDiv + 1;       // 尚未达到 10ms 时继续累加 1ms 基础拍计数。
END_IF;

IF bTempTick100ms THEN                          // 先把 100ms 节拍标志清零，只有命中分频点时才在当前扫描周期拉高一次。
    IF uiTempTickDiv >= 99 THEN                  // 当 1ms 基础拍累计满 100 次时，输出一次 100ms 逻辑节拍。
        uiTempTickDiv := 0;                     // 100ms 分频计数器清零，开始统计下一轮 100ms 周期。
        bTempTick100ms := TRUE;                // 标记本扫描周期允许刷新一次温控计算。
    ELSE
        uiTempTickDiv := uiTempTickDiv + 1;     // 尚未达到 100ms 时继续累加 1ms 基础拍计数。
    END_IF;
END_IF;


(* 先同步 HMI 参数边界，确保 HMI 下发的新工艺值先写入在线参数区。 *)
gvl_fbHMIParaInterface(
    stMachinePara := gvl_stPara,                // 传入机器在线工艺参数，供 HMI 接口执行读回与参数覆盖。
    stHMIPara := gvl_stHMIPara,                 // 传入 HMI 编辑缓冲区，供 HMI 页面维护配方编辑态。
    stCommand := gvl_stHMIParaCommand,          // 传入 HMI 参数同步命令，驱动读回、应用和脏标记清除。
    stMachineStatus := gvl_stStatus,            // 传入整机状态，便于 HMI 接口在机器忙碌时拦截参数下发。
    stStatus => gvl_stHMIParaStatus             // 回写 HMI 参数接口状态，供画面显示同步结果和拦截原因。
);


(* 顶层独立处理温控系统，不再把温控结果并入机器主控。 *)
IF bTempTick100ms THEN  
    gvl_fbEK312(
        bStart := gvl_stCommand.stManual.bTempStart, // 直接把顶层温控启动命令送入温控块。
        bStop := gvl_stCommand.bStop,                // 机器停止时同步通知温控块退出执行态。
        bReset := gvl_stCommand.bReset,              // 机器复位时同步清空温控块内部状态。
        bR0 := gvl_stCommand.stManual.bR0,           // 直接把第 0 组人工加热命令送入温控块。
        bR1 := gvl_stCommand.stManual.bR1,           // 直接把第 1 组人工加热命令送入温控块。
        bR2 := gvl_stCommand.stManual.bR2,           // 直接把第 2 组人工加热命令送入温控块。
        bR3 := gvl_stCommand.stManual.bR3,           // 直接把第 3 组人工加热命令送入温控块。
        stInPara := gvl_stPara.stEK312InPara,        // 把在线温控参数传给顶层温控块做 100ms 刷新计算。
        stOutPara => gvl_stTempOutPara               // 顶层直接回写温控输出结构，供 HMI 和其他顶层逻辑读取。
    );
END_IF;


(* 再执行机器主控，由主控统一驱动模式管理、自动流程和全部执行模块。 *)
gvl_fbMachineController(
    stCommand := gvl_stCommand,                 // 传入机器公共命令，驱动模式路由、模块启动和复位逻辑。
    stPara := gvl_stPara,                       // 传入机器在线工艺参数，供主控分发给各子模块。
    stSensor := gvl_stSensor,                   // 传入现场输入与轴反馈，供主控和子模块做互锁判断。
    bLogicTick10msIn := bLogicTick10ms,         // 把顶层 10ms 工艺节拍送给主控，让主控只在该拍刷新模式路由和自动流程。
    stStatus => gvl_stStatus,                   // 回写机器级总状态，供 HMI 和上位调用链读取。
    stClampAxis => gvl_stClampAxis,             // 回写合模轴命令与反馈镜像，供后续轴控层或监控层读取。
    stMoldAdjustAxis => gvl_stMoldAdjustAxis,   // 回写调模轴命令与反馈镜像，供后续轴控层或监控层读取。
    stNozzleAxis => gvl_stNozzleAxis,           // 回写座台轴命令与反馈镜像，供后续轴控层或监控层读取。
    stInjectAxis => gvl_stInjectAxis,           // 回写射胶轴命令与反馈镜像，供后续轴控层或监控层读取。
    stMeterAxis => gvl_stMeterAxis,             // 回写储料轴命令与反馈镜像，供后续轴控层或监控层读取。
    stEjectAxis => gvl_stEjectAxis,             // 回写托模轴命令与反馈镜像，供后续轴控层或监控层读取。
    stCoreAxis => gvl_stCoreAxis,               // 回写中子轴命令与反馈镜像，供后续轴控层或监控层读取。
    aCoreAllow => gvl_aCoreAllow                // 回写合模允许中子动作数组，供其他联锁逻辑读取。
);
END_PROGRAM
