(* 
  FB_EjectMode 功能块
  功能：
  1. 在基础 `FB_Eject` 之上组合出定次、震动、停留三种托模模式。
  2. 通过内部顺序控制，把“托模进/托模退/托模保持”拼成更高层动作。
  3. 对外仍保持与普通托模模块相似的 Busy/Done/Alarm 接口，便于主控统一调用。

  说明：
  1. 本块本身不直接生成工艺命令，而是直接复用 `FB_Eject` 完成具体动作。
  2. `uiSeqPhase` 用来表示当前执行到“复位子块、托进、再次复位、托退”的哪一步。
  3. 只有在手动组合模式被上层明确选择时，才应该让本块接管托模轴输出。
*)
FUNCTION_BLOCK FB_EjectMode
VAR_IN_OUT
    stEjectAxis: ST_AxisRefHyd;   // 托模共享轴结构，内部复用的 `FB_Eject` 直接操作该轴
END_VAR
VAR_INPUT
    bStart: BOOL;                 // TRUE=启动组合托模模式
    bStop: BOOL;                  // TRUE=正常停止当前组合流程
    bEStop: BOOL;                 // TRUE=急停，立即撤销对子块的命令
    bReset: BOOL;                 // TRUE=复位本块及内部 `FB_Eject`
    uiEjectMode: UINT;            // 1=定次 2=震动 3=停留
    uiEjectTimes: UINT;           // 定次/震动次数；震动模式下 0 表示持续循环
    stEjectPara: ST_EjectPara;    // 传给内部 `FB_Eject` 的托模工艺参数
    bEjectInStop: BOOL;           // 托模进停止信号，直接透传给内部 `FB_Eject`
    bEjectOutStop: BOOL;          // 托模退停止信号，直接透传给内部 `FB_Eject`
    udiEjectElecRulerVal: UDINT;  // 托模电子尺反馈，直接透传给内部 `FB_Eject`
    rEjectActualPosition: LREAL;  // 托模轴实际位置反馈
    rEjectActualVelocity: LREAL;  // 托模轴实际速度反馈
    rEjectActualPressure: LREAL;  // 托模轴实际压力反馈
END_VAR
VAR_OUTPUT
    bBusy: BOOL;                  // TRUE=组合托模模式尚未完成
    bDone: BOOL;                  // TRUE=组合托模模式完成
    bAlarm: BOOL;                 // TRUE=本块或内部 `FB_Eject` 报警
    dwAlarmID: DWORD;             // 组合块报警码，优先透传子块报警
    uiActHint: UINT;              // 当前动作提示码，默认复用子块提示
    uiActTime: UINT;              // 当前动作持续时间，默认复用子块计时
    bEjectIned: BOOL;             // TRUE=内部托模进完成
    bEjectOuted: BOOL;            // TRUE=内部托模退完成
    uiPresCmd: UINT;              // 当前对子块输出的压力命令镜像
    uiSpdCmd: UINT;               // 当前对子块输出的速度命令镜像
    udiPosCmd: UDINT;             // 当前对子块输出的位置命令镜像
END_VAR
VAR
    eState: E_EjectModeState := eState_Idle; // 当前组合托模状态机状态
    fbEject: FB_Eject;                       // 内部基础托模块实例，实际液压命令由它生成

    (* 发给内部 `FB_Eject` 的命令。 *)
    bCmdStart: BOOL := FALSE;               // TRUE=本拍触发内部 `FB_Eject` 启动
    bCmdReset: BOOL := FALSE;               // TRUE=本拍复位内部 `FB_Eject`
    uiCmdMode: UINT := 0;                   // 发给内部 `FB_Eject` 的模式号，1=托进 2=托退

    (* 顺序控制变量。 *)
    uiExecCount: UINT := 0;                 // 已完成的往返或震动次数
    uiSeqPhase: UINT := 0;                  // 当前子流程相位：0复位前置 1托进 2退前复位 3托退

    (* 内部 `FB_Eject` 状态缓存。 *)
    bSubBusy: BOOL := FALSE;                // 内部 `FB_Eject` Busy 状态缓存
    bSubDone: BOOL := FALSE;                // 内部 `FB_Eject` Done 状态缓存
    bSubAlarm: BOOL := FALSE;               // 内部 `FB_Eject` Alarm 状态缓存
    dwSubAlarmID: DWORD := 0;               // 内部 `FB_Eject` 报警码缓存
    uiSubActHint: UINT := 0;                // 内部 `FB_Eject` 当前动作提示缓存
    uiSubActTime: UINT := 0;                // 内部 `FB_Eject` 当前动作时间缓存
    bSubEjectIned: BOOL := FALSE;           // 内部 `FB_Eject` 托模进完成缓存
    bSubEjectOuted: BOOL := FALSE;          // 内部 `FB_Eject` 托模退完成缓存
    uiSubPresCmd: UINT := 0;                // 内部 `FB_Eject` 压力命令缓存
    uiSubSpdCmd: UINT := 0;                 // 内部 `FB_Eject` 速度命令缓存
    udiSubPosCmd: UDINT := 0;               // 内部 `FB_Eject` 位置命令缓存
END_VAR

(* 每个扫描周期先清空对子块的控制命令。 *)
bCmdStart := FALSE;
bCmdReset := FALSE;
uiCmdMode := 0;

(* 复位优先级最高：本块回空闲，同时给内部子块打一拍复位。 *)
IF bReset THEN
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := DWORD#0;
    uiActHint := 0;
    uiActTime := 0;
    uiExecCount := 0;
    uiSeqPhase := 0;
    bCmdReset := TRUE;

(* 急停直接转故障态，并强制复位子块，确保托模轴命令被撤销。 *)
ELSIF bEStop THEN
    eState := eState_Error;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := TRUE;
    dwAlarmID := DWORD#16#0010;
    uiActHint := 1;
    uiActTime := 0;
    uiExecCount := 0;
    uiSeqPhase := 0;
    bCmdReset := TRUE;

(* 正常停止直接回空闲，同样复位子块，避免保留上一个动作的完成态。 *)
ELSIF bStop THEN
    eState := eState_Idle;
    bBusy := FALSE;
    bDone := FALSE;
    bAlarm := FALSE;
    dwAlarmID := DWORD#0;
    uiActHint := 0;
    uiActTime := 0;
    uiExecCount := 0;
    uiSeqPhase := 0;
    bCmdReset := TRUE;

ELSE
    CASE eState OF
        (* 空闲态：等待启动，并按组合模式切入定次、震动或停留逻辑。 *)
        eState_Idle:
            bBusy := FALSE;
            uiActHint := 0;
            uiActTime := 0;

            IF bStart THEN
                bDone := FALSE;
                bAlarm := FALSE;
                dwAlarmID := DWORD#0;
                uiExecCount := 0;
                uiSeqPhase := 0;

                CASE uiEjectMode OF
                    1: eState := eState_EjectCount;
                    2: eState := eState_EjectVibra;
                    3: eState := eState_EjectHold;
                ELSE
                    bAlarm := TRUE;
                    dwAlarmID := DWORD#16#0001;
                    eState := eState_Error;
                END_CASE;
            END_IF;

        (* 定次托模态：按“托进 -> 托退”为一个完整循环，达到次数后结束。 *)
        eState_EjectCount:
            bBusy := TRUE;

            IF bSubAlarm THEN
                dwAlarmID := dwSubAlarmID;
                eState := eState_Error;
            ELSE
                (* `uiSeqPhase` 把一个往返拆成“复位子块、托进、再次复位、托退”四步。 *)
                CASE uiSeqPhase OF
                    0:
                        (* 子块切换动作前先复位，避免沿用上一个动作的完成态。 *)
                        bCmdReset := TRUE;
                        uiSeqPhase := 1;

                    1:
                        (* 托模进。 *)
                        uiCmdMode := 1;
                        bCmdStart := TRUE;
                        IF bSubDone THEN
                            uiSeqPhase := 2;
                        END_IF;

                    2:
                        (* 进入托模退前再复位一次子块。 *)
                        bCmdReset := TRUE;
                        uiSeqPhase := 3;

                    3:
                        (* 托模退。 *)
                        uiCmdMode := 2;
                        bCmdStart := TRUE;
                        IF bSubDone THEN
                            uiExecCount := uiExecCount + 1;
                            (* 定次模式下 `uiEjectTimes = 0` 仍按 1 次收口，避免无终点循环。 *)
                            IF uiExecCount >= SEL(uiEjectTimes = 0, uiEjectTimes, 1) THEN
                                bBusy := FALSE;
                                bDone := TRUE;
                                eState := eState_Idle;
                            ELSE
                                uiSeqPhase := 0;
                            END_IF;
                        END_IF;

                ELSE
                    uiSeqPhase := 0;
                END_CASE;
            END_IF;

        (* 震动态：同样执行“托进 -> 托退”循环，但 `uiEjectTimes = 0` 表示持续循环。 *)
        eState_EjectVibra:
            bBusy := TRUE;

            IF bSubAlarm THEN
                dwAlarmID := dwSubAlarmID;
                eState := eState_Error;
            ELSE
                (* 相位定义与定次模式一致，只是结束条件不同。 *)
                CASE uiSeqPhase OF
                    0:
                        bCmdReset := TRUE;
                        uiSeqPhase := 1;

                    1:
                        uiCmdMode := 1;
                        bCmdStart := TRUE;
                        IF bSubDone THEN
                            uiSeqPhase := 2;
                        END_IF;

                    2:
                        bCmdReset := TRUE;
                        uiSeqPhase := 3;

                    3:
                        uiCmdMode := 2;
                        bCmdStart := TRUE;
                        IF bSubDone THEN
                            uiExecCount := uiExecCount + 1;
                            IF (uiEjectTimes > 0) AND (uiExecCount >= uiEjectTimes) THEN
                                bBusy := FALSE;
                                bDone := TRUE;
                                eState := eState_Idle;
                            ELSE
                                uiSeqPhase := 0;
                            END_IF;
                        END_IF;

                ELSE
                    uiSeqPhase := 0;
                END_CASE;
            END_IF;

        (* 停留态：只执行一次托模进，完成后停在前进端。 *)
        eState_EjectHold:
            bBusy := TRUE;

            IF bSubAlarm THEN
                dwAlarmID := dwSubAlarmID;
                eState := eState_Error;
            ELSE
                (* 停留模式只需要“复位子块 -> 托进”两个步骤。 *)
                CASE uiSeqPhase OF
                    0:
                        bCmdReset := TRUE;
                        uiSeqPhase := 1;

                    1:
                        uiCmdMode := 1;
                        bCmdStart := TRUE;
                        IF bSubDone THEN
                            bBusy := FALSE;
                            bDone := TRUE;
                            eState := eState_Idle;
                        END_IF;

                ELSE
                    uiSeqPhase := 0;
                END_CASE;
            END_IF;

        (* 故障态：统一复位子块，并保留报警信息给主控/HMI。 *)
        eState_Error:
            bBusy := FALSE;
            bDone := FALSE;
            bAlarm := TRUE;
            uiActHint := 1;
            IF dwAlarmID = DWORD#0 THEN
                dwAlarmID := SEL(dwSubAlarmID = DWORD#0, dwSubAlarmID, DWORD#16#0001);
            END_IF;
            bCmdReset := TRUE;

    ELSE
        dwAlarmID := DWORD#16#7FFF;
        eState := eState_Error;
    END_CASE;
END_IF;

(* 最后再调用内部子块，这样本扫描周期内刚决策出来的命令能立即送到子块。 *)
fbEject(
    stEjectAxis := stEjectAxis,
    bStart := bCmdStart,
    bStop := bStop,
    bEStop := bEStop,
    bReset := bCmdReset,
    bManualMode := FALSE,
    uiEjectMode := uiCmdMode,
    stEjectPara := stEjectPara,
    bEjectInStop := bEjectInStop,
    bEjectOutStop := bEjectOutStop,
    udiEjectElecRulerVal := udiEjectElecRulerVal,
    rEjectActualPosition := rEjectActualPosition,
    rEjectActualVelocity := rEjectActualVelocity,
    rEjectActualPressure := rEjectActualPressure,
    bBusy => bSubBusy,
    bDone => bSubDone,
    bAlarm => bSubAlarm,
    dwAlarmID => dwSubAlarmID,
    uiActHint => uiSubActHint,
    uiActTime => uiSubActTime,
    bEjectIned => bSubEjectIned,
    bEjectOuted => bSubEjectOuted,
    uiPresCmd => uiSubPresCmd,
    uiSpdCmd => uiSubSpdCmd,
    udiPosCmd => udiSubPosCmd
);

(* 对外透传内部托模块的实际动作输出，便于主控统一读取。 *)
bEjectIned := bSubEjectIned;
bEjectOuted := bSubEjectOuted;
uiPresCmd := uiSubPresCmd;
uiSpdCmd := uiSubSpdCmd;
udiPosCmd := udiSubPosCmd;

(* 未报警时优先显示子块动作提示，让外部看到当前托进/托退所在步骤。 *)
IF (NOT bAlarm) AND (uiSubActHint <> 0) THEN
    uiActHint := uiSubActHint;
END_IF;
uiActTime := uiSubActTime;
END_FUNCTION_BLOCK
