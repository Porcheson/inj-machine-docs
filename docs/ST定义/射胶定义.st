TYPE E_InjectState :
(
    (* 状态机枚举 *)
	eState_Idle,				// 空闲状态	
	eState_Init,				// 初始化	
	eState_Injecting,			// 射出中(10段)	
	eState_Injected,			// 射出完成	
	eState_Holding,				// 保压中(8段)	
	eState_Held,				// 保压完成		
	eState_SuckBacking,			// 射退中	
	eState_SuckBacked,			// 射退完成	
	eState_Error				// 错误状态
);
END_TYPE


TYPE ST_InjectSeg :
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


TYPE ST_HoldSeg :
STRUCT
	
	(* 单段工艺参数 *)	
	uiPres: UINT;		// 设定压力
	uiSpd: UINT;		// 设定速度
	uiTime: UINT;		// 设定时间	
	
END_STRUCT
END_TYPE

TYPE ST_InjectPara :
STRUCT
		
	(* 射出多段工艺参数 79*)
	uiInjSegCnt: UINT;						// 射出段数选择   
	uiInjMode: UINT;						// 射出方式选择 0:电子尺  1:行程  2:时间
	uiInjTotalTime: UINT;					// 射出总时间
	uiInjToHoldMode: DWORD;					// 转保压方式（按位组合：Bit0时间 Bit1压力 Bit2位置）
 	uiInjToHoldPres: UINT;					// 转保压压力阈值
	uiInjToHoldPos: UINT;					// 转保压位置阈值
	uiInjToHoldTime: UINT;					// 转保压时间阈值
	aInjSeg: ARRAY[1..10] OF ST_InjectSeg;	// 射出多段设定参数
	
	uiInjPresStartGrad: UINT;				// 压力启动斜率
	uiInjPresStopGrad: UINT;				// 压力停止斜率
	uiInjSpdStartGrad: UINT;				// 速度启动斜率
	uiInjSpdStopGrad: UINT;					// 速度停止斜率
	
			
	(* 保压多段工艺参数 25*)
	uiHoldSegCnt: UINT;							// 保压段数选择   
	aHoldSeg: ARRAY[1..8] OF ST_HoldSeg;		// 保压多段设定参数
	
		
	(* 射退工艺参数 12*)
	uiSuckBackMode: UINT;						// 射退方式选择 0:电子尺  1:时间(时间为0,走行程开关)  
	stSuckBackSeg: ST_InjectSeg;				// 射退设定参数
	
	uiSuckBackPresStartGrad: UINT;				// 压力启动斜率
	uiSuckBackPresStopGrad: UINT;				// 压力停止斜率
	uiSuckBackSpdStartGrad: UINT;				// 速度启动斜率
	uiSuckBackSpdStopGrad: UINT;				// 速度停止斜率
		
	
END_STRUCT
END_TYPE


FUNCTION_BLOCK FB_Inject
VAR_IN_OUT
	stInjectAxis: ST_AxisRefHyd;
END_VAR
VAR_INPUT
	
    (* 控制命令 *)		
	bStart: BOOL;				// 启动	
	bStop: BOOL;				// 停止(有减速停)		
	bEStop: BOOL;				// 急停(立即停止，无减速停)	
	bReset: BOOL;				// 复位	
	
    (* 模式选择 *)	
	uiInjectMode: UINT;		// 0:无模式 1:射出模式 2:射退模式
	
	(* 上位机设定参数输入 *)	
	stInjectPara: ST_InjectPara;
	
	(* 数字信号输入 *)	
	bInjSeg1Stop: BOOL;			// 二级射出     射出1段结束	
	bInjSeg2Stop: BOOL;			// 三级射出     射出2段结束
	bInjStop: BOOL;				// 射出停止
	bSuckBackStop: BOOL;		// 射退停止		
	
	(* 模拟信号输入 *)	
	udiInjElecRulerVal: UDINT;			// 射胶电子尺值			
	
END_VAR
VAR_OUTPUT
		
	(* 状态输出 *)	
	bBusy: BOOL;		// 忙状态		
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态
    (* 报警信息 *)
	uiAlarmID: DWORD;		// 报警代码（按位标识，可同时报告多个报警）
							(*	Bit0(1):   射出超时
								Bit1(2):   保压超时
								Bit2(4):   射退超时
								Bit3(8):   位置超限
								...其他位预留
							*)

    (* 动作提示 *)		
	uiActHint: UINT;		// 当前动作状态 
							(*	0:无动作	1:报警状态	2:射出完成  3:保压完成	4:射退完成 5:射退中   6:		 7:射出10段
								10: 		11:射出1段  12:射出2段	13:射出3段  14:射出4段 15:射出5段 16:射出6段 17:射出7段 18:射出8段 19:射出9段
								20:			21:保压1段  22:保压2段  23:保压3段  24:保压4段 25:保压5段 26:保压6段 27:保压7段 28:保压8段 
							*)
	uiActTime: UINT;		// 当前动作运行时间
		
	(* 动作状态输出 *)		
	bInjected: BOOL;		// 射出完成	
	bHeld: BOOL;			// 保压完成	
	bSuckBacked: BOOL;		// 射退完成
	
    (* 控制命令输出 *)		
	uiPresCmd: UINT;		// 压力命令输出
	uiSpdCmd: UINT;			// 速度命令输出
	udiPosCmd: UDINT;		// 位置命令输出	
	

END_VAR





