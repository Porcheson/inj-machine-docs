(*
  FB_EK312 功能块
  功能：
  1. 提供 12 路温控的统一控制与状态输出接口。
  2. 温控启动后按顶层下发的 100ms 刷新拍执行升温计算；当 R0~R3 有人工组命令时，对应分组直接加热。
  3. 对外输出温控完成、报警、热状态和每一路段状态。

  说明：
  1. 当前实现是控制/仿真一体化逻辑，便于在无真实温控器时联调主控。
  2. `PROGRAM PRG_MainControl` 必须持续以 1ms 基础任务调用本块，并在 `bLogicTick100msIn` 上提供固定 100ms 温控刷新拍。
  3. 若后续接入真实温控器，可保留本接口不变，仅替换内部驱动实现。
*)
FUNCTION_BLOCK FB_EK312
VAR_INPUT
    bStart: BOOL;                 // TRUE=启动温控；顶层保持该命令后，本块开始进入升温状态机。
    bStop: BOOL;                  // TRUE=停止温控；无论是否命中 100ms 刷新拍，都必须立即撤销执行态。
    bReset: BOOL;                 // TRUE=复位温控状态；无论是否命中 100ms 刷新拍，都必须立即回到安全初值。
    bR0: BOOL;                    // 人工直接加热组 0，对应第 1~3 段。
    bR1: BOOL;                    // 人工直接加热组 1，对应第 4~6 段。
    bR2: BOOL;                    // 人工直接加热组 2，对应第 7~9 段。
    bR3: BOOL;                    // 人工直接加热组 3，对应第 10~12 段。
    stInPara: ST_EK312InPara;     // 温控输入参数，包含各段启用位、目标温度和上下限。
END_VAR
VAR_OUTPUT
    bBusy: BOOL;                  // TRUE=温控正在执行，表示当前状态机处于初始化或升温阶段。
    bDone: BOOL;                  // TRUE=全部有效段达到设定温度，表示当前温控已就绪。
    bAlarm: BOOL;                 // TRUE=出现温控报警，表示至少一段越上限或越下限。
    dwAlarmID: DWORD;             // 温控报警码，按位叠加各类温度异常。
    stOutPara: ST_EK312OutPara;   // 温控输出状态，包含各段实际温度、状态和加热输出地址镜像。
    uiHeatState: UINT;            // 0=停止 1=升温 2=已就绪，供 HMI 直接显示当前热状态。
    uiVersion: UINT;              // 模块版本号，便于后续在线辨识温控块实现版本。
END_VAR
VAR
    eState: E_EK312State := eState_Idle;   // 当前温控状态机状态。
    uiCycle: UINT := 0;                    // 温控段循环索引。
    bAllReady: BOOL := FALSE;              // TRUE=最近一次 100ms 温控计算后，全部有效段都已达到设定温度。
    bZoneHeat: BOOL := FALSE;              // 当前段在本轮 100ms 计算中是否允许输出加热命令。
END_VAR

(* 复位时清空温控状态与输出，恢复到安全初值。 *)
IF bReset THEN
    eState := eState_Idle;                     // 复位时强制回到空闲态。
    bBusy := FALSE;                            // 复位时立即清除执行态。
    bDone := FALSE;                            // 复位时立即清除完成态。
    bAlarm := FALSE;                           // 复位时立即清除报警态。
    dwAlarmID := 0;                            // 复位时清空报警码。
    uiHeatState := 0;                          // 复位时把热状态恢复为停止。
    uiVersion := 2;                            // 复位时回写当前模块版本号。
    bAllReady := FALSE;                        // 复位时清空“全部就绪”缓存，避免旧结果带入下次启动。
    FOR uiCycle := 1 TO 12 DO
        stOutPara.aSeg[uiCycle].uiActualTemp := 25; // 复位时把每段模拟温度恢复到默认环境温度。
        stOutPara.aSeg[uiCycle].uiState := 0;       // 复位时清空每段状态码。
    END_FOR;
    FOR uiCycle := 1 TO 100 DO
        stOutPara.aOutputAddr[uiCycle] := 0;   // 复位时关闭全部温控输出地址镜像。
    END_FOR;
ELSIF bStop THEN
    (* 正常停止时保留当前反馈值，但退出执行态并撤销加热输出。 *)
    eState := eState_Idle;                     // 停止时回到空闲态，等待后续重新启动。
    bBusy := FALSE;                            // 停止时立即清除执行态。
    bDone := FALSE;                            // 停止时立即清除完成态。
    uiHeatState := 0;                          // 停止时把热状态恢复为停止。
    bAllReady := FALSE;                        // 停止时清空“全部就绪”缓存，避免停止后仍显示已就绪。
    FOR uiCycle := 1 TO 12 DO
        stOutPara.aOutputAddr[uiCycle] := 0;   // 停止时撤销前 12 路加热输出。
    END_FOR;
ELSE
    CASE eState OF
        eState_Idle:
            bBusy := FALSE;                    // 空闲态明确声明当前未执行温控动作。
            bDone := FALSE;                    // 空闲态明确声明当前未完成升温。
            bAlarm := FALSE;                   // 空闲态默认不保留报警态。
            dwAlarmID := 0;                    // 空闲态清空报警码。
            uiHeatState := 0;                  // 空闲态显示为停止。
            bAllReady := FALSE;                // 空闲态清空“全部就绪”缓存，等待下次启动重新计算。
            FOR uiCycle := 1 TO 12 DO
                stOutPara.aOutputAddr[uiCycle] := 0; // 空闲态持续关闭所有加热输出。
            END_FOR;
            IF bStart THEN
                eState := eState_Init;         // 收到启动命令后转入初始化态，为进入升温态准备初值。
            END_IF;

        eState_Init:
            (* 初始化各段温度与状态，为进入升温阶段准备默认值。 *)
            bBusy := TRUE;                     // 初始化态属于温控执行过程的一部分，因此保持 Busy。
            bDone := FALSE;                    // 初始化期间不允许宣告升温完成。
            uiHeatState := 1;                  // 初始化后即将进入升温态，因此对外显示为升温中。
            uiVersion := 2;                    // 初始化时持续回写当前模块版本号。
            bAllReady := FALSE;                // 每次启动都清空“全部就绪”缓存，确保重新按照最新温度重新判定。
            bAlarm := FALSE;                   // 每次启动都先清空旧报警态，再进入本轮温控计算。
            dwAlarmID := 0;                    // 每次启动都先清空旧报警码，再进入本轮温控计算。
            FOR uiCycle := 1 TO 12 DO
                IF stOutPara.aSeg[uiCycle].uiActualTemp = 0 THEN
                    stOutPara.aSeg[uiCycle].uiActualTemp := 25; // 若段温尚未初始化，则补上默认环境温度。
                END_IF;
                stOutPara.aSeg[uiCycle].uiState := 1; // 初始化时把各段标记为升温中。
            END_FOR;
            eState := eState_Heating;          // 初始化完成后立即转入持续升温态。

        eState_Heating:
            (* 升温态每拍都保持 Busy，但只在顶层给出的 100ms 刷新拍上执行一轮温控计算。 *)
            bBusy := TRUE;                     // 升温态持续维持 Busy，表示温控系统仍在运行。
            IF bLogicTick100msIn THEN
                bAllReady := TRUE;             // 每次新一轮 100ms 计算先假定全部就绪，随后逐段校正。
                bAlarm := FALSE;               // 每次新一轮 100ms 计算先清空报警态，再重新汇总。
                dwAlarmID := 0;                // 每次新一轮 100ms 计算先清空报警码，再重新叠加。

                FOR uiCycle := 1 TO 12 DO
                    bZoneHeat := FALSE;        // 每段计算开始前先清空本段的加热允许位。

                    IF stInPara.aSeg[uiCycle].uiFunc = 1 THEN
                        IF bR0 OR bR1 OR bR2 OR bR3 THEN
                            CASE uiCycle OF
                                1, 2, 3: bZoneHeat := bR0; // 第 1~3 段跟随人工 R0 组命令。
                                4, 5, 6: bZoneHeat := bR1; // 第 4~6 段跟随人工 R1 组命令。
                                7, 8, 9: bZoneHeat := bR2; // 第 7~9 段跟随人工 R2 组命令。
                            ELSE
                                bZoneHeat := bR3;          // 第 10~12 段跟随人工 R3 组命令。
                            END_CASE;
                        ELSE
                            bZoneHeat := (stOutPara.aSeg[uiCycle].uiActualTemp < stInPara.aSeg[uiCycle].uiSetTemp); // 无人工组命令时，按设定温度自动决定是否继续加热。
                        END_IF;

                        IF bZoneHeat THEN
                            stOutPara.aSeg[uiCycle].uiActualTemp := stOutPara.aSeg[uiCycle].uiActualTemp + 1; // 允许加热时，把当前段模拟温度按 100ms 拍递增 1。
                            stOutPara.aOutputAddr[uiCycle] := 1;                                                // 允许加热时，拉起对应段的输出地址镜像。
                        ELSE
                            IF stOutPara.aSeg[uiCycle].uiActualTemp > stInPara.aSeg[uiCycle].uiSetTemp THEN
                                stOutPara.aSeg[uiCycle].uiActualTemp := stOutPara.aSeg[uiCycle].uiActualTemp - 1; // 不加热且当前温度高于设定时，按 100ms 拍做自然回落。
                            END_IF;
                            stOutPara.aOutputAddr[uiCycle] := 0;                                                 // 不允许加热时，关闭对应段的输出地址镜像。
                        END_IF;

                        IF stOutPara.aSeg[uiCycle].uiActualTemp < stInPara.aSeg[uiCycle].uiMin THEN
                            stOutPara.aSeg[uiCycle].uiState := 1;       // 低于下限时，把段状态标记为欠温。
                            bAllReady := FALSE;                         // 只要存在欠温段，本轮整体就绪判定必须失败。
                            bAlarm := TRUE;                             // 欠温属于报警条件，拉起总报警态。
                            dwAlarmID := dwAlarmID OR DWORD#16#0002;    // 欠温时叠加对应报警位。
                        ELSIF stOutPara.aSeg[uiCycle].uiActualTemp > stInPara.aSeg[uiCycle].uiMax THEN
                            stOutPara.aSeg[uiCycle].uiState := 2;       // 高于上限时，把段状态标记为超温。
                            bAlarm := TRUE;                             // 超温属于报警条件，拉起总报警态。
                            dwAlarmID := dwAlarmID OR DWORD#16#0001;    // 超温时叠加对应报警位。
                        ELSE
                            stOutPara.aSeg[uiCycle].uiState := 0;       // 温度位于允许范围内时，清空本段报警状态。
                            IF stOutPara.aSeg[uiCycle].uiActualTemp < stInPara.aSeg[uiCycle].uiSetTemp THEN
                                bAllReady := FALSE;                     // 即便未越界，只要还没达到设定温度，也不能判定整体就绪。
                            END_IF;
                        END_IF;
                    ELSE
                        stOutPara.aSeg[uiCycle].uiState := 0;           // 未启用段不参与报警判断，状态保持为正常。
                        stOutPara.aOutputAddr[uiCycle] := 0;            // 未启用段强制关闭输出地址镜像。
                    END_IF;
                END_FOR;
            END_IF;

            IF bAllReady THEN
                bDone := TRUE;                     // 最近一次计算确认全部有效段已就绪时，对外拉起 Done。
                uiHeatState := 2;                 // 最近一次计算确认全部有效段已就绪时，对外显示为已就绪。
            ELSE
                bDone := FALSE;                    // 只要最近一次计算仍有段未就绪，就保持 Done 为 FALSE。
                uiHeatState := 1;                  // 只要最近一次计算仍有段未就绪，就保持热状态为升温中。
            END_IF;

            IF dwAlarmID = DWORD#16#0001 THEN
                eState := eState_Error;           // 一旦检测到超温报警，立即切入故障态等待外部复位。
            END_IF;

        eState_Error:
            (* 故障态下切断全部加热输出，等待外部复位。 *)
            bBusy := FALSE;                       // 故障态停止继续执行升温动作。
            bAlarm := TRUE;                       // 故障态持续保持报警标志。
            bDone := FALSE;                       // 故障态明确撤销就绪完成标志。
            uiHeatState := 0;                     // 故障态对外显示为停止，由报警位单独提示异常。
            bAllReady := FALSE;                   // 故障态清空“全部就绪”缓存，避免错误显示温控已就绪。
            FOR uiCycle := 1 TO 12 DO
                stOutPara.aOutputAddr[uiCycle] := 0; // 故障态切断前 12 路加热输出。
            END_FOR;

    ELSE
        eState := eState_Error;                   // 未知状态统一转入故障态，避免状态机失控。
    END_CASE;
END_IF;
END_FUNCTION_BLOCK
