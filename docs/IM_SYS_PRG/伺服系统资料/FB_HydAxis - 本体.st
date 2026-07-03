//--- 1. 边沿检测 & 参数映射 ---
rTrigStart(CLK := bStart);
rTrigStop(CLK := bStop);
rTrigEStop(CLK := bEStop);
rTrigReset(CLK := bReset);
// 将Done检测移出CASE，确保全周期扫描，不错过InEndVelocity的上升沿
rTrigDone(CLK := fbMoveContAbs.InEndVelocity); 

rMaxSpeed := 1000.00;
rPres := MAX(UINT_TO_REAL(uiPres), 0.0)*0.1;   //压力设定
rVel  := UINT_TO_REAL(uiSpd)*0.1*0.01*rMaxSpeed;  //速度设定
rEndVel := UINT_TO_REAL(uiEndSpd)*0.1*0.01*rMaxSpeed;  //终点速度，连续轨迹关键：设定终点速度等于最大速度，实现"到位不停车"或平滑过渡
rPos  := UDINT_TO_REAL(udiPos)*0.01;  //位置设定


IF uiAcc = 0 THEN rAcc := 200; ELSE rAcc  := rMaxSpeed/UINT_TO_REAL(uiAcc); END_IF;  
IF uiDec = 0 THEN rDec := 200; ELSE rDec  := rMaxSpeed/UINT_TO_REAL(uiDec); END_IF;  
IF uiJerk = 0 THEN rJerk := 0; ELSE rJerk := rMaxSpeed/UINT_TO_REAL(uiJerk); END_IF;

iDir := uiDir;  
//--- 2. 状态机主逻辑 ---
CASE iStep OF

    0: // 初始化
        fbCreate(USE_SIMULATION := TRUE);
        IF fbCreate.DONE THEN
            siAxisId := fbCreate.AXISID;
            iStep := 10;
        ELSIF fbCreate.ERROR THEN
            bAlarm := TRUE; dwAlarmID := 16#00000001; iStep := 900;
        END_IF;

    10: // 空闲
        bCmdExecute := FALSE; 
        bDone := FALSE; // 重置完成信号
        IF rTrigEStop.Q THEN
            iStep := 300;
        ELSIF rTrigStop.Q THEN
            iStep := 200;
        ELSIF rTrigReset.Q AND bAlarm THEN
            iStep := 400;
        ELSIF rTrigStart.Q AND uiMode >= 1 AND uiMode <= 3 THEN
            uiActiveMode := uiMode; 
            bCmdExecute := TRUE; // 启动时直接置高
            iStep := 100;           
        END_IF;

    100: // 运行中
        // 默认保持执行状态
        bCmdExecute := TRUE; 
        
        // 1. 错误监测 (所有模式通用)
        CASE uiActiveMode OF
            1: bFBError := fbMoveContAbs.ERROR; wFBErrorID := fbMoveContAbs.ERRORID;
            2: bFBError := fbMoveVel.ERROR; wFBErrorID := fbMoveVel.ERRORID;
            3: bFBError := fbPresHdl.ERROR; wFBErrorID := fbPresHdl.ERRORID;
        END_CASE;
        
        IF bFBError THEN
            bAlarm := TRUE; dwAlarmID := wFBErrorID; iStep := 900;
            
        // 2. 段切换触发 (核心逻辑)
        ELSIF rTrigStart.Q THEN
            // 检测到新的启动信号
            IF uiMode = uiActiveMode THEN
                // 同模式重触发（例如射胶第一段->第二段）：
                // 进入过渡步，拉低Execute，下一周期再拉高，产生上升沿
                iStep := 105; 
            ELSIF uiMode >= 1 AND uiMode <= 3 THEN
                // 跨模式切换（如位置->压力）：直接更改模式
                // 注意：有些运动控制库需要Stop才能切换模式，这里假设支持无缝切换或由BufferMode处理
                uiActiveMode := uiMode; 
                // 如果库不支持直接修改参数切换，此处也应跳转Step 105
            END_IF;
        END_IF;
        
        // 3. 中断监测
        IF rTrigEStop.Q THEN iStep := 300;
        ELSIF rTrigStop.Q THEN iStep := 200;
        END_IF;

    105: // 运行过渡步 (产生Execute脉冲)
        // 此步仅保持1个周期
        bCmdExecute := FALSE; // 拉低Execute
        bDone := FALSE;      // 清除上一段的完成标志
        iStep := 100;        // 立即回100，在100中bCmdExecute变TRUE，形成上升沿

    200: // 正常停止
        fbStop(AXISID := siAxisId, EXECUTE := TRUE, DECELERATION := rDec); // 这里的Execute通常需要脉冲或持续，视具体FB而定，假设持续
        IF fbStop.DONE THEN
            fbStop(EXECUTE := FALSE); // 停止命令需复位
            iStep := 10;
        ELSIF fbStop.ERROR THEN
            bAlarm := TRUE; dwAlarmID := fbStop.ERRORID; iStep := 900;
        END_IF;

    300: // 急停
        fbEStop(AXISID := siAxisId, EXECUTE := TRUE, DECELERATION := 99999.0);
        IF fbEStop.DONE OR fbEStop.ERROR THEN
            fbEStop(EXECUTE := FALSE);
            bAlarm := TRUE; dwAlarmID := 16#0000FFFF; iStep := 900;
        END_IF;

    400: // 报警复位
        fbReset(AXISID := siAxisId, EXECUTE := TRUE);
        IF fbReset.DONE THEN
            fbReset(EXECUTE := FALSE);
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
// 注意：fbStop, fbEStop, fbReset的调用已在State中处理或者在这里根据iStep统一处理
// 为了代码清晰，建议持续调用，EXECUTE由状态控制
// 但为了符合原代码结构，下面保留原风格，修正MoveContinuousAbsolute的参数

// Create 只在Init或Reset时调用一次即可，原代码持续调用没问题(内部有Enable管理)
// fbCreate(...); 

fbMoveContAbs(
    AXISID := siAxisId, 
    EXECUTE := (uiActiveMode = 1) AND bCmdExecute, 
    POSITION := rPos, 
    VELOCITY := rVel,
    ENDVELOCITY := rEndVel,    // 关键修改：设定终点速度，保证InEndVelocity能正常触发
    ENDVELOCITYDIRECTION := 0, // 0=Current/Positive, 需根据实际情况设定
    ACCELERATION := rAcc, 
    DECELERATION := rDec, 
    JERK := rJerk, 
    DIRECTION := iDir
    // BufferMode 可根据库支持情况添加，若不支持则依靠Step 105的脉冲机制
);

fbMoveVel(
    AXISID := siAxisId, EXECUTE := (uiActiveMode = 2) AND bCmdExecute, 
    CONTINUOUSUPDATE := TRUE, VELOCITY := rVel,
    ACCELERATION := rAcc, DECELERATION := rDec, JERK := rJerk, DIRECTION := iDir, BUFFERMODE := 0);

fbPresHdl(
    AXISID := siAxisId, EXECUTE := (uiActiveMode = 3) AND bCmdExecute, 
    CONTINUOUSUPDATE := TRUE, PRESSURE := rPres, PRESSURERAMPRATE := rAcc, DURATION := 0.0, BUFFERMODE := 0);

// Stop/EStop/Reset 需要特殊处理Execute信号，防止一直给TRUE
// 修改为根据状态决定EXECUTE
IF iStep = 200 THEN
    fbStop(AXISID := siAxisId, EXECUTE := TRUE, DECELERATION := rDec);
ELSE
    fbStop(AXISID := siAxisId, EXECUTE := FALSE, DECELERATION := rDec);
END_IF;

IF iStep = 300 THEN
    fbEStop(AXISID := siAxisId, EXECUTE := TRUE, DECELERATION := 99999.0);
ELSE
    fbEStop(AXISID := siAxisId, EXECUTE := FALSE, DECELERATION := 99999.0);
END_IF;

IF iStep = 400 THEN
    fbReset(AXISID := siAxisId, EXECUTE := TRUE);
ELSE
    fbReset(AXISID := siAxisId, EXECUTE := FALSE);
END_IF;

fbReadFB(AXISID := siAxisId, ENABLE := TRUE);
IF fbReadFB.VALID THEN
    stAxisRef.rPosition  := fbReadFB.POSITION;
    stAxisRef.rVeloctity := fbReadFB.VELOCITY;
    stAxisRef.rFlow      := fbReadFB.FLOW;
    stAxisRef.rPerssure  := fbReadFB.PRESSURE;
END_IF;
//引出iStep状态
stAxisRef.iStep := iStep;
//--- 4. 状态输出汇总 ---
IF iStep = 10 THEN
    bBusy := FALSE; 
    bDone := FALSE; // 空闲状态下没有完成信号
ELSIF iStep = 100 OR iStep = 105 THEN
    bBusy := TRUE;  // 忙
    
    // 区分模式的Done信号
    IF uiActiveMode = 1 THEN
        // 位置模式：InEndVelocity TRUE 表示当前段已到达且速度吻合，可以进行下一段
        bDone := fbMoveContAbs.InEndVelocity; 
    ELSIF uiActiveMode = 2 THEN
        // 速度模式：通常持续运行，除非有特定停止条件，这里暂不输出Done，或根据是否达到速度判定
        bDone := fbMoveVel.InVelocity; 
    ELSIF uiActiveMode = 3 THEN
        // 压力模式
        bDone := fbPresHdl.INPRESSURE;
    ELSE
        bDone := FALSE;
    END_IF;
    
    bInVelocity := fbMoveVel.InVelocity;
    bInPressure := fbPresHdl.INPRESSURE;
    
ELSIF iStep = 200 THEN
    bBusy := TRUE; bDone := FALSE;
ELSIF iStep = 300 THEN
    bBusy := TRUE; bDone := FALSE;
ELSIF iStep = 400 THEN  
    bBusy := TRUE; bDone := FALSE;
ELSE // 900 等
    bBusy := FALSE; bDone := FALSE;
END_IF;

TraceVariable( INDEX := 0,   VALUE := rPosition );
TraceVariable( INDEX := 1,   VALUE := rVeloctity );