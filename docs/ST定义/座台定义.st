

TYPE E_NozzleState :
(
    (* 状态机枚举 *)
	eState_Idle,				// 空闲状态	
	eState_Init,				// 初始化	
	eState_NozzleIning,			// 座台进中(2段)
	eState_NozzleIned,			// 座台进完成	
	eState_NozzleOuting,		// 座台退中(2段)	
	eState_NozzleOuted,			// 座台退完成	
	eState_Error				// 错误状态
	
);
END_TYPE


TYPE ST_NozzleSeg :
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


TYPE ST_NozzlePara :
STRUCT


	(* 座台进工艺参数 21*)
	uiNozzleInSegCnt: UINT;							// 座台进段数选择
	uiNozzleInMode: UINT;							// 座台进方式选择 0:时间  1:行程  2:位置
	uiNozzleInLimitTime: UINT;						// 座台进限制时间
	aNozzleInSeg: ARRAY[1..2] OF ST_NozzleSeg;		// 座台进多段设定参数

	uiNozzleInPresStartGrad: UINT;				// 压力启动斜率
	uiNozzleInPresStopGrad: UINT;				// 压力停止斜率
	uiNozzleInSpdStartGrad: UINT;				// 速度启动斜率
	uiNozzleInSpdStopGrad: UINT;				// 速度停止斜率


	(* 座台退工艺参数 21*)
	uiNozzleOutSegCnt: UINT;							// 座台退段数选择
	uiNozzleOutMode: UINT;							// 座台退方式选择 0:时间  1:行程  2:位置
	uiNozzleOutLimitTime: UINT;						// 座台退限制时间
	aNozzleOutSeg: ARRAY[1..2] OF ST_NozzleSeg;		// 座台退多段设定参数

	uiNozzleOutPresStartGrad: UINT;				// 压力启动斜率
	uiNozzleOutPresStopGrad: UINT;				// 压力停止斜率
	uiNozzleOutSpdStartGrad: UINT;				// 速度启动斜率
	uiNozzleOutSpdStopGrad: UINT;				// 速度停止斜率

	(* 座台调试模式参数（调模状态下使用） *)
	stNozzleInDbgSeg: ST_NozzleSeg;				// 座台进调试段参数
	stNozzleOutDbgSeg: ST_NozzleSeg;			// 座台退调试段参数

END_STRUCT
END_TYPE




VAR_IN_OUT
	stNozzleAxis: ST_AxisRefHyd;
END_VAR
VAR_INPUT
	
    (* 控制命令 *)		
	bStart: BOOL;				// 启动	
	bStop: BOOL;				// 停止(有减速停)		
	bEStop: BOOL;				// 急停(立即停止，无减速停)	
	bReset: BOOL;				// 复位	
	
    (* 模式选择 *)	
	uiNozzleMode: UINT;		// 0:无模式 1:座台进模式 2:座台退模式 3:座台进(调试模式) 4:座台退(调试模式)
	
	(* 上位机设定参数输入 *)	
	stNozzlePara: ST_NozzlePara;
	
	(* 数字信号输入 *)	
	bNozzleInStop: BOOL;			// 座台进停止
	bNozzleOutStop: BOOL;			// 座台退停止		
	
	(* 模拟信号输入 *)	
	udiNozzleElecRulerVal: UDINT;			// 座台电子尺值			
	
END_VAR
VAR_OUTPUT
		
	(* 状态输出 *)	
	bBusy: BOOL;		// 忙状态		
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态
	
    (* 报警信息 *)
	uiAlarmID: DWORD;		// 报警代码（按位标识，可同时报告多个报警）
							(*	Bit0(1):   座台进超时
								Bit1(2):   座台退超时
								Bit2(4):   位置超限
								Bit3(8):   传感器异常
								...其他位预留
							*)

    (* 动作提示 *)		
	uiActHint: UINT;		// 当前动作状态 
							(*	0:无动作	1:报警状态	  2:座台进完成  3:座台退完成
								10: 		11:座台进1段  12:座台进2段	13: 
								20:			21:座台退1段  22:座台退2段  23: 
							*)
	uiActTime: UINT;		// 当前动作运行时间
		
	(* 动作状态输出 *)		
	bNozzleIned: BOOL;		// 座台进完成	
	bNozzleOuted: BOOL;		// 座台退完成
	
    (* 控制命令输出 *)		
	uiPresCmd: UINT;		// 压力命令输出
	uiSpdCmd: UINT;			// 速度命令输出
	udiPosCmd: UDINT;		// 位置命令输出	
	
	
END_VAR

