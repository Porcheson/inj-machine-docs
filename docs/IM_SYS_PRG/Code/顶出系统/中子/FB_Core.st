(* 
  FB_Core 功能块
  功能：
  1. 负责中子进、中子退及其调试动作的执行状态机。
  2. 根据中子参数输出压力、速度、位置命令，并返回中子进退完成状态。

  说明：
  1. 正常模式使用 1=中子进、2=中子退；调试模式使用 3/4。
  2. 本块支持以时间、行程、位置和计数等条件结束动作。
*)
FUNCTION_BLOCK FB_Core
VAR_IN_OUT
    stCoreAxis: ST_AxisRefHyd;        // 中子共享轴结构
END_VAR
VAR_INPUT
    bStart: BOOL;                     // TRUE=启动中子动作
    bStop: BOOL;                      // TRUE=正常停止
    bEStop: BOOL;                     // TRUE=急停
    bReset: BOOL;                     // TRUE=复位状态机与输出
    bManualMode: BOOL;                // TRUE=手动点动中子
    uiCoreMode: UINT;                 // 1=中子进 2=中子退 3=中子进调试 4=中子退调试
    stCorePara: ST_CorePara;          // 中子工艺参数
    bCoreInStop: BOOL;                // 中子进停止信号
    bCoreOutStop: BOOL;               // 中子退停止信号
    rCoreActualPosition: LREAL;       // 中子轴实际位置反馈
    rCoreActualVelocity: LREAL;       // 中子轴实际速度反馈
    rCoreActualPressure: LREAL;       // 中子轴实际压力反馈
END_VAR
VAR_OUTPUT
    bBusy: BOOL;                      // TRUE=当前动作尚未结束
    bDone: BOOL;                      // TRUE=当前动作完成
    bAlarm: BOOL;                     // TRUE=当前动作报警
    dwAlarmID: DWORD;                 // 模块报警码
    uiActHint: UINT;                  // 当前动作提示码
    uiActTime: UINT;                  // 当前动作持续时间，单位 s
    bCoreIned: BOOL;                  // TRUE=中子进完成
    bCoreOuted: BOOL;                 // TRUE=中子退完成
    uiPresCmd: UINT;                  // 压力命令输出
    uiSpdCmd: UINT;                   // 速度命令输出
    udiPosCmd: UDINT;                 // 位置命令输出
END_VAR
VAR
    eState: E_CoreState := eState_Idle; // 当前中子状态机状态
    fbAxisInst: FB_HydAxis;              // 中子轴层实例
    stAxisStatusLocal: ST_HydAxisStatus; // 中子轴层状态缓存
    stAxisConfigLocal: ST_HydAxisConfig := (
        nAxisID := 7,
        rMaxCylinderStroke := 10000.0,
        rMaxVelocity := 1000.0,
        rMaxPressure := 1000.0,
        rPosTolerance := 0.5,
        rVelTolerance := 0.5,
        rPresTolerance := 0.5
    );
    bAxisEnableLocal: BOOL := FALSE;     // 中子轴层使能，由模块内部根据停机/急停收口
    tPulse: TON;                        // 100ms 节拍定时器，用于累计动作时间
    udiElapsedMs: UDINT := 0;           // 当前中子动作已运行时间，单位 ms
    uiStopCount: UINT := 0;             // 停止信号上升沿累计次数，用于计数式结束模式
    bPrevInStop: BOOL := FALSE;         // 上一拍中子进停止信号，用于检测上升沿
    bPrevOutStop: BOOL := FALSE;        // 上一拍中子退停止信号，用于检测上升沿
    bManualActive: BOOL := FALSE;       // TRUE=当前按调试/手动逻辑执行
    bInRequest: BOOL := FALSE;          // TRUE=当前请求方向为中子进
    bOutRequest: BOOL := FALSE;         // TRUE=当前请求方向为中子退
    stSegCmd: ST_CoreSeg;               // 当前生效的中子段命令缓存
END_VAR

(* 每拍先把模式号解码成统一的中子进/退请求位。 *)
bManualActive := bManualMode OR (uiCoreMode = 3) OR (uiCoreMode = 4);
bInRequest := (uiCoreMode = 1) OR (uiCoreMode = 3);
bOutRequest := (uiCoreMode = 2) OR (uiCoreMode = 4);

(* 复位优先级最高：清空状态、命令、计时和停止沿计数。 *)
IF bReset THEN
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := 0;
    uiActHint := 0;
    uiActTime := 0;
    bCoreIned := FALSE;
    bCoreOuted := FALSE;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    udiElapsedMs := 0;
    uiStopCount := 0;
    bPrevInStop := FALSE;
    bPrevOutStop := FALSE;
    tPulse(IN := FALSE, PT := T#100MS);
(* 急停直接转故障态，撤销中子轴命令。 *)
ELSIF bEStop THEN
    eState := eState_Error;
    bAlarm := TRUE;
    dwAlarmID := dwAlarmID OR DWORD#16#0010;
    uiActHint := 1;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 正常停止回空闲，并清空计时与停止计数。 *)
ELSIF bStop THEN
    eState := eState_Idle;
    bBusy := FALSE;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    uiActHint := 0;
    udiElapsedMs := 0;
    uiStopCount := 0;
    tPulse(IN := FALSE, PT := T#100MS);
ELSE
    CASE eState OF
        (* 空闲态：等待启动，并根据方向请求进入中子进或中子退。 *)
        eState_Idle:
            bBusy := FALSE;
            uiActHint := 0;
            uiActTime := 0;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            udiElapsedMs := 0;
            uiStopCount := 0;
            tPulse(IN := FALSE, PT := T#100MS);
            IF bStart THEN
                bDone := FALSE;
                bAlarm := FALSE;
                dwAlarmID := 0;
                bCoreIned := FALSE;
                bCoreOuted := FALSE;
                IF bInRequest THEN
                    eState := eState_CoreIning;
                ELSIF bOutRequest THEN
                    eState := eState_CoreOuting;
                ELSE
                    bAlarm := TRUE;
                    dwAlarmID := DWORD#16#0001;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 中子进执行态：支持手动点动，也支持按时间、停止信号或计数结束。 *)
        eState_CoreIning:
            bBusy := TRUE;
            stSegCmd := stCorePara.stCoreInSeg;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiElapsedMs / 1000);

            (* 调试中子进优先使用调试段；未配置时回退到正式段。 *)
            IF bManualActive THEN
                stSegCmd := stCorePara.stCoreInDbgSeg;
                IF (stSegCmd.uiPres = 0) AND (stSegCmd.uiSpd = 0) THEN
                    stSegCmd := stCorePara.stCoreInSeg;
                END_IF;
                uiActHint := 33;
                uiPresCmd := stSegCmd.uiPres;
                uiSpdCmd := stSegCmd.uiSpd;
                udiPosCmd := stCorePara.udiCoreInPos;
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动中子进使用正式段，并在停止信号上升沿时累加计数。 *)
            ELSE
                uiActHint := 11;
                uiPresCmd := stCorePara.stCoreInSeg.uiPres;
                uiSpdCmd := stCorePara.stCoreInSeg.uiSpd;
                udiPosCmd := stCorePara.udiCoreInPos;

                IF bCoreInStop AND (NOT bPrevInStop) THEN
                    uiStopCount := uiStopCount + 1;
                END_IF;

                (* `uiCoreInStopMode` 约定：
                   0=按时间结束；
                   1=按停止信号结束；
                   2=按停止信号上升沿计数结束。 *)
                CASE stCorePara.uiCoreInStopMode OF
                    0:
                        IF (stCorePara.stCoreInSeg.uiTime = 0) OR (udiElapsedMs >= TO_UDINT(stCorePara.stCoreInSeg.uiTime)) THEN
                            eState := eState_CoreIned;
                        END_IF;
                    1:
                        IF bCoreInStop THEN
                            eState := eState_CoreIned;
                        END_IF;
                    2:
                        IF (stCorePara.stCoreInSeg.uiCount = 0) OR (uiStopCount >= stCorePara.stCoreInSeg.uiCount) THEN
                            eState := eState_CoreIned;
                        END_IF;
                ELSE
                    IF bCoreInStop THEN
                        eState := eState_CoreIned;
                    END_IF;
                END_CASE;

                (* 中子进总时长超限时直接报警。 *)
                IF (stCorePara.uiCoreInLimitTime > 0) AND (udiElapsedMs >= TO_UDINT(stCorePara.uiCoreInLimitTime)) THEN
                    dwAlarmID := dwAlarmID OR DWORD#16#0001;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 中子进完成态：对外发布中子进完成标志。 *)
        eState_CoreIned:
            bBusy := FALSE;
            bDone := TRUE;
            bCoreIned := TRUE;
            uiActHint := 34;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;

        (* 中子退执行态：逻辑与中子进对称，但使用退方向参数和停止信号。 *)
        eState_CoreOuting:
            bBusy := TRUE;
            stSegCmd := stCorePara.stCoreOutSeg;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiElapsedMs / 1000);

            (* 调试中子退优先使用调试段；未配置时回退到正式段。 *)
            IF bManualActive THEN
                stSegCmd := stCorePara.stCoreOutDbgSeg;
                IF (stSegCmd.uiPres = 0) AND (stSegCmd.uiSpd = 0) THEN
                    stSegCmd := stCorePara.stCoreOutSeg;
                END_IF;
                uiActHint := 35;
                uiPresCmd := stSegCmd.uiPres;
                uiSpdCmd := stSegCmd.uiSpd;
                udiPosCmd := stCorePara.udiCoreOutPos;
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动中子退同样支持按时间、停止信号或停止次数结束。 *)
            ELSE
                uiActHint := 21;
                uiPresCmd := stCorePara.stCoreOutSeg.uiPres;
                uiSpdCmd := stCorePara.stCoreOutSeg.uiSpd;
                udiPosCmd := stCorePara.udiCoreOutPos;

                IF bCoreOutStop AND (NOT bPrevOutStop) THEN
                    uiStopCount := uiStopCount + 1;
                END_IF;

                (* `uiCoreOutStopMode` 约定与进方向一致：
                   0=按时间结束；
                   1=按停止信号结束；
                   2=按停止信号上升沿计数结束。 *)
                CASE stCorePara.uiCoreOutStopMode OF
                    0:
                        IF (stCorePara.stCoreOutSeg.uiTime = 0) OR (udiElapsedMs >= TO_UDINT(stCorePara.stCoreOutSeg.uiTime)) THEN
                            eState := eState_CoreOuted;
                        END_IF;
                    1:
                        IF bCoreOutStop THEN
                            eState := eState_CoreOuted;
                        END_IF;
                    2:
                        IF (stCorePara.stCoreOutSeg.uiCount = 0) OR (uiStopCount >= stCorePara.stCoreOutSeg.uiCount) THEN
                            eState := eState_CoreOuted;
                        END_IF;
                ELSE
                    IF bCoreOutStop THEN
                        eState := eState_CoreOuted;
                    END_IF;
                END_CASE;

                (* 中子退总时长超限时直接报警。 *)
                IF (stCorePara.uiCoreOutLimitTime > 0) AND (udiElapsedMs >= TO_UDINT(stCorePara.uiCoreOutLimitTime)) THEN
                    dwAlarmID := dwAlarmID OR DWORD#16#0002;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 中子退完成态：对外发布中子退完成标志。 *)
        eState_CoreOuted:
            bBusy := FALSE;
            bDone := TRUE;
            bCoreOuted := TRUE;
            uiActHint := 36;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;

        (* 故障态：统一撤销中子输出，仅保留报警。 *)
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

(* 在状态机执行完成后更新停止信号上一拍值，用于下一拍做上升沿计数。 *)
bPrevInStop := bCoreInStop;
bPrevOutStop := bCoreOutStop;

(* 将工艺命令回写到共享轴结构，由轴层功能块继续做最终执行。 *)
stCoreAxis.rActualPosition := rCoreActualPosition;
stCoreAxis.rActualVelocity := rCoreActualVelocity;
stCoreAxis.rActualPressure := rCoreActualPressure;
stCoreAxis.rSetPressure := TO_LREAL(uiPresCmd);
stCoreAxis.rSetVelocity := TO_LREAL(uiSpdCmd);
stCoreAxis.rSetPosition := TO_LREAL(udiPosCmd);
stCoreAxis.stPumpRequest.bRequest := bBusy;
stCoreAxis.stPumpRequest.rPressureSet := TO_LREAL(uiPresCmd);
stCoreAxis.stPumpRequest.rFlowSet := TO_LREAL(uiSpdCmd);
IF bBusy THEN
    stCoreAxis.eAxisState := Running;
ELSE
    stCoreAxis.eAxisState := Idle;
END_IF;
stCoreAxis.nFaultCode := TO_INT(dwAlarmID);
bAxisEnableLocal := (NOT bStop) AND (NOT bEStop);

fbAxisInst(
    stAxisRef := stCoreAxis,
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
