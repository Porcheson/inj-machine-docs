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
		
	
END_STRUCT
END_TYPE 




FUNCTION_BLOCK FB_AxisHyd
VAR_IN_OUT
	stAxisHyd: ST_AxisRefHyd;
END_VAR
VAR_INPUT	
	
    (* 控制命令 *)		
	bStart: BOOL;		// 启动	
	bStop: BOOL;		// 停止(有减速停)		
	bEStop: BOOL;		// 急停(立即停止，无减速停)	
	bReset: BOOL;		// 复位	
	bDir: BOOL;			// 方向

    (* 模式选择 *)	
	uiMode: UINT;		// 0:无模式 1:位置模式 2:速度模式 3:扭矩模式

    (* 参数设定 *)	
	uiCmdPres  : UINT; 	// 压力目标
    uiSpd      : UINT; 	// 速度目标
    udiPos     : UDINT; // 位置目标
    uiForce    : UINT; 	// 力目标，可选(锁模,射胶时使用）
	
    uiAcc	: UINT;     // 加速度 
    uiDec	: UINT;     // 减速度 
	uiJerk	: UINT;     // 加加速
		
END_VAR
VAR_OUTPUT

	(* 状态输出 *)
	bBusy: BOOL;		// 忙状态
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态

    (* 报警信息 *)
	dwAlarmID: DWORD;		// 报警代码
							(*	0:无
							*)

END_VAR
VAR
	// 状态机状态
	State: INT;
	// 内部状态
	StartOld: BOOL;
	StopOld: BOOL;
	EStopOld: BOOL;
	ResetOld: BOOL;
	// 位置/速度模拟
	SimPosition: LREAL;
	SimVelocity: LREAL;
	SimTorque: LREAL;
END_VAR

TYPE EN_AxisState =
(
	AXIS_IDLE		:= 0,	// 空闲
	AXIS_STARTING	:= 1,	// 启动中
	AXIS_RUNNING	:= 2,	// 运行中
	AXIS_STOPPING	:= 3,	// 停止中
	AXIS_STOPPED	:= 4,	// 已停止
	AXIS_ESTOPPING	:= 5,	// 急停中
	AXIS_ERROR		:= 6,	// 错误状态
	AXIS_RESETTING	:= 7	// 复位中
);
END_TYPE

(*
===================================================================
FB_AxisHyd - 液压伺服轴功能块【简化版】
===================================================================
功能：提供液压伺服轴的基本控制接口，用于PLC编程验证
备注：实际驱动器通信部分待后续实现

使用方式：
1. 配置 stAxisHyd 中的轴参数（行程、限位等）
2. 设置 uiMode 选择控制模式
3. 设置目标值（uiCmdPres, uiSpd, udiPos, uiForce）
4. 置位 bStart 启动轴运动
5. 监控 bBusy/bDone/bAlarm 状态

模式说明：
- uiMode=1: 位置模式 - 运动到 udiPos 指定位置
- uiMode=2: 速度模式 - 以 uiSpd 指定速度运动
- uiMode=3: 扭矩模式 - 以 uiForce 指定力运动
===================================================================
*)
FB_AxisHyd();

// 状态机
CASE State OF
	// ==================== 空闲状态 ====================
	AXIS_IDLE:
		bBusy		:= FALSE;
		bDone		:= FALSE;
		stAxisHyd.Moving	:= FALSE;
		stAxisHyd.Stopped	:= TRUE;

		// 检测启动命令
		IF bStart AND NOT StartOld THEN
			// 检查急停和报警
			IF stAxisHyd.DriveAlarm THEN
				dwAlarmID	:= 16#0001;	// 驱动器报警
				bAlarm		:= TRUE;
				State		:= AXIS_ERROR;
			ELSIF stAxisHyd.PositiveLimit AND bDir THEN
				dwAlarmID	:= 16#0002;	// 正限位
				bAlarm		:= TRUE;
				State		:= AXIS_ERROR;
			ELSIF stAxisHyd.NegativeLimit AND NOT bDir THEN
				dwAlarmID	:= 16#0003;	// 负限位
				bAlarm		:= TRUE;
				State		:= AXIS_ERROR;
			ELSE
				// 进入启动
				State		:= AXIS_STARTING;
			END_IF
		END_IF

	// ==================== 启动中 ====================
	AXIS_STARTING:
		bBusy		:= TRUE;
		stAxisHyd.Moving	:= TRUE;
		stAxisHyd.Stopped	:= FALSE;

		// 初始化模拟位置
		SimPosition	:= stAxisHyd.ActualPosition;
		SimVelocity	:= 0.0;
		SimTorque	:= 0.0;

		// 模式选择
		CASE uiMode OF
			1: // 位置模式
				stAxisHyd.TargetPosition	:= LREAL(udiPos) / 1000.0; // 单位转换
				stAxisHyd.CommandVelocity	:= LREAL(uiSpd) / 1000.0;
				stAxisHyd.CommandPosition	:= stAxisHyd.TargetPosition;

			2: // 速度模式
				SimVelocity	:= LREAL(uiSpd) / 1000.0;

			3: // 扭矩模式
				SimTorque	:= LREAL(uiForce) / 1000.0;

			ELSE
				dwAlarmID	:= 16#0010;	// 无效模式
				bAlarm		:= TRUE;
				State		:= AXIS_ERROR;
		END_CASE

		State	:= AXIS_RUNNING;

	// ==================== 运行中 ====================
	AXIS_RUNNING:
		bBusy		:= TRUE;
		stAxisHyd.Moving	:= TRUE;
		stAxisHyd.Stopped	:= FALSE;
		stAxisHyd.InPosition	:= FALSE;

		// 急停检测
		IF bEStop AND NOT EStopOld THEN
			State	:= AXIS_ESTOPPING;
		// 停止命令
		ELSIF bStop AND NOT StopOld THEN
			State	:= AXIS_STOPPING;
		// 位置模式到位检测
		ELSIF uiMode = 1 THEN
			SimPosition	:= SimPosition + SimVelocity * 0.05; // 模拟位置变化
			stAxisHyd.ActualPosition	:= SimPosition;

			// 到位判断
			IF ABS(SimPosition - stAxisHyd.TargetPosition) <= stAxisHyd.Pos_Tolerance THEN
				State	:= AXIS_STOPPED;
			END_IF
		// 速度/扭矩模式需要外部停止
		ELSE
			// 模拟运动
			IF bDir THEN
				SimPosition	:= SimPosition + SimVelocity * 0.05;
			ELSE
				SimPosition	:= SimPosition - SimVelocity * 0.05;
			END_IF
			stAxisHyd.ActualPosition	:= SimPosition;
		END_IF

	// ==================== 停止中 ====================
	AXIS_STOPPING:
		bBusy		:= TRUE;
		SimVelocity	:= SimVelocity * 0.8; // 减速

		IF ABS(SimVelocity) < 0.001 THEN
			SimVelocity	:= 0.0;
			stAxisHyd.ActualVelocity	:= 0.0;
			State	:= AXIS_STOPPED;
		ELSE
			SimPosition	:= SimPosition + SimVelocity * 0.05;
			stAxisHyd.ActualPosition	:= SimPosition;
			stAxisHyd.ActualVelocity	:= SimVelocity;
		END_IF

	// ==================== 已停止 ====================
	AXIS_STOPPED:
		bBusy		:= FALSE;
		bDone		:= TRUE;
		stAxisHyd.Moving	:= FALSE;
		stAxisHyd.Stopped	:= TRUE;
		stAxisHyd.InPosition	:= TRUE;
		SimVelocity	:= 0.0;
		SimTorque	:= 0.0;

		// 重新检测启动
		IF NOT bStart THEN
			State	:= AXIS_IDLE;
		END_IF

	// ==================== 急停中 ====================
	AXIS_ESTOPPING:
		bBusy		:= FALSE;
		bDone		:= FALSE;
		stAxisHyd.Moving	:= FALSE;
		SimVelocity	:= 0.0;
		SimTorque	:= 0.0;
		State	:= AXIS_STOPPED;

	// ==================== 错误状态 ====================
	AXIS_ERROR:
		bBusy		:= FALSE;
		bDone		:= FALSE;
		bAlarm		:= TRUE;
		stAxisHyd.Error	:= TRUE;
		stAxisHyd.ErrorId	:= dwAlarmID;
		stAxisHyd.Moving	:= FALSE;
		SimVelocity	:= 0.0;

		// 复位检测
		IF bReset AND NOT ResetOld THEN
			dwAlarmID	:= 0;
			bAlarm		:= FALSE;
			stAxisHyd.Error	:= FALSE;
			stAxisHyd.ErrorId	:= 0;
			State	:= AXIS_RESETTING;
		END_IF

	// ==================== 复位中 ====================
	AXIS_RESETTING:
		State	:= AXIS_IDLE;

END_CASE

// 边沿检测
StartOld	:= bStart;
StopOld		:= bStop;
EStopOld	:= bEStop;
ResetOld	:= bReset;

// 实时更新状态
stAxisHyd.ControlMode	:= INT_TO_UINT(uiMode);
stAxisHyd.Ready		:= (State = AXIS_IDLE) OR (State = AXIS_STOPPED);
stAxisHyd.Faulted	:= (State = AXIS_ERROR);

// 模拟实际值更新
stAxisHyd.CommandPosition	:= SimPosition;
stAxisHyd.CommandVelocity	:= SimVelocity;
stAxisHyd.ActualVelocity	:= SimVelocity;
stAxisHyd.ActualTorque		:= SimTorque;
stAxisHyd.PowerOn	:= TRUE;
stAxisHyd.Enabled	:= NOT bEStop;

END_FUNCTION_BLOCK
