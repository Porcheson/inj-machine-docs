//--- 1. 边沿检测 & 参数映射 ---
rTrigStart(CLK := bStart);
rTrigStop(CLK := bStop);
rTrigEStop(CLK := bEStop);
rTrigReset(CLK := bReset);

rPres := MAX(UINT_TO_REAL(uiPres), 0.0)*0.1;   //压力设定
rVel  := UINT_TO_REAL(uiSpd)*0.01*1000;  //速度设定
rPos  := UDINT_TO_REAL(udiPos)*0.01;  //位置设定
IF uiAcc = 0 THEN rAcc := 200; ELSE rAcc  := UINT_TO_REAL(uiAcc); END_IF;  
IF uiDec = 0 THEN rDec := 200; ELSE rDec  := UINT_TO_REAL(uiDec); END_IF;  
IF uiJerk = 0 THEN rJerk := 0; ELSE rJerk := UINT_TO_REAL(uiJerk); END_IF;

// 方向转换 (1:正 -> 1, 2:反 -> -1, 0 -> 0)
IF uiDir = 2 THEN iDir := -1; ELSE iDir := UINT_TO_SINT(uiDir); END_IF;
  
//--- 2. 状态机主逻辑 ---
CASE iStep OF

    0: // 初始化
        IF fbCreate.DONE THEN
            siAxisId := fbCreate.AXISID;
            iStep := 10;
        ELSIF fbCreate.ERROR THEN
            bAlarm := TRUE; dwAlarmID := 16#00000001; iStep := 900;
        END_IF;

    10: // 空闲
        bCmdExecute := FALSE; 
        IF rTrigEStop.Q THEN
            iStep := 300;
        ELSIF rTrigStop.Q THEN
            iStep := 200;
        ELSIF rTrigReset.Q AND bAlarm THEN
            iStep := 400;
        ELSIF rTrigStart.Q AND uiMode >= 1 AND uiMode <= 3 THEN
            uiActiveMode := uiMode; 
            iStep := 100;           
        END_IF;

    100: // 运行中 (Execute=1，持续保持)
        bCmdExecute := TRUE;
        
        // 1. 错误监测 (所有模式通用)
        CASE uiActiveMode OF
            1: bFBError := fbMoveAbs.ERROR; wFBErrorID := fbMoveAbs.ERRORID;
            2: bFBError := fbMoveVel.ERROR; wFBErrorID := fbMoveVel.ERRORID;
            3: bFBError := fbPresHdl.ERROR; wFBErrorID := fbPresHdl.ERRORID;
        END_CASE;
        
        IF bFBError THEN
            bAlarm := TRUE; dwAlarmID := wFBErrorID; iStep := 900;
            
        // 2. 动作完成监测 (只有位置模式才能自然完成并退出！)
        ELSIF (uiActiveMode = 1) AND fbMoveAbs.DONE THEN
            iStep := 10; // 绝对定位完成，回到空闲
            
        // 3. 强制中断监测 (通用)
        ELSIF rTrigEStop.Q THEN
            iStep := 300;
        ELSIF rTrigStop.Q THEN
            iStep := 200;
            
        // 4. 重新触发/模式切换 (通用)
        ELSIF rTrigStart.Q THEN
            IF uiMode = uiActiveMode THEN
                iStep := 105; // 同模式重触发：去过渡步拉低 Execute
            ELSIF uiMode >= 1 AND uiMode <= 3 THEN
                uiActiveMode := uiMode; // 跨模式切换：直接更改模式！(注射转保压的最优解)
            END_IF;
        END_IF;

    105: // 运行过渡步 (同模式重触发专用，仅1周期)
        bCmdExecute := FALSE; 
        iStep := 100;         

    200: // 正常停止
        IF fbStop.DONE THEN
            iStep := 10;
        ELSIF fbStop.ERROR THEN
            bAlarm := TRUE; dwAlarmID := fbStop.ERRORID; iStep := 900;
        END_IF;

    300: // 急停
        IF fbEStop.DONE OR fbEStop.ERROR THEN
            bAlarm := TRUE; dwAlarmID := 16#0000FFFF; iStep := 900;
        END_IF;

    400: // 报警复位
        IF fbReset.DONE THEN
            bAlarm := FALSE; dwAlarmID := 0; iStep := 10;
        ELSIF fbReset.ERROR THEN
            bAlarm := TRUE; dwAlarmID := fbReset.ERRORID; iStep := 900;
        END_IF;

    900: // 报警等待
        IF rTrigReset.Q THEN
            iStep := 400;
        END_IF;

END_CASE;

//--- 3. 底层 FB 统一调用区 ---
fbCreate(USE_SIMULATION := TRUE);

fbMoveAbs(
    AXISID := siAxisId, EXECUTE := (uiActiveMode = 1) AND bCmdExecute, // 只有模式匹配且执行标志为1时才为TRUE
    CONTINUOUSUPDATE := TRUE, POSITION := rPos, VELOCITY := rVel,
    ACCELERATION := rAcc, DECELERATION := rDec, JERK := rJerk, DIRECTION := iDir, BUFFERMODE := 0);

fbMoveVel(
    AXISID := siAxisId, EXECUTE := (uiActiveMode = 2) AND bCmdExecute, 
    CONTINUOUSUPDATE := TRUE, VELOCITY := rVel,
    ACCELERATION := rAcc, DECELERATION := rDec, JERK := rJerk, DIRECTION := iDir, BUFFERMODE := 0);

fbPresHdl(
    AXISID := siAxisId, EXECUTE := (uiActiveMode = 3) AND bCmdExecute, 
    CONTINUOUSUPDATE := TRUE, PRESSURE := rPres, PRESSURERAMPRATE := rAcc, DURATION := 0.0, BUFFERMODE := 0);

fbStop(AXISID := siAxisId, EXECUTE := (iStep = 200), DECELERATION := rDec);
fbEStop(AXISID := siAxisId, EXECUTE := (iStep = 300), DECELERATION := 99999.0);
fbReset(AXISID := siAxisId, EXECUTE := (iStep = 400));

fbReadFB(AXISID := siAxisId, ENABLE := TRUE);
IF fbReadFB.VALID THEN
    rPosition  := fbReadFB.POSITION;
    rVeloctity := fbReadFB.VELOCITY;
    rFlow      := fbReadFB.FLOW;
    rPerssure  := fbReadFB.PRESSURE;
END_IF;
//--- 4. 状态输出汇总 (严格遵循接口定义) ---
IF iStep = 10 THEN
    bBusy := FALSE; bDone := TRUE;  // 无命令且健康
ELSIF iStep = 100 OR iStep = 105 THEN
    bBusy := TRUE;  // 仍有执行命令
    bDone := FALSE; // 未完成(注：上位机若需判断是否到达目标压力/速度，应取 fbPresHdl.INPRESSURE 等变量)
    bInVelocity := fbMoveVel.INVELOCITY;
    bInPressure := fbPresHdl.INPRESSURE;
ELSIF iStep = 200 THEN
    bBusy := fbStop.BUSY; bDone := FALSE;
ELSIF iStep = 300 THEN
    bBusy := TRUE; bDone := FALSE;
ELSIF iStep = 400 THEN
    bBusy := fbReset.BUSY; bDone := FALSE;
ELSE // 900 等
    bBusy := FALSE; bDone := FALSE;
END_IF;
