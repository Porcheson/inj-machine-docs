(* 
  CommonTypes.st
  功能：
  1. 定义多个执行模块共用的轴状态、泵请求和液压轴引用结构。
  2. 为工艺模块、伺服轴层和主控层提供统一的轴接口边界。

  维护要求：
  1. 若 `ST_AxisRefHyd` 字段发生变化，必须同步检查 `FB_HydAxis`、`FB_MachineController` 以及所有直接读写该结构的模块。
  2. 本文件只保留跨模块通用类型，不放单模块专用工艺参数。
*)

TYPE E_AxisState :
(
    Idle,           // 空闲：当前无有效执行命令
    Running,        // 运行：当前存在有效执行命令
    Stop            // 停止：轴被上层或保护逻辑强制压停
);
END_TYPE

TYPE ST_PumpRequest :
STRUCT
    bRequest: BOOL;       // TRUE=当前扫描周期需要泵站输出
    rFlowSet: LREAL;      // 目标流量设定值
    rPressureSet: LREAL;  // 目标压力设定值
END_STRUCT
END_TYPE

TYPE ST_AxisRefHyd :
STRUCT

    // ================================
	// AXIS_REF 轴索引结构体【完整版】
	// 包含：轴所有状态、位置、速度、扭矩、限位、报警、参数
	// ================================

    // ========== 1. 轴基础信息 ==========
    AxisNo           : INT;          // 轴编号 (0,1,2,3...)
    AxisName         : STRING[32];   // 轴名称
    Valid            : BOOL;         // 轴结构体有效
    AxisRefId        : UINT;         // 内部轴ID

    // ========== 2. 轴使能与状态 ==========
    Enabled          : BOOL;         // 轴已使能
    PowerOn          : BOOL;         // 伺服已上电
    Faulted          : BOOL;         // 轴故障
    Ready            : BOOL;         // 轴准备就绪
    Stopped          : BOOL;         // 轴已停止
    Moving           : BOOL;         // 轴正在运动
    Homing           : BOOL;         // 正在回零
    HomingDone       : BOOL;         // 回零完成
    InPosition       : BOOL;         // 已到达目标位置

    // ========== 3. 控制模式 ==========
    ControlMode      : INT;          // 当前控制模式
    // 0=未激活 1=位置 2=速度 3=扭矩 4=回零
    HomingMode       : INT;          // 回零模式

    // ========== 4. 位置数据 ==========
    ActualPosition   : LREAL;        // 实际位置（实时）
    CommandPosition  : LREAL;        // 指令位置
    HomePosition     : LREAL;        // 原点位置
    TargetPosition   : LREAL;        // 目标位置

    // ========== 5. 速度数据 ==========
    ActualVelocity   : LREAL;        // 实际速度
    CommandVelocity  : LREAL;        // 指令速度
    MaxVelocity      : LREAL;        // 轴最大速度

    // ========== 6. 加速度数据 ==========
    Acceleration     : LREAL;        // 当前加速度
    Deceleration     : LREAL;        // 当前减速度
    MaxAcceleration  : LREAL;        // 最大加速度
    MaxDeceleration  : LREAL;        // 最大减速度
    Jerk             : LREAL;        // 跃度
    MaxJerk          : LREAL;        // 最大跃度

    // ========== 7. 扭矩/力矩数据 ==========
    ActualTorque     : LREAL;        // 实际扭矩
    MaxTorque        : LREAL;        // 最大扭矩
    TorqueLimit      : LREAL;        // 扭矩限制

    // ========== 8. 限位信号 ==========
    PositiveLimit    : BOOL;         // 正限位触发
    NegativeLimit    : BOOL;         // 负限位触发
    SoftPlusLimit    : BOOL;         // 软正限位
    SoftNegLimit     : BOOL;         // 软负限位

    // ========== 9. 错误与报警 ==========
    Error            : BOOL;         // 轴错误
    ErrorId          : DWORD;        // 错误代码
    DriveAlarm       : BOOL;         // 驱动器报警
    DriveErrorId     : DWORD;        // 驱动器错误码
    ErrorStop        : BOOL;         // 错误停止

    // ========== 10. 状态字 ==========
    AxisStatus       : DWORD;        // 轴状态字
    DriveStatus      : DWORD;        // 驱动器状态字
    StatusBits       : ARRAY[0..15] OF BOOL; // 状态位		


	(* 根据实际需求可以增加变量	*)

    // 1. 几何尺寸
    Bore_Dia        : LREAL;  // 缸径 mm
    Rod_Dia         : LREAL;  // 杆径 mm
    Stroke          : LREAL;  // 总行程 mm
    Min_Len         : LREAL;  // 最小安装距
    Max_Len         : LREAL;  // 最大安装距

    // 2. 面积容积
    Area_Piston     : LREAL;  // mm²
    Area_Rod        : LREAL;  // mm²
    Area_Annular    : LREAL;  // mm²
    Vol_Per_MM      : LREAL;  // mL/mm

    // 3. 压力推力
    Press_Rated     : LREAL;  // MPa
    Press_Max       : LREAL;  // MPa
    Force_Extend    : LREAL;  // N
    Force_Retract   : LREAL;  // N
    Effi            : LREAL;  // 效率

    // 4. 速度流量
    Vel_Ext_Max     : LREAL;  // mm/s
    Vel_Ret_Max     : LREAL;  // mm/s
    Flow_Ext        : LREAL;  // L/min
    Flow_Ret        : LREAL;  // L/min

    // 5. 位置限位
    Soft_Limit_F    : LREAL;  // 正向软限位
    Soft_Limit_B    : LREAL;  // 反向软限位
    Home_Pos        : LREAL;  // 原点位置
    Pos_Tolerance   : LREAL;  // 定位允差

    // 6. 负载摩擦
    Friction        : LREAL;
    Max_Axial_Load  : LREAL;
    Max_Rad_Load    : LREAL;	
		
        
    (* 轴基础定义。由主控层和轴层统一维护。 *)
    bActive: BOOL;               // TRUE=该轴当前参与机器控制
    eAxisState: E_AxisState;     // 轴当前状态
    nAxisID: INT;                // 统一轴号
    rMaxCylinderStroke: LREAL;   // 最大允许行程
    rMaxVelocity: LREAL;         // 最大允许速度
    rMaxPressure: LREAL;         // 最大允许压力

    (* 目标命令。通常由模块层写入，再由轴层整理。 *)
    rSetPosition: LREAL;         // 目标位置
    rSetVelocity: LREAL;         // 目标速度
    rSetPressure: LREAL;         // 目标压力

    (* 实际反馈。通常由主控层回写现场反馈值。 *)
    rActualPosition: LREAL;      // 实际位置
    rActualVelocity: LREAL;      // 实际速度
    rActualPressure: LREAL;      // 实际压力

    (* 泵请求。用于把轴动作转换成液压站侧需求。 *)
    stPumpRequest: ST_PumpRequest;

    (* 故障码。模块层和轴层都可以叠加写入。 *)
    nFaultCode: INT;             // 轴相关报警或故障码
END_STRUCT
END_TYPE
