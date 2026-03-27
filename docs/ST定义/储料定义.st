TYPE E_MeterState :
(
    (* 状态机枚举 *)
	eState_Idle,				// 空闲状态	
	eState_Init,				// 初始化	
	eState_Metering,			// 储料中(8段)	
	eState_Metered,				// 储料完成	
	eState_Error				// 错误状态
	
);
END_TYPE


TYPE ST_MeterSeg :
STRUCT
	
	(* 单段工艺参数 *)	
	uiSPres: UINT;		// 设定压力	
	uiBackPres: UINT;	// 设定背压
	uiSpd: UINT;		// 设定速度
	udiPos: UDINT;		// 设定位置
	uiPresGrad: UINT;	// 设定压力斜率
	uiSpdGrad: UINT;	// 设定速度斜率
	
END_STRUCT
END_TYPE


TYPE ST_MeterPara :
STRUCT
					
	(* 储料工艺参数 71*)
	uiMeterSegCnt: UINT;						// 储料段数选择	
	uiMeterMode: UINT;							// 储料退方式选择 0:电子尺  1:行程
	uiMeterLimitTime: UINT;						// 储料限制时间
	aMeterSeg: ARRAY[1..8] OF ST_MeterSeg;		// 储料多段设定参数
	
	uiMeterPresStartGrad: UINT;			// 压力启动斜率
	uiMeterPresStopGrad: UINT;			// 压力停止斜率
	uiMeterSpdStartGrad: UINT;			// 速度启动斜率
	uiMeterSpdStopGrad: UINT;			// 速度停止斜率	
	
END_STRUCT
END_TYPE


FUNCTION_BLOCK FB_Meter
VAR_IN_OUT
	stMeterAxis: ST_AxisRefHyd;
END_VAR
VAR_INPUT		
		
    (* 控制命令 *)		
	bStart: BOOL;				// 启动	
	bStop: BOOL;				// 停止(有减速停)		
	bEStop: BOOL;				// 急停(立即停止，无减速停)	
	bReset: BOOL;				// 复位	
	
    (* 模式选择 *)	
// 	uiMeterMode: UINT;		// 0:无模式 1: 2: 3:
	
	(* 上位机设定参数输入 *)	
	stMeterPara: ST_MeterPara;
	
	(* 数字信号输入 *)	
	bMeterStop: BOOL;			// 储料停止	
	
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
							(*	Bit0(1):   储料超时
								Bit1(2):   位置超限
								...其他位预留
							*)

    (* 动作提示 *)		
	uiActHint: UINT;		// 当前动作状态 
							(*	0:无动作  1:报警状态  2:储料完成    3:   
								10: 	  11:储料1段  12:储料2段	13: 储料3段  14:储料4段    15:储料5段  16: 储料6段  17:储料7段   18:储料8段
							*)
	uiActTime: UINT;		// 当前动作运行时间
		
	(* 动作状态输出 *)		
	bMetered: BOOL;				//储料完成
	
    (* 控制命令输出 *)		
	uiPresCmd: UINT;		// 压力命令输出
	uiBackPresCmd: UINT;	// 背压命令输出
	uiSpdCmd: UINT;			// 速度命令输出
	udiPosCmd: UDINT;		// 位置命令输出	
	
END_VAR






