(* 
  FB_Inject 功能块
  功能：
  1. 负责射出、保压、射退及其调试动作的执行状态机。
  2. 按工艺段输出压力、速度、位置命令，并返回射出/保压/射退完成状态。

  说明：
  1. 正常模式使用 1=射出、2=射退；调试模式使用 3/4。
  2. 状态机部分只生成工艺命令和状态，块尾由内部 `FB_HydAxis` 完成最终轴限幅与保护。
*)
FUNCTION_BLOCK FB_Inject
VAR_IN_OUT
    stInjectAxis: ST_AxisRefHyd;      // 射胶共享轴结构
END_VAR
VAR_INPUT
    bStart: BOOL;                     // TRUE=启动射胶动作
    bStop: BOOL;                      // TRUE=正常停止
    bEStop: BOOL;                     // TRUE=急停
    bReset: BOOL;                     // TRUE=复位状态机与输出
    bManualMode: BOOL;                // TRUE=手动点动射出/射退
    uiInjectMode: UINT;               // 1=射出 2=射退 3=射出调试 4=射退调试
    stInjectPara: ST_InjectPara;      // 射胶工艺参数
    bInjSeg1Stop: BOOL;               // 射出第一停止信号
    bInjSeg2Stop: BOOL;               // 射出第二停止信号
    bInjStop: BOOL;                   // 射出结束信号
    bSuckBackStop: BOOL;              // 射退结束信号
    udiInjElecRulerVal: UDINT;        // 位置反馈
    rInjectActualPosition: LREAL;     // 射胶轴实际位置反馈
    rInjectActualVelocity: LREAL;     // 射胶轴实际速度反馈
    rInjectActualPressure: LREAL;     // 射胶轴实际压力反馈
END_VAR
VAR_OUTPUT
    bBusy: BOOL;                      // TRUE=当前动作尚未结束
    bDone: BOOL;                      // TRUE=当前动作完成
    bAlarm: BOOL;                     // TRUE=当前动作报警
    dwAlarmID: DWORD;                 // 模块报警码
    uiActHint: UINT;                  // 当前动作提示码
    uiActTime: UINT;                  // 当前动作持续时间，单位 s
    bInjected: BOOL;                  // TRUE=射出完成
    bHeld: BOOL;                      // TRUE=保压完成
    bSuckBacked: BOOL;                // TRUE=射退完成
    uiPresCmd: UINT;                  // 压力命令输出
    uiSpdCmd: UINT;                   // 速度命令输出
    udiPosCmd: UDINT;                 // 位置命令输出
END_VAR
VAR
    eState: E_InjectState := eState_Idle; // 当前射胶状态机状态
    fbAxisInst: FB_HydAxis;               // 射胶轴层实例
    stAxisStatusLocal: ST_HydAxisStatus;  // 射胶轴层状态缓存
    stAxisConfigLocal: ST_HydAxisConfig := (
        nAxisID := 4,
        rMaxCylinderStroke := 10000.0,
        rMaxVelocity := 1000.0,
        rMaxPressure := 1000.0,
        rPosTolerance := 0.5,
        rVelTolerance := 0.5,
        rPresTolerance := 0.5
    );
    bAxisEnableLocal: BOOL := FALSE;      // 射胶轴层使能，由模块内部根据停机/急停收口
    uiStageIndex: UINT := 0;              // 当前执行到的射出段号
    uiHoldIndex: UINT := 0;               // 当前执行到的保压段号
    tPulse: TON;                          // 100ms 节拍定时器，用于累计动作时间
    udiStageElapsedMs: UDINT := 0;        // 当前射出段或保压段已运行时间，单位 ms
    udiTotalElapsedMs: UDINT := 0;        // 射出阶段总运行时间，单位 ms
    bManualActive: BOOL := FALSE;         // TRUE=当前按调试/手动逻辑执行
    bInjectRequest: BOOL := FALSE;        // TRUE=当前请求方向为射出
    bSuckBackRequest: BOOL := FALSE;      // TRUE=当前请求方向为射退
    bStageDone: BOOL := FALSE;            // 当前射出段完成标志
    bTransferToHold: BOOL := FALSE;       // TRUE=满足转保压条件，本拍结束射出进入保压
    stSegCmd: ST_InjectSeg;               // 当前射出或射退生效段命令缓存
END_VAR

(* 每拍先把模式号翻译成统一语义，状态机内部只判断“射出/射退/手动”。 *)
bManualActive := bManualMode OR (uiInjectMode = 3) OR (uiInjectMode = 4);
bInjectRequest := (uiInjectMode = 1) OR (uiInjectMode = 3);
bSuckBackRequest := (uiInjectMode = 2) OR (uiInjectMode = 4);
bStageDone := FALSE;
bTransferToHold := FALSE;

(* 复位优先级最高：清空完成态、段号、计时和输出命令。 *)
IF bReset THEN
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := 0;
    uiActHint := 0;
    uiActTime := 0;
    bInjected := FALSE;
    bHeld := FALSE;
    bSuckBacked := FALSE;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    uiStageIndex := 0;
    uiHoldIndex := 0;
    udiStageElapsedMs := 0;
    udiTotalElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 急停直接切入故障态，撤销射胶轴命令。 *)
ELSIF bEStop THEN
    eState := eState_Error;
    bAlarm := TRUE;
    dwAlarmID := dwAlarmID OR DWORD#16#0010;
    uiActHint := 1;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 正常停止回空闲，不保留当前射出/保压/射退上下文。 *)
ELSIF bStop THEN
    eState := eState_Idle;
    bBusy := FALSE;
    uiActHint := 0;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    udiStageElapsedMs := 0;
    udiTotalElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
ELSE
    CASE eState OF
        (* 空闲态：等待启动，并根据模式决定进入射出还是射退流程。 *)
        eState_Idle:
            bBusy := FALSE;
            uiActHint := 0;
            uiActTime := 0;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            uiStageIndex := 0;
            uiHoldIndex := 0;
            udiStageElapsedMs := 0;
            udiTotalElapsedMs := 0;
            tPulse(IN := FALSE, PT := T#100MS);
            IF bStart THEN
                bDone := FALSE;
                bAlarm := FALSE;
                dwAlarmID := 0;
                bInjected := FALSE;
                bHeld := FALSE;
                bSuckBacked := FALSE;

                IF bInjectRequest THEN
                    uiStageIndex := 1;
                    eState := eState_Injecting;
                ELSIF bSuckBackRequest THEN
                    eState := eState_SuckBacking;
                ELSE
                    bAlarm := TRUE;
                    dwAlarmID := DWORD#16#0001;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 射出执行态：手动模式持续输出单段，自动模式按段推进并监视转保压条件。 *)
        eState_Injecting:
            bBusy := TRUE;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiStageElapsedMs := udiStageElapsedMs + 100;
                udiTotalElapsedMs := udiTotalElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiTotalElapsedMs / 1000);

            (* 调试射出优先使用调试段；调试段为空时回退到正式第一段。 *)
            IF bManualActive THEN
                stSegCmd := stInjectPara.stInjDbgSeg;
                IF (stSegCmd.uiPres = 0) AND (stSegCmd.uiSpd = 0) AND (stSegCmd.udiPos = 0) THEN
                    stSegCmd := stInjectPara.aInjSeg[1];
                END_IF;
                uiActHint := 44;
                uiPresCmd := stSegCmd.uiPres;
                uiSpdCmd := stSegCmd.uiSpd;
                udiPosCmd := stSegCmd.udiPos;
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动射出按段执行。每段完成后推进段号，也可以被“转保压”条件提前打断。 *)
            ELSE
                IF uiStageIndex > stInjectPara.uiInjSegCnt THEN
                    eState := eState_Injected;
                    uiPresCmd := 0;
                    uiSpdCmd := 0;
                    udiPosCmd := 0;
                ELSE
                    stSegCmd := stInjectPara.aInjSeg[uiStageIndex];
                    uiActHint := 10 + uiStageIndex;
                    uiPresCmd := stSegCmd.uiPres;
                    uiSpdCmd := stSegCmd.uiSpd;
                    udiPosCmd := stSegCmd.udiPos;

                    (* `uiInjMode` 约定：
                       0=按位置完成当前段；
                       1=按外部停止信号完成当前段；
                       其他=按段时间完成当前段。
                       无论主模式为何，段时间到达仍会作为兜底完成条件。 *)
                    CASE stInjectPara.uiInjMode OF
                        0:
                            IF udiInjElecRulerVal >= stSegCmd.udiPos THEN
                                bStageDone := TRUE;
                            END_IF;
                        1:
                            IF ((uiStageIndex = 1) AND bInjSeg1Stop) OR ((uiStageIndex = 2) AND bInjSeg2Stop) OR ((uiStageIndex >= 3) AND bInjStop) THEN
                                bStageDone := TRUE;
                            END_IF;
                    ELSE
                        IF (stSegCmd.uiTime > 0) AND (udiStageElapsedMs >= TO_UDINT(stSegCmd.uiTime)) THEN
                            bStageDone := TRUE;
                        END_IF;
                    END_CASE;

                    IF (stSegCmd.uiTime > 0) AND (udiStageElapsedMs >= TO_UDINT(stSegCmd.uiTime)) THEN
                        bStageDone := TRUE;
                    END_IF;

                    (* `dwInjToHoldMode` 位定义：
                       bit0=按总时间转保压；
                       bit1=按实际压力转保压；
                       bit2=按位置转保压。 *)
                    IF ((stInjectPara.dwInjToHoldMode AND DWORD#16#00000001) <> DWORD#16#00000000) AND (stInjectPara.uiInjToHoldTime > 0) AND (udiTotalElapsedMs >= TO_UDINT(stInjectPara.uiInjToHoldTime)) THEN
                        bTransferToHold := TRUE;
                    END_IF;
                    IF ((stInjectPara.dwInjToHoldMode AND DWORD#16#00000002) <> DWORD#16#00000000) AND (TO_UINT(stInjectAxis.rActualPressure) >= stInjectPara.uiInjToHoldPres) THEN
                        bTransferToHold := TRUE;
                    END_IF;
                    IF ((stInjectPara.dwInjToHoldMode AND DWORD#16#00000004) <> DWORD#16#00000000) AND (udiInjElecRulerVal >= stInjectPara.uiInjToHoldPos) THEN
                        bTransferToHold := TRUE;
                    END_IF;

                    (* 转保压优先级高于普通段完成：一旦满足就立即结束射出阶段。 *)
                    IF bTransferToHold THEN
                        eState := eState_Injected;
                        udiStageElapsedMs := 0;
                        tPulse(IN := FALSE, PT := T#100MS);
                    ELSIF bStageDone THEN
                        uiStageIndex := uiStageIndex + 1;
                        udiStageElapsedMs := 0;
                        tPulse(IN := FALSE, PT := T#100MS);
                    END_IF;
                END_IF;

                (* 射出总时间超限时直接报警，避免长时间憋压。 *)
                IF (stInjectPara.uiInjTotalTime > 0) AND (udiTotalElapsedMs >= TO_UDINT(stInjectPara.uiInjTotalTime)) THEN
                    dwAlarmID := dwAlarmID OR DWORD#16#0001;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 射出结束过渡态：置位“已射出”，并根据保压段数量决定是否进入保压。 *)
        eState_Injected:
            bBusy := TRUE;
            bInjected := TRUE;
            uiActHint := 2;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            udiStageElapsedMs := 0;
            tPulse(IN := FALSE, PT := T#100MS);

            IF stInjectPara.uiHoldSegCnt > 0 THEN
                uiHoldIndex := 1;
                eState := eState_Holding;
            ELSE
                eState := eState_Held;
            END_IF;

        (* 保压执行态：按保压段顺序输出压力/速度，位置命令在保压阶段固定为 0。 *)
        eState_Holding:
            bBusy := TRUE;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiStageElapsedMs := udiStageElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT((udiTotalElapsedMs + udiStageElapsedMs) / 1000);

            IF uiHoldIndex > stInjectPara.uiHoldSegCnt THEN
                eState := eState_Held;
            ELSE
                uiActHint := 20 + uiHoldIndex;
                uiPresCmd := stInjectPara.aHoldSeg[uiHoldIndex].uiPres;
                uiSpdCmd := stInjectPara.aHoldSeg[uiHoldIndex].uiSpd;
                udiPosCmd := 0;

                (* 当前保压段时间结束后推进到下一段；时间为 0 视为本拍完成。 *)
                IF (stInjectPara.aHoldSeg[uiHoldIndex].uiTime = 0) OR (udiStageElapsedMs >= TO_UDINT(stInjectPara.aHoldSeg[uiHoldIndex].uiTime)) THEN
                    uiHoldIndex := uiHoldIndex + 1;
                    udiStageElapsedMs := 0;
                    tPulse(IN := FALSE, PT := T#100MS);
                END_IF;
            END_IF;

        (* 保压完成态：保压结束后整体动作完成。 *)
        eState_Held:
            bBusy := FALSE;
            bDone := TRUE;
            bHeld := TRUE;
            uiActHint := 3;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;

        (* 射退执行态：支持手动单段调试，也支持按配置段完成自动射退。 *)
        eState_SuckBacking:
            bBusy := TRUE;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiStageElapsedMs := udiStageElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiStageElapsedMs / 1000);

            (* 调试射退优先取调试段；未配置时回退到正式射退段。 *)
            IF bManualActive THEN
                stSegCmd := stInjectPara.stSuckBackDbgSeg;
                IF (stSegCmd.uiPres = 0) AND (stSegCmd.uiSpd = 0) AND (stSegCmd.udiPos = 0) THEN
                    stSegCmd := stInjectPara.stSuckBackSeg;
                END_IF;
                uiActHint := 13;
                uiPresCmd := stSegCmd.uiPres;
                uiSpdCmd := stSegCmd.uiSpd;
                udiPosCmd := stSegCmd.udiPos;
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动射退根据配置模式按位置、时间或停止信号判定完成。 *)
            ELSE
                uiActHint := 5;
                uiPresCmd := stInjectPara.stSuckBackSeg.uiPres;
                uiSpdCmd := stInjectPara.stSuckBackSeg.uiSpd;
                udiPosCmd := stInjectPara.stSuckBackSeg.udiPos;

                (* `uiSuckBackMode` 约定：
                   0=按位置到位结束；
                   1=优先按时间，时间为 0 时退化为按停止信号；
                   其他=按停止信号结束。 *)
                CASE stInjectPara.uiSuckBackMode OF
                    0:
                        IF udiInjElecRulerVal >= stInjectPara.stSuckBackSeg.udiPos THEN
                            eState := eState_SuckBacked;
                        END_IF;
                    1:
                        IF (stInjectPara.stSuckBackSeg.uiTime > 0) AND (udiStageElapsedMs >= TO_UDINT(stInjectPara.stSuckBackSeg.uiTime)) THEN
                            eState := eState_SuckBacked;
                        ELSIF (stInjectPara.stSuckBackSeg.uiTime = 0) AND bSuckBackStop THEN
                            eState := eState_SuckBacked;
                        END_IF;
                ELSE
                    IF bSuckBackStop THEN
                        eState := eState_SuckBacked;
                    END_IF;
                END_CASE;
            END_IF;

        (* 射退完成态：对外发布射退完成标志，并清零命令。 *)
        eState_SuckBacked:
            bBusy := FALSE;
            bDone := TRUE;
            bSuckBacked := TRUE;
            uiActHint := 14;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;

        (* 故障态：统一撤销射胶输出，只保留报警信息。 *)
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

(* 将当前工艺命令回写到共享轴结构，由轴层统一做最终执行与诊断。 *)
stInjectAxis.rActualPosition := rInjectActualPosition;
stInjectAxis.rActualVelocity := rInjectActualVelocity;
stInjectAxis.rActualPressure := rInjectActualPressure;
stInjectAxis.rSetPressure := TO_LREAL(uiPresCmd);
stInjectAxis.rSetVelocity := TO_LREAL(uiSpdCmd);
stInjectAxis.rSetPosition := TO_LREAL(udiPosCmd);
stInjectAxis.stPumpRequest.bRequest := bBusy;
stInjectAxis.stPumpRequest.rPressureSet := TO_LREAL(uiPresCmd);
stInjectAxis.stPumpRequest.rFlowSet := TO_LREAL(uiSpdCmd);
IF bBusy THEN
    stInjectAxis.eAxisState := Running;
ELSE
    stInjectAxis.eAxisState := Idle;
END_IF;
stInjectAxis.nFaultCode := TO_INT(dwAlarmID);
bAxisEnableLocal := (NOT bStop) AND (NOT bEStop);

fbAxisInst(
    stAxisRef := stInjectAxis,
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
