TYPE E_EjectState :
(
    (* 状态机枚举 *)
	eState_Idle,				// 空闲状态	
	eState_Init,				// 初始化	
	eState_EjectIning,			// 托模进中(3段)
	eState_EjectIned,			// 托模进完成	
	eState_EjectKeeping,		// 托模保持中
	eState_EjectKept,			// 托模保持完成	
	eState_EjectOuting,			// 托模退中(3段)	
	eState_EjectOuted,			// 托模退完成	
	eState_Error				// 错误状态
	
);
END_TYPE


TYPE ST_EjectSeg :
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


TYPE ST_EjectPara :
STRUCT

	(* 托模进工艺参数 28*)
	uiEjectInSegCnt: UINT;							// 托模进段数选择
	uiEjectInMode: UINT;							// 托模进方式选择 0:时间  1:行程  2:位置
	uiEjectInLimitTime: UINT;						// 托模进限制时间
	aEjectInSeg: ARRAY[1..3] OF ST_EjectSeg;		// 托模进多段设定参数

	uiEjectInPresStartGrad: UINT;				// 压力启动斜率
	uiEjectInPresStopGrad: UINT;				// 压力停止斜率
	uiEjectInSpdStartGrad: UINT;				// 速度启动斜率
	uiEjectInSpdStopGrad: UINT;					// 速度停止斜率


	(* 托模保持工艺参数 7*)
	stEjectKeepSeg: ST_EjectSeg;		// 托模保持设定参数


	(* 托模退工艺参数 28*)
	uiEjectOutSegCnt: UINT;							// 托模退段数选择
	uiEjectOutMode: UINT;							// 托模退方式选择 0:时间  1:行程  2:位置
	uiEjectOutLimitTime: UINT;						// 托模退限制时间
	aEjectOutSeg: ARRAY[1..3] OF ST_EjectSeg;		// 托模退多段设定参数

	uiEjectOutPresStartGrad: UINT;				// 压力启动斜率
	uiEjectOutPresStopGrad: UINT;				// 压力停止斜率
	uiEjectOutSpdStartGrad: UINT;				// 速度启动斜率
	uiEjectOutSpdStopGrad: UINT;					// 速度停止斜率

	(* 托模调试模式参数（调模状态下使用） *)
	stEjectInDbgSeg: ST_EjectSeg;				// 托模进调试段参数
	stEjectOutDbgSeg: ST_EjectSeg;				// 托模退调试段参数

END_STRUCT
END_TYPE



VAR_IN_OUT
	stEjectAxis: ST_AxisRefHyd;
END_VAR
VAR_INPUT
	
    (* 控制命令 *)		
	bStart: BOOL;				// 启动	
	bStop: BOOL;				// 停止(有减速停)		
	bEStop: BOOL;				// 急停(立即停止，无减速停)	
	bReset: BOOL;				// 复位	
	
    (* 模式选择 *)	
	uiEjectMode: UINT;		// 0:无模式 1:托模进模式 2:托模退模式 3:定次 4:震动 5:停留 6:托模进(调试模式) 7:托模退(调试模式)
	
	(* 上位机设定参数输入 *)	
	stEjectPara: ST_EjectPara;
	
	(* 数字信号输入 *)	
	bEjectInStop: BOOL;			// 托模进停止
	bEjectOutStop: BOOL;		// 托模退停止		
	
	(* 模拟信号输入 *)	
	udiEjectElecRulerVal: UDINT;			// 托模电子尺值			
	
END_VAR
VAR_OUTPUT
		
	(* 状态输出 *)	
	bBusy: BOOL;		// 忙状态		
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态
	
    (* 报警信息 *)
	dwAlarmID: DWORD;		// 报警代码（按位标识，可同时报告多个报警）
							(*	Bit0(1):   托模进超时
								Bit1(2):   托模退超时
								Bit2(4):   位置超限
								Bit3(8):   传感器异常
								...其他位预留
								例：dwAlarmID=3 表示"托模进超时+托模退超时"同时发生
							*)

    (* 动作提示 *)		
	uiActHint: UINT;		// 当前动作状态 
							(*	0:无动作	1:报警状态	  2:托模进完成  3:托模退完成   4:托模保持
								10: 		11:托模进1段  12:托模进2段	13: 托模进3段 
								20:			21:托模退1段  22:托模退2段  23: 托模退3段
							*)
	uiActTime: UINT;		// 当前动作运行时间
		
	(* 动作状态输出 *)		
	bEjectIned: BOOL;		// 托模进完成	
	bEjectOuted: BOOL;		// 托模退完成
	
    (* 控制命令输出 *)		
	uiPresCmd: UINT;		// 压力命令输出
	uiSpdCmd: UINT;			// 速度命令输出
	udiPosCmd: UDINT;		// 位置命令输出	
	
	
END_VAR



TYPE E_EjectModeState :
(
    (* 状态机枚举 *)
	eState_Idle,				// 空闲状态	
	eState_Init,				// 初始化		
	eState_EjectCount,			// 定次
	eState_EjectVibra,			// 震动		
	eState_EjectHold,			// 停留		
	eState_Error				// 错误状态
	
);
END_TYPE


FUNCTION_BLOCK FB_EjectMode
VAR_IN_OUT
	stEjectAxis: ST_AxisRefHyd;
END_VAR
VAR_INPUT
		
		
    (* 控制命令 *)		
	bStart: BOOL;				// 启动	
	bStop: BOOL;				// 停止(有减速停)		
	bEStop: BOOL;				// 急停(立即停止，无减速停)	
	bReset: BOOL;				// 复位	
	
    (* 模式选择 *)	
	uiEjectMode: UINT;		// 0:无模式 1:定次模式 2:震动模式 3:停留模式
	
	(* 上位机设定参数输入 *)	
	uiEjectTimes: UINT;						// 托模次数  
	stEjectPara: ST_EjectPara;
	
	(* 数字信号输入 *)	
	bEjectInStop: BOOL;			// 托模进停止
	bEjectOutStop: BOOL;		// 托模退停止		
	
	(* 模拟信号输入 *)	
	udiEjectElecRulerVal: UDINT;			// 托模电子尺值			
	
END_VAR
VAR_OUTPUT
			
	(* 状态输出 *)	
	bBusy: BOOL;		// 忙状态		
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态
	
    (* 报警信息 *)
	dwAlarmID: DWORD;		// 报警代码（按位标识，可同时报告多个报警）
							(*	Bit0(1):   托模进超时
								Bit1(2):   托模退超时
								Bit2(4):   位置超限
								Bit3(8):   传感器异常
								...其他位预留
								例：dwAlarmID=3 表示"托模进超时+托模退超时"同时发生
							*)

    (* 动作提示 *)		
	uiActHint: UINT;		// 当前动作状态 
							(*	0:无动作	1:报警状态	  2:托模进完成  3:托模退完成   4:托模保持
								10: 		11:托模进1段  12:托模进2段	13: 托模进3段 
								20:			21:托模退1段  22:托模退2段  23: 托模退3段
							*)
	uiActTime: UINT;		// 当前动作运行时间
		
	(* 动作状态输出 *)		
	bEjectIned: BOOL;		// 托模进完成	
	bEjectOuted: BOOL;		// 托模退完成
	
    (* 控制命令输出 *)		
	uiPresCmd: UINT;		// 压力命令输出
	uiSpdCmd: UINT;			// 速度命令输出
	udiPosCmd: UDINT;		// 位置命令输出	
	
END_VAR
VAR
	EjectIn: FB_Eject;
	EjectOut: FB_Eject;
END_VAR