(* 
  FB_Nozzle 功能块
  功能：
  1. 负责座进、座退及其调试动作的执行状态机。
  2. 按段输出座台压力、速度、位置命令，并返回进退完成状态。

  说明：
  1. 正常模式使用 1=座进、2=座退；调试模式使用 3/4。
  2. 状态机部分只处理工艺节拍，块尾由内部 `FB_HydAxis` 负责最终轴保护。
*)
FUNCTION_BLOCK FB_Nozzle
VAR_IN_OUT
    stNozzleAxis: ST_AxisRefHyd;      // 座台共享轴结构
END_VAR
VAR_INPUT
    bStart: BOOL;                     // TRUE=启动座台动作
    bStop: BOOL;                      // TRUE=正常停止
    bEStop: BOOL;                     // TRUE=急停
    bReset: BOOL;                     // TRUE=复位状态机与输出
    bManualMode: BOOL;                // TRUE=手动点动座台
    uiNozzleMode: UINT;               // 1=座进 2=座退 3=座进调试 4=座退调试
    stNozzlePara: ST_NozzlePara;      // 座台工艺参数
    bNozzleInStop: BOOL;              // 座进停止信号
    bNozzleOutStop: BOOL;             // 座退停止信号
    udiNozzleElecRulerVal: UDINT;     // 位置反馈
    rNozzleActualPosition: LREAL;     // 座台轴实际位置反馈
    rNozzleActualVelocity: LREAL;     // 座台轴实际速度反馈
    rNozzleActualPressure: LREAL;     // 座台轴实际压力反馈
END_VAR
VAR_OUTPUT
    bBusy: BOOL;                      // TRUE=当前动作尚未结束
    bDone: BOOL;                      // TRUE=当前动作完成
    bAlarm: BOOL;                     // TRUE=当前动作报警
    dwAlarmID: DWORD;                 // 模块报警码
    uiActHint: UINT;                  // 当前动作提示码
    uiActTime: UINT;                  // 当前动作持续时间，单位 s
    bNozzleIned: BOOL;                // TRUE=座进完成
    bNozzleOuted: BOOL;               // TRUE=座退完成
    uiPresCmd: UINT;                  // 压力命令输出
    uiSpdCmd: UINT;                   // 速度命令输出
    udiPosCmd: UDINT;                 // 位置命令输出
END_VAR
VAR
    eState: E_NozzleState := eState_Idle; // 当前座台状态机状态
    fbAxisInst: FB_HydAxis;               // 座台轴层实例
    stAxisStatusLocal: ST_HydAxisStatus;  // 座台轴层状态缓存
    stAxisConfigLocal: ST_HydAxisConfig := (
        nAxisID := 3,
        rMaxCylinderStroke := 10000.0,
        rMaxVelocity := 1000.0,
        rMaxPressure := 1000.0,
        rPosTolerance := 0.5,
        rVelTolerance := 0.5,
        rPresTolerance := 0.5
    );
    bAxisEnableLocal: BOOL := FALSE;      // 座台轴层使能，由模块内部根据停机/急停收口
    uiStageIndex: UINT := 0;              // 当前执行到的座进/座退工艺段号
    tPulse: TON;                          // 100ms 节拍定时器，用于累计段运行时间
    udiElapsedMs: UDINT := 0;             // 当前动作或当前段已运行时间，单位 ms
    bManualActive: BOOL := FALSE;         // TRUE=当前按调试/手动逻辑执行
    bInRequest: BOOL := FALSE;            // TRUE=当前请求方向为座进
    bOutRequest: BOOL := FALSE;           // TRUE=当前请求方向为座退
    stSegCmd: ST_NozzleSeg;               // 当前生效的座台段命令缓存
END_VAR

(* 每拍先把模式号映射成“座进/座退/手动”三个统一语义。 *)
bManualActive := bManualMode OR (uiNozzleMode = 3) OR (uiNozzleMode = 4);
bInRequest := (uiNozzleMode = 1) OR (uiNozzleMode = 3);
bOutRequest := (uiNozzleMode = 2) OR (uiNozzleMode = 4);

(* 复位优先级最高：清空完成态、命令输出、段号和计时。 *)
IF bReset THEN
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := 0;
    uiActHint := 0;
    uiActTime := 0;
    bNozzleIned := FALSE;
    bNozzleOuted := FALSE;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    uiStageIndex := 0;
    udiElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 急停直接进入故障态，立即撤销座台命令。 *)
ELSIF bEStop THEN
    eState := eState_Error;
    bAlarm := TRUE;
    dwAlarmID := dwAlarmID OR DWORD#16#0010;
    uiActHint := 1;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 正常停止统一按空闲态收口，等待下次重新启动。 *)
ELSIF bStop THEN
    eState := eState_Idle;
    bBusy := FALSE;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    uiActHint := 0;
    udiElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
ELSE
    CASE eState OF
        (* 空闲态：等待启动，根据请求方向进入座进或座退。 *)
        eState_Idle:
            bBusy := FALSE;
            uiActHint := 0;
            uiActTime := 0;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            uiStageIndex := 0;
            udiElapsedMs := 0;
            tPulse(IN := FALSE, PT := T#100MS);
            IF bStart THEN
                bDone := FALSE;
                bAlarm := FALSE;
                dwAlarmID := 0;
                bNozzleIned := FALSE;
                bNozzleOuted := FALSE;
                uiStageIndex := 1;

                IF bInRequest THEN
                    eState := eState_NozzleIning;
                ELSIF bOutRequest THEN
                    eState := eState_NozzleOuting;
                ELSE
                    bAlarm := TRUE;
                    dwAlarmID := DWORD#16#0001;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 座进执行态：手动模式持续输出调试段，自动模式按段推进。 *)
        eState_NozzleIning:
            bBusy := TRUE;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiElapsedMs / 1000);

            (* 调试座进优先使用专用调试段；未配置时退回正式第一段。 *)
            IF bManualActive THEN
                stSegCmd := stNozzlePara.stNozzleInDbgSeg;
                IF (stSegCmd.uiPres = 0) AND (stSegCmd.uiSpd = 0) AND (stSegCmd.udiPos = 0) THEN
                    stSegCmd := stNozzlePara.aNozzleInSeg[1];
                END_IF;
                uiActHint := 113;
                uiPresCmd := stSegCmd.uiPres;
                uiSpdCmd := stSegCmd.uiSpd;
                udiPosCmd := stSegCmd.udiPos;
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动座进按段执行，段完成条件可来自位置、停止信号或时间。 *)
            ELSE
                IF uiStageIndex > stNozzlePara.uiNozzleInSegCnt THEN
                    eState := eState_NozzleIned;
                ELSE
                    stSegCmd := stNozzlePara.aNozzleInSeg[uiStageIndex];
                    uiActHint := 87 + uiStageIndex; // 88-89
                    uiPresCmd := stSegCmd.uiPres;
                    uiSpdCmd := stSegCmd.uiSpd;
                    udiPosCmd := stSegCmd.udiPos;

                    (* `uiNozzleInMode` 约定：
                       0=按段时间推进；
                       1=按座进停止信号推进；
                       2=按电子尺位置推进。 *)
                    IF (stNozzlePara.uiNozzleInMode = 2) AND (udiNozzleElecRulerVal >= stSegCmd.udiPos) THEN
                        uiStageIndex := uiStageIndex + 1;
                        udiElapsedMs := 0;
                        tPulse(IN := FALSE, PT := T#100MS);
                    ELSIF ((stNozzlePara.uiNozzleInMode = 0) AND (stSegCmd.uiTime > 0) AND (udiElapsedMs >= TO_UDINT(stSegCmd.uiTime))) OR ((stNozzlePara.uiNozzleInMode = 1) AND bNozzleInStop) THEN
                        uiStageIndex := uiStageIndex + 1;
                        udiElapsedMs := 0;
                        tPulse(IN := FALSE, PT := T#100MS);
                    END_IF;

                    (* 座进总时长超限后直接报警，防止机构长时间顶压。 *)
                    IF (stNozzlePara.uiNozzleInLimitTime > 0) AND (udiElapsedMs >= TO_UDINT(stNozzlePara.uiNozzleInLimitTime)) THEN
                        dwAlarmID := dwAlarmID OR DWORD#16#0001;
                        eState := eState_Error;
                    END_IF;
                END_IF;
            END_IF;

        (* 座进完成态：对外发布完成标志并撤销输出。 *)
        eState_NozzleIned:
            bBusy := FALSE;
            bDone := TRUE;
            bNozzleIned := TRUE;
            uiActHint := 6;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;

        (* 座退执行态：手动模式持续输出调试段，自动模式按段推进。 *)
        eState_NozzleOuting:
            bBusy := TRUE;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiElapsedMs / 1000);

            (* 调试座退优先使用专用调试段；未配置时退回正式第一段。 *)
            IF bManualActive THEN
                stSegCmd := stNozzlePara.stNozzleOutDbgSeg;
                IF (stSegCmd.uiPres = 0) AND (stSegCmd.uiSpd = 0) AND (stSegCmd.udiPos = 0) THEN
                    stSegCmd := stNozzlePara.aNozzleOutSeg[1];
                END_IF;
                uiActHint := 114;
                uiPresCmd := stSegCmd.uiPres;
                uiSpdCmd := stSegCmd.uiSpd;
                udiPosCmd := stSegCmd.udiPos;
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动座退按段执行，完成条件同样支持位置、停止信号或时间。 *)
            ELSE
                IF uiStageIndex > stNozzlePara.uiNozzleOutSegCnt THEN
                    eState := eState_NozzleOuted;
                ELSE
                    stSegCmd := stNozzlePara.aNozzleOutSeg[uiStageIndex];
                    uiActHint := 85 + uiStageIndex; // 86-87
                    uiPresCmd := stSegCmd.uiPres;
                    uiSpdCmd := stSegCmd.uiSpd;
                    udiPosCmd := stSegCmd.udiPos;

                    (* `uiNozzleOutMode` 约定：
                       0=按段时间推进；
                       1=按座退停止信号推进；
                       2=按电子尺位置推进。 *)
                    IF (stNozzlePara.uiNozzleOutMode = 2) AND (udiNozzleElecRulerVal >= stSegCmd.udiPos) THEN
                        uiStageIndex := uiStageIndex + 1;
                        udiElapsedMs := 0;
                        tPulse(IN := FALSE, PT := T#100MS);
                    ELSIF ((stNozzlePara.uiNozzleOutMode = 0) AND (stSegCmd.uiTime > 0) AND (udiElapsedMs >= TO_UDINT(stSegCmd.uiTime))) OR ((stNozzlePara.uiNozzleOutMode = 1) AND bNozzleOutStop) THEN
                        uiStageIndex := uiStageIndex + 1;
                        udiElapsedMs := 0;
                        tPulse(IN := FALSE, PT := T#100MS);
                    END_IF;

                    (* 座退总时长超限时按座退超时报警处理。 *)
                    IF (stNozzlePara.uiNozzleOutLimitTime > 0) AND (udiElapsedMs >= TO_UDINT(stNozzlePara.uiNozzleOutLimitTime)) THEN
                        dwAlarmID := dwAlarmID OR DWORD#16#0002;
                        eState := eState_Error;
                    END_IF;
                END_IF;
            END_IF;

        (* 座退完成态：对外发布座退完成标志。 *)
        eState_NozzleOuted:
            bBusy := FALSE;
            bDone := TRUE;
            bNozzleOuted := TRUE;
            uiActHint := 16;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;

        (* 故障态：统一收口命令，只保留报警给上层读取。 *)
        eState_Error:
            bBusy := FALSE;
            bAlarm := TRUE;
            uiActHint := 1;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            tPulse(IN := FALSE, PT := T#100MS);

    ELSE
        eState := eState_Error;
    END_CASE;
END_IF;

(* 将工艺层命令回写到共享轴结构，最终执行仍由轴层处理。 *)
stNozzleAxis.rActualPosition := rNozzleActualPosition;
stNozzleAxis.rActualVelocity := rNozzleActualVelocity;
stNozzleAxis.rActualPressure := rNozzleActualPressure;
stNozzleAxis.rSetPressure := TO_LREAL(uiPresCmd);
stNozzleAxis.rSetVelocity := TO_LREAL(uiSpdCmd);
stNozzleAxis.rSetPosition := TO_LREAL(udiPosCmd);
stNozzleAxis.stPumpRequest.bRequest := bBusy;
stNozzleAxis.stPumpRequest.rPressureSet := TO_LREAL(uiPresCmd);
stNozzleAxis.stPumpRequest.rFlowSet := TO_LREAL(uiSpdCmd);
IF bBusy THEN
    stNozzleAxis.eAxisState := Running;
ELSE
    stNozzleAxis.eAxisState := Idle;
END_IF;
stNozzleAxis.nFaultCode := TO_INT(dwAlarmID);
bAxisEnableLocal := (NOT bStop) AND (NOT bEStop);

fbAxisInst(
    stAxisRef := stNozzleAxis,
    bEnable := bAxisEnableLocal,
    bReset := bReset,
    stConfig := stAxisConfigLocal,
    stStatus => stAxisStatusLocal
);

bBusy := bBusy OR stAxisStatusLocal.bCommandActive;
bAlarm := bAlarm OR stAxisStatusLocal.bAlarm;
dwAlarmID := dwAlarmID OR stAxisStatusLocal.dwAlarmID;
IF stAxisStatusLocal.uiActTime > uiActTime THEN
    uiActTime := stAxisStatusLocal.uiActTime;
END_IF;
END_FUNCTION_BLOCK
