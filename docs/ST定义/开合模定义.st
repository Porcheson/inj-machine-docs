(*
 * 文件: 开合模定义.st
 * 版本: V1.1
 *
 * 版本历史:
 * V1.0  2026-03-27  初始版本
 * V1.1  2026-04-02  新增调试模式支持(stOpenDebug/stCloseDebug)
 *
 * 说明: 开合模机构控制的功能块和数据结构定义
 *)

TYPE E_AxisState :
(
	Idle,				// 空闲状态
	Running,				// 运行状态
	Stop					// 停止状态
);
END_TYPE

TYPE E_ClampState :
(
	(* 状态机枚举 *)
	eState_Idle,				// 空闲状态
	eState_Init,				// 初始化
	eState_OpenUnload,			// 开模卸荷
	eState_Opening,				// 开模中(5段)
	eState_Opened,				// 开模完成
	eState_Closing,				// 合模中(3段)
	eState_Closed,				// 合模完成
	eState_CloseLowPress,		// 合模低压
	eState_CloseHighPress,		// 合模高压
	eState_Error				// 错误状态
);
END_TYPE


TYPE ST_PumpRequest :
STRUCT
	bRequest: BOOL;			// 泵请求
	rFlowSet: LREAL;		// 流量设定
	rPressureSet: LREAL;	// 压力设定
END_STRUCT
END_TYPE


TYPE ST_AxisRefHyd :
STRUCT
	(* 静态参数 *)
	bActive: BOOL;					// 轴是否激活
	eAxisState: E_AxisState;		// 轴状态
	nAxisID: INT;					// 轴ID号
	rMaxCylinderStroke: LREAL;		// 最大油缸行程
	rMaxVelocity: LREAL;			// 最大速度
	rMaxPressure: LREAL;			// 最大压力

	(* 运行设定值 *)
	rSetPosition: LREAL;				// 目标位置
	rSetVelocity: LREAL;			// 目标速度
	rSetPressure: LREAL;			// 目标压力

	(* 运行实际值 *)
	rActualPosition: LREAL;			// 实际位置
	rActualVelocity: LREAL;			// 实际速度
	rActualPressure: LREAL;			// 实际压力

	(* 泵请求 *)
	stPumpRequest: ST_PumpRequest;	// 向泵发送的请求

	(* 故障信息 *)
	nFaultCode: INT;					// 故障码
END_STRUCT
END_TYPE


TYPE ST_ClampSeg :
STRUCT

	(* 单段工艺参数 *)
	uiPres: UINT;		// 设定压力
	uiSpd: UINT;		// 设定速度
	udiPos: UDINT;		// 设定位置
	uiTime: UINT;		// 设定时间
	uiPresGrad: UINT;	// 设定压力斜率
	uiSpdGrad: UINT;	// 设定速度斜率

END_STRUCT
END_TYPE


TYPE ST_ClampPara :
STRUCT

	(* 开模工艺参数 *)
	uiOpenSegCnt: UINT;							// 开模段数选择 (1-5段)
	uiOpenMode: UINT;							// 开模方式选择 0:电子尺  1:行程
	uiOpenLimitTime: UINT;						// 开模限制时间
	stOpenUnloadPres: ST_ClampSeg;				// 开模卸荷设定参数
	aOpenSeg: ARRAY[1..5] OF ST_ClampSeg;		// 开模多段设定参数

	uiOpenPresStartGrad: UINT;					// 开模压力启动斜率
	uiOpenPresStopGrad: UINT;					// 开模压力停止斜率
	uiOpenSpdStartGrad: UINT;					// 开模速度启动斜率
	uiOpenSpdStopGrad: UINT;					// 开模速度停止斜率

	(* 合模工艺参数 *)
	uiCloseSegCnt: UINT;							// 合模段数选择 (1-3段)
	uiCloseMode: UINT;							// 合模方式选择 0:电子尺  1:行程
	uiCloseLimitTime: UINT;						// 合模限制时间
	uiCloseLowPresLimitTime: UINT;					// 合模低压保护时间
	uiCloseEndMode: UINT;							// 合模终止方式选择 0:时间 1:行程 2:压力
	uiCloseEndHighPres: UINT;						// 合模高压压力
	aCloseSeg: ARRAY[1..3] OF ST_ClampSeg;		// 合模多段设定参数
	stCloseLowPres: ST_ClampSeg;					// 合模低压设定参数
	stCloseHighPres: ST_ClampSeg;					// 合模高压设定参数

	uiClosePresStartGrad: UINT;					// 合模压力启动斜率
	uiClosePresStopGrad: UINT;					// 合模压力停止斜率
	uiCloseSpdStartGrad: UINT;					// 合模速度启动斜率
	uiCloseSpdStopGrad: UINT;					// 合模速度停止斜率

	(* 调试模式参数（调模状态下使用） *)
	stOpenDebug: ST_ClampSeg;					// 开模调试参数
	stCloseDebug: ST_ClampSeg;					// 合模调试参数

	(* 中子控制参数 *)
	aCoreFn: ARRAY[1..8] OF UINT;				// 中子功能 0:不使用 1:使用
	aCoreInMode: ARRAY[1..8] OF UINT;			// 中子进开始方式 0:行程 1:位置
	aCoreInStroke: ARRAY[1..8] OF UINT;		// 中子进开始行程
	aCoreInPos: ARRAY[1..8] OF UDINT;			// 中子进开始位置
	aCoreOutMode: ARRAY[1..8] OF UINT;			// 中子退开始方式 0:行程 1:位置
	aCoreOutStroke: ARRAY[1..8] OF UINT;		// 中子退开始行程
	aCoreOutPos: ARRAY[1..8] OF UDINT;			// 中子退开始位置

END_STRUCT
END_TYPE


FUNCTION_BLOCK FB_Clamp
VAR_IN_OUT
	ClampAxis: ST_AxisRefHyd;
END_VAR
VAR_INPUT

	(* 控制命令 *)
	bStart: BOOL;				// 启动
	bStop: BOOL;				// 停止(有减速停)
	bEStop: BOOL;				// 急停(立即停止，无减速停)
	bReset: BOOL;				// 复位

	(* 模式选择 *)
	uiClampMode: UINT;			// 0:无模式 1:开模模式 2:合模模式 3:开模(调试模式) 4:合模(调试模式)

	(* 上位机设定参数输入 *)
	stClampPara: ST_ClampPara;

	(* 数字信号输入 *)
	bOpenStop: BOOL;				// 开模停止
	bCloseLowPres: BOOL;			// 合模低压
	bCloseHighPres: BOOL;			// 合模高压
	bCloseStop: BOOL;				// 合模停止

	(* 模拟信号输入 *)
	udiClampElecRulerVal: UDINT;			// 锁模电子尺值
	uiClampPresElecRulerVal: UINT;			// 锁模压力值

END_VAR
VAR_OUTPUT

	(* 状态输出 *)
	bBusy: BOOL;		// 忙状态
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态

	(* 报警信息 *)
	dwAlarmID: DWORD;		// 报警代码（按位标识，可同时报告多个报警）
							(*	Bit0(1):   低压保护超时
								Bit1(2):   开模超时
								Bit2(4):   合模超时
								Bit3(8):   位置超限
								Bit4(16):  传感器异常
								...其他位预留
							*)

	(* 动作提示 *)
	uiActHint: UINT;		// 当前动作状态
							(*	0:无动作	1:报警状态	2:开模完成  3:合模完成  4:中子执行
								10:开模卸荷	11:开模1段  12:开模2段	13:开模3段  14:开模4段  15:开模5段
								21:合模1段	22:合模2段  23:合模3段
								30:合模低压	31:合模高压
								40:开模调试	41:合模调试
							*)
	uiActTime: UINT;		// 当前动作运行时间
	bMoldOpened: BOOL;		// 开模完成
	bMoldClosed: BOOL;		// 合模完成
	aCoreAllow: ARRAY[1..8] OF BOOL;		// 中子允许信号（1..8组）

	(* 输出命令 *)
	uiPresCmd: UINT;		// 压力命令输出
	uiSpdCmd: UINT;		// 速度命令输出
	udiPosCmd: UDINT;		// 位置命令输出

END_VAR