VAR_IN_OUT
 stAxisRef : ST_HydAxisRef;
END_VAR

VAR_INPUT
 bStart : BOOL;
 bStop : BOOL;
 bEStop : BOOL;
 bReset : BOOL;
 uiDir : UINT; // 0:无效 1:正向 2:反向 
 uiMode : UINT; // 0:无效 1:位置 2:速度 3:压力 
 uiPres : UINT;
 uiSpd : UINT;
 udiPos : UDINT;
 uiForce : UINT;
 uiAcc : UINT;
 uiDec : UINT;
 uiJerk : UINT;
END_VAR

VAR_OUTPUT
 bBusy : BOOL; // TRUE=轴层当前仍保持有效执行命令 
 bDone : BOOL; // TRUE=轴层当前未执行命令且状态健康，可视为本拍已完成 
 bInVelocity : BOOL;
 bInPressure : BOOL;
 bAlarm : BOOL;
 dwAlarmID : DWORD;
END_VAR

VAR
 iStep : INT; // 0初始化, 10空闲, 100运行, 105运行过渡, 200停止, 300急停, 400复位, 900报警 
 fbCreate : HYD_CreateMotion;
 fbMoveAbs : HYD_MoveAbsolute;
 fbMoveVel : HYD_MoveVelocity;
 fbPresHdl : HYD_PressureHandle;
 fbStop : HYD_Stop;
 fbEStop : HYD_Stop;
 fbReset : HYD_Reset;
 fbReadFB : HYD_ReadSimFeedback;
 siAxisId : SINT;
 rTrigStart : R_TRIG;
 rTrigStop : R_TRIG;
 rTrigEStop : R_TRIG;
 rTrigReset : R_TRIG;
 rTrigDone : R_TRIG;
 uiActiveMode : UINT; // 当前执行模式 (1:Pos, 2:Vel, 3:Pres) 
 bCmdExecute : BOOL; // 统一控制当前活跃模式的 Execute 引脚 
 rPos : REAL;
 rVel : REAL;
 rPres : REAL;
 rAcc : REAL;
 rDec : REAL;
 rJerk : REAL;
 bFBError : BOOL;
 wFBErrorID : WORD;
 iDir : SINT;
 iDoneCnt : INT := 0;
 MaxSpeed : REAL; // 单位mm/s 
END_VAR

