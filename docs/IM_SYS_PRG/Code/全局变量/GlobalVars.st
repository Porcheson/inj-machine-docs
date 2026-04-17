(*
  GlobalVars.st
  功能：
  1. 定义整机统一的共享数据边界，供 `PRG_MainControl` 及其调用链访问。
  2. 这里只保留在线运行所必需的命令、参数、状态和执行输出。
  3. 旧版手动/自动中间缓存已经移除，避免多入口重复调度同一控制链。

  维护规则：
  1. 任何代码改动只要影响接口、流程、命名、注释约定或架构分析，必须同步更新：
     `Code\文档\开发规范与注释约定.md`
     `Code\文档\总体架构与代码分析.md`
     `Code\文档\修改记录.md`
  2. 工程任务配置应只绑定 `PRG_MainControl` 作为有效主入口，且基础周期固定为 1ms。
*)
VAR_GLOBAL
    (* HMI 参数同步边界。
       `gvl_stPara` 是机器在线运行参数；
       `gvl_stHMIPara` 是 HMI 编辑缓冲区。
    *)
    gvl_stPara: ST_MachinePara;
    gvl_stHMIPara: ST_HMIProcessPara;
    gvl_stHMIParaCommand: ST_HMIParaCommand;
    gvl_stHMIParaStatus: ST_HMIParaStatus;

    (* 机器级命令、传感器和汇总状态。 *)
    gvl_stCommand: ST_MachineCommand;
    gvl_stSensor: ST_MachineSensor;
    gvl_stStatus: ST_MachineStatus;

    (* 面板管理综合按键边界。
       每个逻辑键同时收口排序号、键值和灯值，供不同面板型号功能块按同一结构交互。
    *)
    gvl_stPanelButtons: ST_PanelButtons;

    (* 各执行模块输出轴镜像。 *)
    gvl_stClampAxis: ST_AxisRefHyd;
    gvl_stMoldAdjustAxis: ST_AxisRefHyd;
    gvl_stNozzleAxis: ST_AxisRefHyd;
    gvl_stInjectAxis: ST_AxisRefHyd;
    gvl_stMeterAxis: ST_AxisRefHyd;
    gvl_stEjectAxis: ST_AxisRefHyd;
    gvl_stCoreAxis: ST_AxisRefHyd;
    gvl_aCoreAllow: ARRAY[1..8] OF BOOL;

    (* 温控输出。 *)
    gvl_stTempOutPara: ST_EK312OutPara;
END_VAR
