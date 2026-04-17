(* 
  FB_Meter 功能块
  功能：
  1. 负责储料动作的执行状态机，可按段完成储料过程。
  2. 根据储料参数输出压力、背压、速度和位置命令，并返回储料完成状态。

  说明：
  1. 手动模式下本块工作在点动方式；自动模式下按参数段推进。
  2. 状态机部分只负责工艺层命令，块尾由内部 `FB_HydAxis` 承担最终轴保护。
*)
FUNCTION_BLOCK FB_Meter
VAR_IN_OUT
    stMeterAxis: ST_AxisRefHyd;       // 储料共享轴结构
END_VAR
VAR_INPUT
    bStart: BOOL;                     // TRUE=启动储料动作
    bStop: BOOL;                      // TRUE=正常停止
    bEStop: BOOL;                     // TRUE=急停
    bReset: BOOL;                     // TRUE=复位状态机与输出
    bManualMode: BOOL;                // TRUE=手动点动储料
    stMeterPara: ST_MeterPara;        // 储料工艺参数
    bMeterStop: BOOL;                 // 储料停止信号
    udiInjElecRulerVal: UDINT;        // 位置反馈
    rMeterActualPosition: LREAL;      // 储料轴实际位置反馈
    rMeterActualVelocity: LREAL;      // 储料轴实际速度反馈
    rMeterActualPressure: LREAL;      // 储料轴实际压力反馈
END_VAR
VAR_OUTPUT
    bBusy: BOOL;                      // TRUE=当前动作尚未结束
    bDone: BOOL;                      // TRUE=当前动作完成
    bAlarm: BOOL;                     // TRUE=当前动作报警
    dwAlarmID: DWORD;                 // 模块报警码
    uiActHint: UINT;                  // 当前动作提示码
    uiActTime: UINT;                  // 当前动作持续时间，单位 s
    bMetered: BOOL;                   // TRUE=储料完成
    uiPresCmd: UINT;                  // 压力命令输出
    uiBackPresCmd: UINT;              // 背压命令输出
    uiSpdCmd: UINT;                   // 速度命令输出
    udiPosCmd: UDINT;                 // 位置命令输出
END_VAR
VAR
    eState: E_MeterState := eState_Idle; // 当前储料状态机状态
    fbAxisInst: FB_HydAxis;              // 储料轴层实例
    stAxisStatusLocal: ST_HydAxisStatus; // 储料轴层状态缓存
    stAxisConfigLocal: ST_HydAxisConfig := (
        nAxisID := 5,
        rMaxCylinderStroke := 10000.0,
        rMaxVelocity := 1000.0,
        rMaxPressure := 1000.0,
        rPosTolerance := 0.5,
        rVelTolerance := 0.5,
        rPresTolerance := 0.5
    );
    bAxisEnableLocal: BOOL := FALSE;     // 储料轴层使能，由模块内部根据停机/急停收口
    uiStageIndex: UINT := 0;             // 当前执行到的储料段号
    tPulse: TON;                         // 100ms 节拍定时器，用于累计储料时间
    udiElapsedMs: UDINT := 0;            // 当前储料动作已运行时间，单位 ms
END_VAR

(* 复位时清空储料状态、输出命令和计时缓存。 *)
IF bReset THEN
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := 0;
    uiActHint := 0;
    uiActTime := 0;
    bMetered := FALSE;
    uiPresCmd := 0;
    uiBackPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    uiStageIndex := 0;
    udiElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 急停直接打入故障态，避免储料继续运动。 *)
ELSIF bEStop THEN
    eState := eState_Error;
    bAlarm := TRUE;
    dwAlarmID := dwAlarmID OR DWORD#16#0010;
    uiActHint := 1;
    uiPresCmd := 0;
    uiBackPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 正常停止按空闲态收口，等待下次重新启动。 *)
ELSIF bStop THEN
    eState := eState_Idle;
    bBusy := FALSE;
    uiActHint := 0;
    uiPresCmd := 0;
    uiBackPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    udiElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
ELSE
    CASE eState OF
        (* 空闲态：等待启动，并在启动时清零完成/报警状态。 *)
        eState_Idle:
            bBusy := FALSE;
            uiActHint := 0;
            uiActTime := 0;
            uiPresCmd := 0;
            uiBackPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            uiStageIndex := 0;
            udiElapsedMs := 0;
            tPulse(IN := FALSE, PT := T#100MS);
            IF bStart THEN
                bDone := FALSE;
                bAlarm := FALSE;
                dwAlarmID := 0;
                bMetered := FALSE;
                uiStageIndex := 1;
                eState := eState_Metering;
            END_IF;

        (* 储料执行态：手动模式持续输出第一段，自动模式按段推进。 *)
        eState_Metering:
            bBusy := TRUE;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiElapsedMs / 1000);

            (* 手动储料使用第一段参数持续点动，直到启动信号释放。 *)
            IF bManualMode THEN
                uiActHint := 66;
                uiPresCmd := stMeterPara.aMeterSeg[1].uiSPres;
                uiBackPresCmd := stMeterPara.aMeterSeg[1].uiBackPres;
                uiSpdCmd := stMeterPara.aMeterSeg[1].uiSpd;
                udiPosCmd := stMeterPara.aMeterSeg[1].udiPos;
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动储料按段执行；每段完成条件由位置或储料停止信号决定。 *)
            ELSE
                IF uiStageIndex > stMeterPara.uiMeterSegCnt THEN
                    eState := eState_Metered;
                ELSE
                    uiActHint := 10 + uiStageIndex;
                    uiPresCmd := stMeterPara.aMeterSeg[uiStageIndex].uiSPres;
                    uiBackPresCmd := stMeterPara.aMeterSeg[uiStageIndex].uiBackPres;
                    uiSpdCmd := stMeterPara.aMeterSeg[uiStageIndex].uiSpd;
                    udiPosCmd := stMeterPara.aMeterSeg[uiStageIndex].udiPos;

                    (* `uiMeterMode` 约定：
                       0=按电子尺位置推进；
                       非 0=按储料停止信号推进。 *)
                    IF (stMeterPara.uiMeterMode = 0) AND (udiInjElecRulerVal >= stMeterPara.aMeterSeg[uiStageIndex].udiPos) THEN
                        uiStageIndex := uiStageIndex + 1;
                    ELSIF (stMeterPara.uiMeterMode <> 0) AND bMeterStop THEN
                        uiStageIndex := uiStageIndex + 1;
                    END_IF;

                    (* 储料总时长超限后直接报警，防止长时间背压运行。 *)
                    IF (stMeterPara.uiMeterLimitTime > 0) AND (udiElapsedMs >= TO_UDINT(stMeterPara.uiMeterLimitTime)) THEN
                        dwAlarmID := dwAlarmID OR DWORD#16#0001;
                        eState := eState_Error;
                    END_IF;
                END_IF;
            END_IF;

        (* 储料完成态：置位完成标志，并撤销对轴的输出命令。 *)
        eState_Metered:
            bBusy := FALSE;
            bDone := TRUE;
            bMetered := TRUE;
            uiActHint := 12;
            uiPresCmd := 0;
            uiBackPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;

        (* 故障态：只保留报警状态，所有动作命令归零。 *)
        eState_Error:
            bBusy := FALSE;
            bAlarm := TRUE;
            uiActHint := 1;
            uiPresCmd := 0;
            uiBackPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            tPulse(IN := FALSE, PT := T#100MS);

    ELSE
        eState := eState_Error;
    END_CASE;
END_IF;

(* 当前轴接口没有独立背压设定字段，因此这里只把压力/速度/位置回写到共享轴结构；
   `uiBackPresCmd` 仍保留在功能块输出，供主控或后续扩展读取。 *)
stMeterAxis.rActualPosition := rMeterActualPosition;
stMeterAxis.rActualVelocity := rMeterActualVelocity;
stMeterAxis.rActualPressure := rMeterActualPressure;
stMeterAxis.rSetPressure := TO_LREAL(uiPresCmd);
stMeterAxis.rSetVelocity := TO_LREAL(uiSpdCmd);
stMeterAxis.rSetPosition := TO_LREAL(udiPosCmd);
stMeterAxis.stPumpRequest.bRequest := bBusy;
stMeterAxis.stPumpRequest.rPressureSet := TO_LREAL(uiPresCmd);
stMeterAxis.stPumpRequest.rFlowSet := TO_LREAL(uiSpdCmd);
IF bBusy THEN
    stMeterAxis.eAxisState := Running;
ELSE
    stMeterAxis.eAxisState := Idle;
END_IF;
stMeterAxis.nFaultCode := TO_INT(dwAlarmID);
bAxisEnableLocal := (NOT bStop) AND (NOT bEStop);

fbAxisInst(
    stAxisRef := stMeterAxis,
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
