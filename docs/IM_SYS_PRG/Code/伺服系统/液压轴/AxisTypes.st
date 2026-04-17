(* 
  AxisTypes.st
  功能：
  1. 定义伺服系统中液压轴功能块使用的统一状态结构。
  2. 让主控层可以用一致的数据结构读取轴是否就绪、是否报警以及最终命令。

  说明：
  1. 具体工艺模块仍然只负责生成 `ST_AxisRefHyd` 的目标值与泵请求。
  2. 最终的轴实例化、限幅和轴层诊断，由 `FB_HydAxis` 完成。
*)

TYPE ST_HydAxisConfig :
STRUCT
    (* 轴身份与保护边界。 *)
    nAxisID: INT;                // 统一轴号，供主控/HMI/下位 I/O 对齐
    rMaxCylinderStroke: LREAL;   // 最大允许行程
    rMaxVelocity: LREAL;         // 最大允许速度
    rMaxPressure: LREAL;         // 最大允许压力
    rPosTolerance: LREAL;        // 位置到位容差
    rVelTolerance: LREAL;        // 速度到位容差
    rPresTolerance: LREAL;       // 压力到位容差
END_STRUCT
END_TYPE

TYPE ST_HydAxisStatus :
STRUCT
    (* 轴层使能与就绪状态。 *)
    bEnabled: BOOL;            // TRUE=当前主控允许该轴参与执行
    bReady: BOOL;              // TRUE=轴层检查通过，可接受当前命令
    bCommandActive: BOOL;      // TRUE=当前扫描周期存在有效执行命令

    (* 跟随判断。用于后续扩展更细的轴层闭环诊断。 *)
    bInPosition: BOOL;         // TRUE=实际位置进入目标位置容差带
    bInVelocity: BOOL;         // TRUE=实际速度进入目标速度容差带
    bInPressure: BOOL;         // TRUE=实际压力进入目标压力容差带

    (* 轴层报警与诊断。 *)
    bAlarm: BOOL;              // TRUE=轴层发现限幅、禁用下命令或继承的模块报警
    dwAlarmID: DWORD;          // 轴层最终报警码，包含模块报警与轴层报警叠加结果
    uiActTime: UINT;           // 当前连续命令保持时长，单位 s

    (* 轴层最终输出命令。
       这些值是经过轴层限幅后的最终结果，而不是模块原始目标值。
    *)
    rCmdPosition: LREAL;
    rCmdVelocity: LREAL;
    rCmdPressure: LREAL;
END_STRUCT
END_TYPE
