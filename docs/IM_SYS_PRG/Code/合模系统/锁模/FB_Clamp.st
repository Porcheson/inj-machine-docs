(* 
  FB_Clamp 功能块
  功能：
  1. 负责开模、合模、低压合模、高压锁模以及调试动作的执行状态机。
  2. 按开合模工艺段生成压力、速度、位置命令，并输出模具开闭状态。

  说明：
  1. 正常自动模式使用 1=开模、2=合模；调试模式使用 3=开模调试、4=合模调试。
  2. 本块只生成工艺层命令，最终轴限幅与诊断由 `FB_HydAxis` 处理。
*)
FUNCTION_BLOCK FB_Clamp
VAR_IN_OUT
    ClampAxis: ST_AxisRefHyd;         // 合模共享轴结构
END_VAR
VAR_INPUT
    bStart: BOOL;                     // TRUE=启动本次合模动作
    bStop: BOOL;                      // TRUE=正常停止
    bEStop: BOOL;                     // TRUE=急停
    bReset: BOOL;                     // TRUE=复位状态机与输出
    bManualMode: BOOL;                // TRUE=手动点动开合模
    uiClampMode: UINT;                // 1=开模 2=合模 3=开模调试 4=合模调试
    stClampPara: ST_ClampPara;        // 合模工艺参数
    bOpenStop: BOOL;                  // 开模到位/停止信号
    bCloseLowPres: BOOL;              // 低压合模到位信号
    bCloseHighPres: BOOL;             // 高压锁模到位信号
    bCloseStop: BOOL;                 // 合模停止信号
    udiClampElecRulerVal: UDINT;      // 开合模电子尺反馈
    uiClampPresElecRulerVal: UINT;    // 合模压力反馈
    rClampActualPosition: LREAL;      // 合模轴实际位置反馈
    rClampActualVelocity: LREAL;      // 合模轴实际速度反馈
    rClampActualPressure: LREAL;      // 合模轴实际压力反馈
END_VAR
VAR_OUTPUT
    bBusy: BOOL;                      // TRUE=当前动作尚未结束
    bDone: BOOL;                      // TRUE=当前动作完成
    bAlarm: BOOL;                     // TRUE=当前动作报警
    dwAlarmID: DWORD;                 // 模块报警码
    uiActHint: UINT;                  // 当前动作提示码
    uiActTime: UINT;                  // 当前动作持续时间，单位 s
    bMoldOpened: BOOL;                // TRUE=开模完成
    bMoldClosed: BOOL;                // TRUE=合模完成
    aCoreAllow: ARRAY[1..8] OF BOOL;  // 中子允许数组
    uiPresCmd: UINT;                  // 压力命令输出
    uiSpdCmd: UINT;                   // 速度命令输出
    udiPosCmd: UDINT;                 // 位置命令输出
END_VAR
VAR
    eState: E_ClampState := eState_Idle; // 当前合模状态机状态
    fbAxisInst: FB_HydAxis;              // 合模轴层实例
    stAxisStatusLocal: ST_HydAxisStatus; // 合模轴层状态缓存
    stAxisConfigLocal: ST_HydAxisConfig := (
        nAxisID := 1,
        rMaxCylinderStroke := 10000.0,
        rMaxVelocity := 1000.0,
        rMaxPressure := 1000.0,
        rPosTolerance := 0.5,
        rVelTolerance := 0.5,
        rPresTolerance := 0.5
    );
    bAxisEnableLocal: BOOL := FALSE;     // 合模轴层使能，由模块内部根据停机/急停收口
    tPulse: TON;                         // 100ms 节拍定时器，用于把扫描周期累加成动作时间
    uiStageIndex: UINT := 0;             // 当前执行到的工艺段号
    uiStageCount: UINT := 0;             // 当前方向允许执行的有效段数，进入动作时做边界收口
    uiIndex: UINT := 0;                  // 循环索引，用于刷新中子允许数组
    udiStageElapsedMs: UDINT := 0;       // 当前工艺段已运行时间，单位 ms
    udiTotalElapsedMs: UDINT := 0;       // 本次开模或合模动作总耗时，单位 ms
    bManualActive: BOOL := FALSE;        // TRUE=当前按调试/手动逻辑执行，不走完整工艺段推进
    bOpenRequest: BOOL := FALSE;         // TRUE=本次请求方向为开模
    bCloseRequest: BOOL := FALSE;        // TRUE=本次请求方向为合模
    bStepDone: BOOL := FALSE;            // 当前段完成标志，由位置/停止信号/时间任一条件置位
    bCloseDone: BOOL := FALSE;           // 高压锁模结束标志，由锁模结束模式统一置位
    stSegCmd: ST_ClampSeg;               // 当前生效的开模或合模段命令缓存
END_VAR

(* 每拍先把模式号解码成统一的请求标志，后续状态机只判断“开模/合模/手动”三个语义。 *)
bManualActive := bManualMode OR (uiClampMode = 3) OR (uiClampMode = 4);
bOpenRequest := (uiClampMode = 1) OR (uiClampMode = 3);
bCloseRequest := (uiClampMode = 2) OR (uiClampMode = 4);
bStepDone := FALSE;
bCloseDone := FALSE;

(* 根据合模参数里的中子功能位实时生成允许数组，供主控转发给中子模块做互锁。 *)
FOR uiIndex := 1 TO 8 DO
    aCoreAllow[uiIndex] := (stClampPara.aCoreFn[uiIndex] = 1);
END_FOR;

(* 复位优先级最高：无论动作进行到哪里，都强制回到空闲并清空命令、计时和完成态。 *)
IF bReset THEN
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := 0;
    uiActHint := 0;
    uiActTime := 0;
    bMoldOpened := FALSE;
    bMoldClosed := FALSE;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    uiStageIndex := 0;
    uiStageCount := 0;
    udiStageElapsedMs := 0;
    udiTotalElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 急停直接打入故障态，同时撤销压力/速度/位置命令，避免轴继续运动。 *)
ELSIF bEStop THEN
    eState := eState_Error;
    bBusy := FALSE;
    bAlarm := TRUE;
    dwAlarmID := dwAlarmID OR DWORD#16#0010;
    uiActHint := 1;
    uiActTime := 0;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    tPulse(IN := FALSE, PT := T#100MS);
(* 正常停止不保留当前段上下文，等待下一次显式启动重新进入流程。 *)
ELSIF bStop THEN
    eState := eState_Idle;
    bBusy := FALSE;
    uiPresCmd := 0;
    uiSpdCmd := 0;
    udiPosCmd := 0;
    uiActHint := 0;
    udiStageElapsedMs := 0;
    udiTotalElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
ELSE
    CASE eState OF
        (* 空闲态：输出全部归零，等待启动沿，并根据模式号决定进入开模还是合模初始化。 *)
        eState_Idle:
            bBusy := FALSE;
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            uiActHint := 0;
            uiActTime := 0;
            uiStageIndex := 0;
            uiStageCount := 0;
            udiStageElapsedMs := 0;
            udiTotalElapsedMs := 0;
            tPulse(IN := FALSE, PT := T#100MS);
            IF bStart THEN
                bDone := FALSE;
                bAlarm := FALSE;
                dwAlarmID := 0;
                bMoldOpened := FALSE;
                bMoldClosed := FALSE;
                eState := eState_Init;
            END_IF;

        (* 初始化态：收口有效段数、重置段号，并决定开模是否先经过卸压。 *)
        eState_Init:
            bBusy := TRUE;
            uiActTime := 0;
            udiStageElapsedMs := 0;
            udiTotalElapsedMs := 0;
            tPulse(IN := FALSE, PT := T#100MS);

            (* 开模请求支持最多 5 段；自动模式先卸压，手动模式直接进开模调试。 *)
            IF bOpenRequest THEN
                uiStageCount := stClampPara.uiOpenSegCnt;
                IF uiStageCount < 1 THEN
                    uiStageCount := 1;
                END_IF;
                IF uiStageCount > 5 THEN
                    uiStageCount := 5;
                END_IF;
                uiStageIndex := 1;

                IF bManualActive THEN
                    eState := eState_Opening;
                ELSE
                    eState := eState_OpenUnload;
                END_IF;
            (* 合模请求支持最多 3 段，随后统一进入合模段推进。 *)
            ELSIF bCloseRequest THEN
                uiStageCount := stClampPara.uiCloseSegCnt;
                IF uiStageCount < 1 THEN
                    uiStageCount := 1;
                END_IF;
                IF uiStageCount > 3 THEN
                    uiStageCount := 3;
                END_IF;
                uiStageIndex := 1;
                eState := eState_Closing;
            (* 模式号无法解析为开模或合模时，直接报参数类报警。 *)
            ELSE
                bAlarm := TRUE;
                dwAlarmID := DWORD#16#0008;
                eState := eState_Error;
            END_IF;

        (* 开模卸压态：先输出卸压段命令，避免模具仍带高压时直接开模。 *)
        eState_OpenUnload:
            bBusy := TRUE;
            uiActHint := 18;
            uiPresCmd := stClampPara.stOpenUnloadPres.uiPres;
            uiSpdCmd := stClampPara.stOpenUnloadPres.uiSpd;
            udiPosCmd := stClampPara.stOpenUnloadPres.udiPos;

            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiStageElapsedMs := udiStageElapsedMs + 100;
                udiTotalElapsedMs := udiTotalElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiTotalElapsedMs / 1000);

            (* 卸压时间到后转入正式开模；若卸压时间为 0，则视为本拍立即完成。 *)
            IF (stClampPara.stOpenUnloadPres.uiTime = 0) OR (udiStageElapsedMs >= TO_UDINT(stClampPara.stOpenUnloadPres.uiTime)) THEN
                eState := eState_Opening;
                udiStageElapsedMs := 0;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;

            (* 开模总时长超限时进入故障，报警码按开模超时叠加。 *)
            IF (stClampPara.uiOpenLimitTime > 0) AND (udiTotalElapsedMs >= TO_UDINT(stClampPara.uiOpenLimitTime)) THEN
                dwAlarmID := dwAlarmID OR DWORD#16#0002;
                eState := eState_Error;
            END_IF;

        (* 开模执行态：手动模式持续输出单段调试命令，自动模式按段推进。 *)
        eState_Opening:
            bBusy := TRUE;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiStageElapsedMs := udiStageElapsedMs + 100;
                udiTotalElapsedMs := udiTotalElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiTotalElapsedMs / 1000);

            (* 调试开模优先取调试段；若调试段未配置，则回退到第一段正式参数。 *)
            IF bManualActive THEN
                stSegCmd := stClampPara.stOpenDebug;
                IF (stSegCmd.uiPres = 0) AND (stSegCmd.uiSpd = 0) AND (stSegCmd.udiPos = 0) THEN
                    stSegCmd := stClampPara.aOpenSeg[1];
                END_IF;
                uiActHint := 40;
                uiPresCmd := stSegCmd.uiPres;
                uiSpdCmd := stSegCmd.uiSpd;
                udiPosCmd := stSegCmd.udiPos;

                IF (NOT bStart) OR bOpenStop THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动开模按当前段输出命令，并根据位置、停止信号或段时间判断段完成。 *)
            ELSE
                IF uiStageIndex > uiStageCount THEN
                    eState := eState_Opened;
                    uiPresCmd := 0;
                    uiSpdCmd := 0;
                    udiPosCmd := 0;
                ELSE
                    stSegCmd := stClampPara.aOpenSeg[uiStageIndex];
                    uiActHint := 83 + uiStageIndex;
                    uiPresCmd := stSegCmd.uiPres;
                    uiSpdCmd := stSegCmd.uiSpd;
                    udiPosCmd := stSegCmd.udiPos;

                    IF (stClampPara.uiOpenMode = 0) AND (udiClampElecRulerVal >= stSegCmd.udiPos) THEN
                        bStepDone := TRUE;
                    END_IF;
                    IF (stClampPara.uiOpenMode = 1) AND bOpenStop THEN
                        bStepDone := TRUE;
                    END_IF;
                    IF (stSegCmd.uiTime > 0) AND (udiStageElapsedMs >= TO_UDINT(stSegCmd.uiTime)) THEN
                        bStepDone := TRUE;
                    END_IF;

                    (* 当前段满足任一完成条件后推进到下一段，并清零段计时。 *)
                    IF bStepDone THEN
                        uiStageIndex := uiStageIndex + 1;
                        udiStageElapsedMs := 0;
                        tPulse(IN := FALSE, PT := T#100MS);
                    END_IF;
                END_IF;

                (* 自动开模仍受总开模时间保护，避免段间切换异常导致长时间动作。 *)
                IF (stClampPara.uiOpenLimitTime > 0) AND (udiTotalElapsedMs >= TO_UDINT(stClampPara.uiOpenLimitTime)) THEN
                    dwAlarmID := dwAlarmID OR DWORD#16#0002;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 开模完成态：对外发布完成标志与开模完成状态，并撤销轴命令。 *)
        eState_Opened:
            bBusy := FALSE;
            bDone := TRUE;
            bMoldOpened := TRUE;
            uiActHint := 2;
            uiActTime := TO_UINT(udiTotalElapsedMs / 1000);
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            tPulse(IN := FALSE, PT := T#100MS);

        (* 合模执行态：先完成普通合模段，再转入低压保护和高压锁模。 *)
        eState_Closing:
            bBusy := TRUE;
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiStageElapsedMs := udiStageElapsedMs + 100;
                udiTotalElapsedMs := udiTotalElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiTotalElapsedMs / 1000);

            (* 调试合模持续输出单段命令，松开启动或收到停止信号就回空闲。 *)
            IF bManualActive THEN
                stSegCmd := stClampPara.stCloseDebug;
                IF (stSegCmd.uiPres = 0) AND (stSegCmd.uiSpd = 0) AND (stSegCmd.udiPos = 0) THEN
                    stSegCmd := stClampPara.aCloseSeg[1];
                END_IF;
                uiActHint := 41;
                uiPresCmd := stSegCmd.uiPres;
                uiSpdCmd := stSegCmd.uiSpd;
                udiPosCmd := stSegCmd.udiPos;

                IF (NOT bStart) OR bCloseStop THEN
                    eState := eState_Idle;
                END_IF;
            (* 自动合模按段推进，段完成后进入低压合模阶段。 *)
            ELSE
                IF uiStageIndex <= uiStageCount THEN
                    stSegCmd := stClampPara.aCloseSeg[uiStageIndex];
                    uiActHint := 80 + uiStageIndex;
                    uiPresCmd := stSegCmd.uiPres;
                    uiSpdCmd := stSegCmd.uiSpd;
                    udiPosCmd := stSegCmd.udiPos;

                    IF (stClampPara.uiCloseMode = 0) AND (udiClampElecRulerVal >= stSegCmd.udiPos) THEN
                        bStepDone := TRUE;
                    END_IF;
                    IF (stSegCmd.uiTime > 0) AND (udiStageElapsedMs >= TO_UDINT(stSegCmd.uiTime)) THEN
                        bStepDone := TRUE;
                    END_IF;

                    (* 当前合模段完成后切到下一段，并重新累计本段时间。 *)
                    IF bStepDone THEN
                        uiStageIndex := uiStageIndex + 1;
                        udiStageElapsedMs := 0;
                        tPulse(IN := FALSE, PT := T#100MS);
                    END_IF;
                ELSE
                    eState := eState_CloseLowPress;
                    udiStageElapsedMs := 0;
                    tPulse(IN := FALSE, PT := T#100MS);
                END_IF;

                (* 合模总时间超限统一按合模超时报警处理。 *)
                IF (stClampPara.uiCloseLimitTime > 0) AND (udiTotalElapsedMs >= TO_UDINT(stClampPara.uiCloseLimitTime)) THEN
                    dwAlarmID := dwAlarmID OR DWORD#16#0004;
                    eState := eState_Error;
                END_IF;
            END_IF;

        (* 低压合模态：以保护模具为目的缓慢闭合，等待低压到位信号。 *)
        eState_CloseLowPress:
            bBusy := TRUE;
            uiActHint := 30;
            uiPresCmd := stClampPara.stCloseLowPres.uiPres;
            uiSpdCmd := stClampPara.stCloseLowPres.uiSpd;
            udiPosCmd := stClampPara.stCloseLowPres.udiPos;

            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiStageElapsedMs := udiStageElapsedMs + 100;
                udiTotalElapsedMs := udiTotalElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiTotalElapsedMs / 1000);

            (* 低压到位后才允许进入高压锁模。 *)
            IF bCloseLowPres THEN
                eState := eState_CloseHighPress;
                udiStageElapsedMs := 0;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;

            (* 低压合模超时说明保护段未在规定时间内结束，直接报警停机。 *)
            IF (stClampPara.uiCloseLowPresLimitTime > 0) AND (udiStageElapsedMs >= TO_UDINT(stClampPara.uiCloseLowPresLimitTime)) THEN
                dwAlarmID := dwAlarmID OR DWORD#16#0001;
                eState := eState_Error;
            END_IF;

        (* 高压锁模态：输出最终锁模压力/速度/位置，并按结束模式判定锁模完成。 *)
        eState_CloseHighPress:
            bBusy := TRUE;
            uiActHint := 31;
            uiPresCmd := stClampPara.stCloseHighPres.uiPres;
            uiSpdCmd := stClampPara.stCloseHighPres.uiSpd;
            udiPosCmd := stClampPara.stCloseHighPres.udiPos;

            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiStageElapsedMs := udiStageElapsedMs + 100;
                udiTotalElapsedMs := udiTotalElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            uiActTime := TO_UINT(udiTotalElapsedMs / 1000);

            (* 锁模结束模式支持按时间、按停止/到位信号、按压力阈值三种判断。 *)
            CASE stClampPara.uiCloseEndMode OF
                0:
                    IF (stClampPara.stCloseHighPres.uiTime = 0) OR (udiStageElapsedMs >= TO_UDINT(stClampPara.stCloseHighPres.uiTime)) THEN
                        bCloseDone := TRUE;
                    END_IF;
                1:
                    IF bCloseStop OR bCloseHighPres THEN
                        bCloseDone := TRUE;
                    END_IF;
                2:
                    IF uiClampPresElecRulerVal >= stClampPara.uiCloseEndHighPres THEN
                        bCloseDone := TRUE;
                    END_IF;
            ELSE
                IF bCloseStop OR bCloseHighPres THEN
                    bCloseDone := TRUE;
                END_IF;
            END_CASE;

            (* 满足锁模完成条件后进入完成态，保持完成标志直到外部复位或重新启动。 *)
            IF bCloseDone THEN
                eState := eState_Closed;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;

            (* 高压阶段也受合模总时间约束，避免高压长期保持。 *)
            IF (stClampPara.uiCloseLimitTime > 0) AND (udiTotalElapsedMs >= TO_UDINT(stClampPara.uiCloseLimitTime)) THEN
                dwAlarmID := dwAlarmID OR DWORD#16#0004;
                eState := eState_Error;
            END_IF;

        (* 合模完成态：对外发布合模完成标志，并把轴命令全部清零。 *)
        eState_Closed:
            bBusy := FALSE;
            bDone := TRUE;
            bMoldClosed := TRUE;
            uiActHint := 3;
            uiActTime := TO_UINT(udiTotalElapsedMs / 1000);
            uiPresCmd := 0;
            uiSpdCmd := 0;
            udiPosCmd := 0;
            tPulse(IN := FALSE, PT := T#100MS);

        (* 故障态：统一撤销命令，只保留报警信息给主控和 HMI 读取。 *)
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

(* 将工艺层输出统一回写到共享轴结构，后续由 `FB_HydAxis` 做最终限幅和诊断。 *)
ClampAxis.rActualPosition := rClampActualPosition;
ClampAxis.rActualVelocity := rClampActualVelocity;
ClampAxis.rActualPressure := rClampActualPressure;
ClampAxis.rSetPressure := TO_LREAL(uiPresCmd);
ClampAxis.rSetVelocity := TO_LREAL(uiSpdCmd);
ClampAxis.rSetPosition := TO_LREAL(udiPosCmd);
ClampAxis.stPumpRequest.bRequest := bBusy;
ClampAxis.stPumpRequest.rPressureSet := TO_LREAL(uiPresCmd);
ClampAxis.stPumpRequest.rFlowSet := TO_LREAL(uiSpdCmd);
IF bBusy THEN
    ClampAxis.eAxisState := Running;
ELSE
    ClampAxis.eAxisState := Idle;
END_IF;
ClampAxis.nFaultCode := TO_INT(dwAlarmID);
bAxisEnableLocal := (NOT bStop) AND (NOT bEStop);

fbAxisInst(
    stAxisRef := ClampAxis,
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
