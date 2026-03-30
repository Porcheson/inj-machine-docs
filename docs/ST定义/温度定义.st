TYPE ST_EK312State :
(
	(* 状态机枚举 *)
	eState_Idle,				// 空闲状态	
	eState_Init,				// 初始化	
	eState_Heating,				// 加热中
	eState_Error				// 错误状态
);
END_TYPE



TYPE ST_EK312InSeg :
STRUCT
	
	(* 单段工艺参数 *)		
	uiSetTemp: UINT;	// 温度设定值
	uiFunc: UINT;		// 温度设定功能 0:不用 1:使用
	uiP: UINT;			// 温度设定P值
	uiD: UINT;			// 温度设定D值		
	uiMax: UINT;		// 温度设定上限
	uiMin: UINT;		// 温度设定下限	
		
END_STRUCT
END_TYPE



TYPE ST_EK312InPara :
STRUCT
		
	(* EK312输入参数 123*)
	aSeg: ARRAY[1..12] OF ST_EK312InSeg;	// 多段输入参数		
	aInputAddr: ARRAY[1..50] OF UINT;		//输入地址
	
	
    (* 配置参数 *)	
	uiStationNo: UINT;			// 站号
	uiColorSelect: UINT;		// 单双三色选择  80
	uiAColor: UINT;				// A色开选择    81
	uiBColor: UINT;				// B色开选择    82
	uiCColor: UINT;				// C色开选择    83
	uiANozMode: UINT;			// A色射咀方式    17
	uiBNozMode: UINT;			// B色射咀方式    84
	uiCNozMode: UINT;			// C色射咀方式 	  86
	uiANozPerc: UINT;			// A色射咀百分比  22	  
	uiBNozPerc: UINT;			// B色射咀百分比  85  
	uiCNozPerc: UINT;			// C色射咀百分比  87
	uiContSSR: UINT;			// 接触器和固态继电器选择    24
	uiNozCtrlCycle: UINT;		// 射咀控制周期    26
	
END_STRUCT
END_TYPE


TYPE ST_EK312OutSeg :
STRUCT
	
	(* 单段工艺参数 *)		
	uiActualTemp: UINT;		// 温度实际值	
	uiState: UINT;			// 温度状态值 0:正常 1:偏低 2:偏高 3:断线
		
END_STRUCT
END_TYPE


TYPE ST_EK312OutPara :
STRUCT	
	
	(* EK312输出参数 124*) 
	aSeg: ARRAY[1..12] OF ST_EK312OutSeg;		// 多段输出参数		
	aOutputAddr: ARRAY[1..100] OF UINT;			//输出地址
	
END_STRUCT
END_TYPE



FUNCTION_BLOCK FB_EK312
VAR_INPUT
	
	(* 控制命令 *)	
	bStart: BOOL;	// 启动	
	bStop: BOOL;	// 停止
	bReset: BOOL;	// 复位	
	
	(* 输出控制命令 *)	
	bR0:BOOL;		// R0使能 
	bR1:BOOL;		// R1使能 
	bR2:BOOL;		// R2使能 
	bR3:BOOL;		// R3使能 	

    (* 模式选择 *)	
// 	uiMode: UINT;		// 0:无模式 1: 2: 3:
		
	(* EK312输入参数 *)	
	stInPara: ST_EK312InPara;
		
END_VAR
VAR_OUTPUT
		
	(* 状态输出 *)	
	bBusy: BOOL;		// 忙状态		
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态
	
    (* 报警信息 *)		
	dwAlarmID: DWORD;		// 报警代码							
							(*	0:无 
								1000: 通讯失败
							*)	
	
	(* EK312输出参数 *)	
	stOutPara: ST_EK312OutPara;
	
    (* 加热状态输出 *)		
	uiHeatState: UINT;		// 温度加热状态  220
	
	(* 版本号 *)	
	uiVersion: UINT;		// 版本号  222
	

	
END_VAR
VAR
END_VAR
