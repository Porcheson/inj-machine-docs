(*
  FB_AutoCycle 功能块
  功能：
  1. 负责整机自动循环的步骤调度与运行状态管理。
  2. 只输出各模块的启动、复位和模式命令，不直接控制任何一根轴。
  3. 对外提供自动循环 Busy/Done/Alarm、动作提示和周期计数。

  设计原则：
  1. 每个自动步骤只负责一个主动作，便于状态判断和问题定位。
  2. 实际动作由主控层转发给合模、座台、射胶、储料、托模等模块执行。
  3. 复位、停机、急停统一在本块内收口，避免自动调度残留输出。
*)
FUNCTION_BLOCK FB_AutoCycle
VAR_INPUT
    (* 自动流程启动停止信号。 *)
    bStart: BOOL;
    bStop: BOOL;
    bEStop: BOOL;
    bReset: BOOL;

    (* 自动模式：0=停止 1=半自动 2=全自动。 *)
    uiAutoMode: UINT;

    (* 自动流程参数。 *)
    stAutoPara: ST_AutoCyclePara;

    (* 自动前置条件。 *)
    bDoorClosed: BOOL;
    bHydReady: BOOL;
    bSystemNoAlarm: BOOL;

    (* 合模模块反馈。 *)
    bClampDone: BOOL;
    bClampAlarm: BOOL;
    bMoldOpened: BOOL;
    bMoldClosed: BOOL;

    (* 座台模块反馈。 *)
    bNozzleDone: BOOL;
    bNozzleAlarm: BOOL;
    bNozzleIned: BOOL;
    bNozzleOuted: BOOL;

    (* 射胶模块反馈。 *)
    bInjectDone: BOOL;
    bInjectAlarm: BOOL;
    bHeld: BOOL;
    bSuckBacked: BOOL;

    (* 储料模块反馈。 *)
    bMeterDone: BOOL;
    bMeterAlarm: BOOL;
    bMetered: BOOL;

    (* 托模模块反馈。 *)
    bEjectDone: BOOL;
    bEjectAlarm: BOOL;
    bEjectIned: BOOL;
    bEjectOuted: BOOL;
END_VAR
VAR_OUTPUT
    (* 自动流程状态输出。 *)
    bBusy: BOOL;
    bDone: BOOL;
    bAlarm: BOOL;
    dwAlarmID: DWORD;
    uiActHint: UINT;
    uiActTime: UINT;
    uiCycleCount: UINT;

    (* 合模模块命令。 *)
    bClampStart: BOOL;
    bClampReset: BOOL;
    uiClampMode: UINT;

    (* 座台模块命令。 *)
    bNozzleStart: BOOL;
    bNozzleReset: BOOL;
    uiNozzleMode: UINT;

    (* 射胶模块命令。 *)
    bInjectStart: BOOL;
    bInjectReset: BOOL;
    uiInjectMode: UINT;

    (* 储料模块命令。 *)
    bMeterStart: BOOL;
    bMeterReset: BOOL;

    (* 托模模块命令。 *)
    bEjectStart: BOOL;
    bEjectReset: BOOL;
    uiEjectMode: UINT;
END_VAR
VAR
    eState: E_AutoCycleState := eState_Idle;
    ePrevState: E_AutoCycleState := eState_Idle;
    tPulse: TON;
    udiElapsedMs: UDINT := 0;
    bStateEntry: BOOL := FALSE;
    bReadyOk: BOOL := FALSE;
END_VAR

(* 每个扫描周期都先清空自动流程对子模块的输出命令，避免上一状态残留命令继续生效。 *)
bClampStart := FALSE;
bClampReset := FALSE;
uiClampMode := 0;
bNozzleStart := FALSE;
bNozzleReset := FALSE;
uiNozzleMode := 0;
bInjectStart := FALSE;
bInjectReset := FALSE;
uiInjectMode := 0;
bMeterStart := FALSE;
bMeterReset := FALSE;
bEjectStart := FALSE;
bEjectReset := FALSE;
uiEjectMode := 0;

bReadyOk := bDoorClosed AND bHydReady AND bSystemNoAlarm;   // 自动前置条件现只检查安全门、液压和系统无报警，不再依赖独立温度就绪回灌。
bStateEntry := (eState <> ePrevState);
ePrevState := eState;

IF bReset THEN
    (* 复位时统一回到空闲态，并向全部子模块发出一次复位脉冲。 *)
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := DWORD#0;
    uiActHint := 0;
    uiActTime := 0;
    uiCycleCount := 0;
    udiElapsedMs := 0;
    bClampReset := TRUE;
    bNozzleReset := TRUE;
    bInjectReset := TRUE;
    bMeterReset := TRUE;
    bEjectReset := TRUE;
    tPulse(IN := FALSE, PT := T#100MS);

ELSIF bEStop THEN
    (* 急停直接切入故障态，并强制撤销所有自动输出。 *)
    eState := eState_Error;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := TRUE;
    dwAlarmID := DWORD#16#8000;
    uiActHint := 1;
    uiActTime := 0;
    bClampReset := TRUE;
    bNozzleReset := TRUE;
    bInjectReset := TRUE;
    bMeterReset := TRUE;
    bEjectReset := TRUE;
    tPulse(IN := FALSE, PT := T#100MS);

ELSIF bStop THEN
    (* 正常停止回到空闲态，同时通知各子模块退出本轮自动动作。 *)
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    uiActHint := 0;
    uiActTime := 0;
    udiElapsedMs := 0;
    bClampReset := TRUE;
    bNozzleReset := TRUE;
    bInjectReset := TRUE;
    bMeterReset := TRUE;
    bEjectReset := TRUE;
    tPulse(IN := FALSE, PT := T#100MS);

ELSE
    CASE eState OF
        eState_Idle:
            bBusy := FALSE;
            uiActHint := 0;
            uiActTime := 0;
            udiElapsedMs := 0;
            tPulse(IN := FALSE, PT := T#100MS);

            IF bStart AND (uiAutoMode >= 1) AND (uiAutoMode <= 2) THEN
                bDone := FALSE;
                bAlarm := FALSE;
                dwAlarmID := DWORD#0;
                eState := eState_Init;
            END_IF;

        eState_Init:
            (* 初始化阶段只检查自动前置条件；条件满足后再真正进入自动循环。 *)
            bBusy := TRUE;
            bDone := FALSE;
            uiActHint := 1000;
            uiActTime := 0;
            tPulse(IN := FALSE, PT := T#100MS);

            IF bReadyOk THEN
                eState := eState_ClampClose;
            END_IF;

        eState_ClampClose:
            bBusy := TRUE;
            uiActHint := 81;

            IF bStateEntry THEN
                bClampReset := TRUE;
            ELSE
                uiClampMode := 2;
                bClampStart := TRUE;

                IF bClampAlarm THEN
                    dwAlarmID := DWORD#16#0001;
                    eState := eState_Error;
                ELSIF bMoldClosed OR bClampDone THEN
                    IF stAutoPara.bUseNozzle THEN
                        eState := eState_NozzleIn;
                    ELSIF stAutoPara.bUseInject THEN
                        eState := eState_Inject;
                    ELSE
                        eState := eState_PreCool;
                    END_IF;
                END_IF;
            END_IF;

        eState_NozzleIn:
            bBusy := TRUE;
            uiActHint := 113;

            IF bStateEntry THEN
                bNozzleReset := TRUE;
            ELSE
                uiNozzleMode := 1;
                bNozzleStart := TRUE;

                IF bNozzleAlarm THEN
                    dwAlarmID := DWORD#16#0002;
                    eState := eState_Error;
                ELSIF bNozzleIned OR bNozzleDone THEN
                    IF stAutoPara.bUseInject THEN
                        eState := eState_Inject;
                    ELSE
                        eState := eState_PreCool;
                    END_IF;
                END_IF;
            END_IF;

        eState_Inject:
            bBusy := TRUE;
            uiActHint := 44;

            IF bStateEntry THEN
                bInjectReset := TRUE;
            ELSE
                uiInjectMode := 1;
                bInjectStart := TRUE;

                IF bInjectAlarm THEN
                    dwAlarmID := DWORD#16#0004;
                    eState := eState_Error;
                ELSIF bHeld OR bInjectDone THEN
                    eState := eState_PreCool;
                END_IF;
            END_IF;

        eState_PreCool:
            bBusy := TRUE;
            uiActHint := 69;
            tPulse(IN := TRUE, PT := T#100MS);

            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;

            uiActTime := TO_UINT(udiElapsedMs / 1000);

            IF (stAutoPara.uiPreCoolTime = 0) OR (udiElapsedMs >= TO_UDINT(stAutoPara.uiPreCoolTime)) THEN
                udiElapsedMs := 0;
                tPulse(IN := FALSE, PT := T#100MS);

                IF stAutoPara.bUsePreSuckBack THEN
                    eState := eState_PreSuckBack;
                ELSIF stAutoPara.bUseMeter THEN
                    eState := eState_Meter;
                ELSIF stAutoPara.bUsePostSuckBack THEN
                    eState := eState_PostSuckBack;
                ELSE
                    eState := eState_PostCool;
                END_IF;
            END_IF;

        eState_PreSuckBack:
            bBusy := TRUE;
            uiActHint := 71;

            IF bStateEntry THEN
                bInjectReset := TRUE;
            ELSE
                uiInjectMode := 2;
                bInjectStart := TRUE;

                IF bInjectAlarm THEN
                    dwAlarmID := DWORD#16#0004;
                    eState := eState_Error;
                ELSIF bSuckBacked OR bInjectDone THEN
                    IF stAutoPara.bUseMeter THEN
                        eState := eState_Meter;
                    ELSIF stAutoPara.bUsePostSuckBack THEN
                        eState := eState_PostSuckBack;
                    ELSE
                        eState := eState_PostCool;
                    END_IF;
                END_IF;
            END_IF;

        eState_Meter:
            bBusy := TRUE;
            uiActHint := 11;

            IF bStateEntry THEN
                bMeterReset := TRUE;
            ELSE
                bMeterStart := TRUE;

                IF bMeterAlarm THEN
                    dwAlarmID := DWORD#16#0008;
                    eState := eState_Error;
                ELSIF bMetered OR bMeterDone THEN
                    IF stAutoPara.bUsePostSuckBack THEN
                        eState := eState_PostSuckBack;
                    ELSE
                        eState := eState_PostCool;
                    END_IF;
                END_IF;
            END_IF;

        eState_PostSuckBack:
            bBusy := TRUE;
            uiActHint := 72;

            IF bStateEntry THEN
                bInjectReset := TRUE;
            ELSE
                uiInjectMode := 2;
                bInjectStart := TRUE;

                IF bInjectAlarm THEN
                    dwAlarmID := DWORD#16#0004;
                    eState := eState_Error;
                ELSIF bSuckBacked OR bInjectDone THEN
                    eState := eState_PostCool;
                END_IF;
            END_IF;

        eState_PostCool:
            bBusy := TRUE;
            uiActHint := 70;
            tPulse(IN := TRUE, PT := T#100MS);

            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;

            uiActTime := TO_UINT(udiElapsedMs / 1000);

            IF (stAutoPara.uiPostCoolTime = 0) OR (udiElapsedMs >= TO_UDINT(stAutoPara.uiPostCoolTime)) THEN
                udiElapsedMs := 0;
                tPulse(IN := FALSE, PT := T#100MS);

                IF stAutoPara.bUseNozzle THEN
                    eState := eState_NozzleOut;
                ELSE
                    eState := eState_ClampOpen;
                END_IF;
            END_IF;

        eState_NozzleOut:
            bBusy := TRUE;
            uiActHint := 114;

            IF bStateEntry THEN
                bNozzleReset := TRUE;
            ELSE
                uiNozzleMode := 2;
                bNozzleStart := TRUE;

                IF bNozzleAlarm THEN
                    dwAlarmID := DWORD#16#0002;
                    eState := eState_Error;
                ELSIF bNozzleOuted OR bNozzleDone THEN
                    eState := eState_ClampOpen;
                END_IF;
            END_IF;

        eState_ClampOpen:
            bBusy := TRUE;
            uiActHint := 19;

            IF bStateEntry THEN
                bClampReset := TRUE;
            ELSE
                uiClampMode := 1;
                bClampStart := TRUE;

                IF bClampAlarm THEN
                    dwAlarmID := DWORD#16#0001;
                    eState := eState_Error;
                ELSIF bMoldOpened OR bClampDone THEN
                    IF stAutoPara.bUseEject THEN
                        eState := eState_EjectIn;
                    ELSE
                        eState := eState_CycleEnd;
                    END_IF;
                END_IF;
            END_IF;

        eState_EjectIn:
            bBusy := TRUE;
            uiActHint := 28;

            IF bStateEntry THEN
                bEjectReset := TRUE;
            ELSE
                uiEjectMode := 1;
                bEjectStart := TRUE;

                IF bEjectAlarm THEN
                    dwAlarmID := DWORD#16#0010;
                    eState := eState_Error;
                ELSIF bEjectIned OR bEjectDone THEN
                    eState := eState_EjectOut;
                END_IF;
            END_IF;

        eState_EjectOut:
            bBusy := TRUE;
            uiActHint := 31;

            IF bStateEntry THEN
                bEjectReset := TRUE;
            ELSE
                uiEjectMode := 2;
                bEjectStart := TRUE;

                IF bEjectAlarm THEN
                    dwAlarmID := DWORD#16#0010;
                    eState := eState_Error;
                ELSIF bEjectOuted OR bEjectDone THEN
                    eState := eState_CycleEnd;
                END_IF;
            END_IF;

        eState_CycleEnd:
            bBusy := FALSE;
            uiActHint := 1000;
            uiActTime := 0;

            IF bStateEntry THEN
                uiCycleCount := uiCycleCount + 1;
                bDone := TRUE;
            END_IF;

            IF uiAutoMode = 2 THEN
                IF (stAutoPara.uiAutoStopCount > 0) AND (uiCycleCount >= stAutoPara.uiAutoStopCount) THEN
                    IF NOT bStart THEN
                        eState := eState_Idle;
                    END_IF;
                ELSIF bReadyOk THEN
                    bDone := FALSE;
                    eState := eState_ClampClose;
                END_IF;
            ELSE
                IF NOT bStart THEN
                    eState := eState_Idle;
                END_IF;
            END_IF;

        eState_Error:
            bBusy := FALSE;
            bAlarm := TRUE;
            bDone := FALSE;
            uiActHint := 1;
            bClampReset := TRUE;
            bNozzleReset := TRUE;
            bInjectReset := TRUE;
            bMeterReset := TRUE;
            bEjectReset := TRUE;
            tPulse(IN := FALSE, PT := T#100MS);

    ELSE
        eState := eState_Error;
        dwAlarmID := DWORD#16#7FFF;
    END_CASE;
END_IF;
END_FUNCTION_BLOCK

