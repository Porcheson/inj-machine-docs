TYPE E_CoreState :
(
    (* 状态机枚举 *)
	eState_Idle,				// 空闲状态	
	eState_Init,				// 初始化		
	eState_CoreIning,			// 中子进中
	eState_CoreIned,			// 中子进完成
	eState_CoreOuting,			// 中子退中	
	eState_CoreOuted,			// 中子退完成	
	eState_Error				// 错误状态
	
);
END_TYPE


TYPE ST_CoreSeg :
STRUCT
		
	(* 单段工艺参数 *)	
	uiPres: UINT;			// 设定压力
	uiSpd: UINT;			// 设定速度
	uiTime: UINT;			// 设定停止时间	
	uiCount: UINT;			// 设定停止计数
	
END_STRUCT
END_TYPE




TYPE ST_CorePara :
STRUCT

	(* 中子进工艺参数 14*)
	uiCoreInStartMode: UINT;		// 中子进开始方式 0:行程 1:位置
	uiCoreInStroke: UINT;			// 中子进开始行程
	udiCoreInPos: UDINT;			// 中子进开始位置
	uiCoreInStopMode: UINT;			// 中子进停止方式 0:时间 1:行程 2:计数
	uiCoreInLimitTime: UINT;		// 中子进限制时间
	stCoreInSeg: ST_CoreSeg;		// 中子进设定参数

	uiCoreInPresStartGrad: UINT;			// 压力启动斜率
	uiCoreInPresStopGrad: UINT;				// 压力停止斜率
	uiCoreInSpdStartGrad: UINT;				// 速度启动斜率
	uiCoreInSpdStopGrad: UINT;				// 速度停止斜率


	(* 中子退工艺参数 14*)
	uiCoreOutStartMode: UINT;		// 中子退开始方式 0:行程 1:位置
	uiCoreOutStroke: UINT;			// 中子退开始行程
	udiCoreOutPos: UDINT;			// 中子退开始位置
	uiCoreOutStopMode: UINT;		// 中子退停止方式 0:时间 1:行程 2:计数
	uiCoreOutLimitTime: UINT;		// 中子退限制时间
	stCoreOutSeg: ST_CoreSeg;		// 中子退设定参数

	uiCoreOutPresStartGrad: UINT;			// 压力启动斜率
	uiCoreOutPresStopGrad: UINT;			// 压力停止斜率
	uiCoreOutSpdStartGrad: UINT;			// 速度启动斜率
	uiCoreOutSpdStopGrad: UINT;				// 速度停止斜率

	(* 中子调试模式参数（调模状态下使用） *)
	stCoreInDbgSeg: ST_CoreSeg;				// 中子进调试段参数
	stCoreOutDbgSeg: ST_CoreSeg;			// 中子退调试段参数

END_STRUCT
END_TYPE

FUNCTION_BLOCK FB_Core
VAR_IN_OUT
	stCoreAxis: ST_AxisRefHyd;
END_VAR
VAR_INPUT
	
    (* 控制命令 *)		
	bStart: BOOL;				// 启动	
	bStop: BOOL;				// 停止(有减速停)		
	bEStop: BOOL;				// 急停(立即停止，无减速停)	
	bReset: BOOL;				// 复位	
	
    (* 模式选择 *)	
	uiCoreMode: UINT;		// 0:无模式 1:中子进模式 2:中子退模式 3:中子进(调试模式) 4:中子退(调试模式)
	
	(* 上位机设定参数输入 *)	
	stCorePara: ST_CorePara;
	
	(* 数字信号输入 *)	
	bCoreInStop: BOOL;			// 中子进停止
	bCoreOutStop: BOOL;			// 中子退停止		
	
	(* 模拟信号输入 *)			
	
END_VAR
VAR_OUTPUT
		
	(* 状态输出 *)	
	bBusy: BOOL;		// 忙状态		
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态
	
    (* 报警信息 *)
	uiAlarmID: DWORD;		// 报警代码（按位标识，可同时报告多个报警）
							(*	Bit0(1):   中子进超时
								Bit1(2):   中子退超时
								Bit2(4):   位置超限
								Bit3(8):   传感器异常
								...其他位预留
							*)

    (* 动作提示 *)		
	uiActHint: UINT;		// 当前动作状态 
							(*	0:无动作	1:报警状态	  2:中子进完成  3:中子退完成
								10: 		11:中子进1段  12:			13:  
								20:			21:中子退1段  22:  			23: 
							*)
	uiActTime: UINT;		// 当前动作运行时间
		
	(* 动作状态输出 *)		
	bCoreIned: BOOL;		// 中子进完成	
	bCoreOuted: BOOL;		// 中子退完成
	
    (* 控制命令输出 *)		
	uiPresCmd: UINT;		// 压力命令输出
	uiSpdCmd: UINT;			// 速度命令输出
	udiPosCmd: UDINT;		// 位置命令输出	
	
	
END_VAR





