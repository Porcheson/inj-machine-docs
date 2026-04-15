(* 
  FB_HydAxis 功能块
  功能：
  1. 对模块层写入的 `ST_AxisRefHyd` 进行最终轴实例化。
  2. 在统一位置补齐轴号、能力上限、命令限幅和轴层报警诊断。
  3. 输出标准化的轴状态结构，便于主控层把轴层结果并入机器总状态。

  设计原则：
  1. 本块不负责工艺状态机，也不替代 `FB_Clamp`、`FB_Inject` 等模块的动作逻辑。
  2. 本块只做最终一层轴抽象：接管共享轴结构，整理出可下发的最终命令。
  3. 当模块层误下发越界命令时，本块会做保护性限幅，并把报警叠加回轴故障码。
*)
FUNCTION_BLOCK FB_HydAxis
VAR_IN_OUT
    stAxisRef: ST_AxisRefHyd;      // 共享轴引用；模块层写目标值，轴层做最终整理
END_VAR
VAR_INPUT
    
    (* 控制命令 *)		
	bStart: BOOL;		// 启动	
	bStop: BOOL;		// 停止(有减速停)		
	bEStop: BOOL;		// 急停(立即停止，无减速停)	
	bReset: BOOL;		// 复位	
	bDir: BOOL;			// 方向

    (* 模式选择 *)	
	uiMode: UINT;		// 0:无模式 1:位置模式 2:速度模式 3:扭矩模式

    (* 参数设定 *)	
	uiCmdPres  : UINT; 	// 压力目标
    uiSpd      : UINT; 	// 速度目标
    udiPos     : UDINT; // 位置目标
    uiForce    : UINT; 	// 力目标，可选(锁模,射胶时使用）
	
    uiAcc	: UINT;     // 加速度 
    uiDec	: UINT;     // 减速度 
	uiJerk	: UINT;     // 加加速


    bEnable: BOOL;                 // TRUE=当前主控允许该轴工作
    bReset: BOOL;                  // TRUE=清空轴层状态与命令
    nAxisID: INT;                  // 统一轴号，供主控/HMI/下位 I/O 对齐
    rMaxCylinderStroke: LREAL;     // 轴允许的最大行程上限
    rMaxVelocity: LREAL;           // 轴允许的最大速度上限
    rMaxPressure: LREAL;           // 轴允许的最大压力上限
    rPosTolerance: LREAL;          // 位置到位容差
    rVelTolerance: LREAL;          // 速度到位容差
    rPresTolerance: LREAL;         // 压力到位容差
END_VAR
VAR_OUTPUT
    	
	(* 状态输出 *)	
	bBusy: BOOL;		// 忙状态		
	bDone: BOOL;		// 完成状态
	bAlarm: BOOL;		// 报警状态
	
    (* 报警信息 *)		
	dwAlarmID: DWORD;		// 报警代码							
							(*	0:无 							
							*)	
	
    
    stStatus: ST_HydAxisStatus;    // 轴层最终状态与限幅后的命令输出
END_VAR
VAR
    tPulse: TON;
    udiElapsedMs: UDINT := 0;
    dwAxisFault: DWORD := DWORD#0;
    rSafePosition: LREAL := 0.0;
    rSafeVelocity: LREAL := 0.0;
    rSafePressure: LREAL := 0.0;
END_VAR

(* 每个扫描周期都先把静态轴属性回写到共享轴结构中。
   这样模块层、主控层和未来的 I/O 层都能读取到一致的轴定义。
*)
stAxisRef.bActive := bEnable;
stAxisRef.nAxisID := nAxisID;
stAxisRef.rMaxCylinderStroke := rMaxCylinderStroke;
stAxisRef.rMaxVelocity := rMaxVelocity;
stAxisRef.rMaxPressure := rMaxPressure;

IF bReset THEN
    (* 复位时清空轴层命令、报警和计时，但保留由主控回写的实际反馈。 *)
    stAxisRef.rSetPosition := 0.0;
    stAxisRef.rSetVelocity := 0.0;
    stAxisRef.rSetPressure := 0.0;
    stAxisRef.stPumpRequest.bRequest := FALSE;
    stAxisRef.stPumpRequest.rFlowSet := 0.0;
    stAxisRef.stPumpRequest.rPressureSet := 0.0;
    stAxisRef.eAxisState := Idle;
    stAxisRef.nFaultCode := 0;

    stStatus.bEnabled := FALSE;
    stStatus.bReady := FALSE;
    stStatus.bCommandActive := FALSE;
    stStatus.bInPosition := FALSE;
    stStatus.bInVelocity := FALSE;
    stStatus.bInPressure := FALSE;
    stStatus.bAlarm := FALSE;
    stStatus.dwAlarmID := DWORD#0;
    stStatus.uiActTime := 0;
    stStatus.rCmdPosition := 0.0;
    stStatus.rCmdVelocity := 0.0;
    stStatus.rCmdPressure := 0.0;

    udiElapsedMs := 0;
    tPulse(IN := FALSE, PT := T#100MS);
ELSE
    (* 先继承模块层已经写入的报警位，再叠加轴层自己的保护报警。 *)
    dwAxisFault := TO_DWORD(TO_UINT(stAxisRef.nFaultCode));

    rSafePosition := stAxisRef.rSetPosition;
    rSafeVelocity := stAxisRef.rSetVelocity;
    rSafePressure := stAxisRef.rSetPressure;

    (* 对目标命令做基础限幅，避免模块层把越界值直接透传到最终轴命令。 *)
    IF rSafePosition < 0.0 THEN
        rSafePosition := 0.0;
        dwAxisFault := dwAxisFault OR DWORD#16#0002;
    ELSIF (rMaxCylinderStroke > 0.0) AND (rSafePosition > rMaxCylinderStroke) THEN
        rSafePosition := rMaxCylinderStroke;
        dwAxisFault := dwAxisFault OR DWORD#16#0002;
    END_IF;

    IF rSafeVelocity < 0.0 THEN
        rSafeVelocity := 0.0;
        dwAxisFault := dwAxisFault OR DWORD#16#0004;
    ELSIF (rMaxVelocity > 0.0) AND (rSafeVelocity > rMaxVelocity) THEN
        rSafeVelocity := rMaxVelocity;
        dwAxisFault := dwAxisFault OR DWORD#16#0004;
    END_IF;

    IF rSafePressure < 0.0 THEN
        rSafePressure := 0.0;
        dwAxisFault := dwAxisFault OR DWORD#16#0008;
    ELSIF (rMaxPressure > 0.0) AND (rSafePressure > rMaxPressure) THEN
        rSafePressure := rMaxPressure;
        dwAxisFault := dwAxisFault OR DWORD#16#0008;
    END_IF;

    IF NOT bEnable THEN
        (* 当主控不允许该轴工作时，任何残留命令都要被压掉，并记为轴层报警。 *)
        IF stAxisRef.stPumpRequest.bRequest OR (rSafePosition > 0.0) OR (rSafeVelocity > 0.0) OR (rSafePressure > 0.0) THEN
            dwAxisFault := dwAxisFault OR DWORD#16#0001;
        END_IF;

        stAxisRef.rSetPosition := 0.0;
        stAxisRef.rSetVelocity := 0.0;
        stAxisRef.rSetPressure := 0.0;
        stAxisRef.stPumpRequest.bRequest := FALSE;
        stAxisRef.stPumpRequest.rFlowSet := 0.0;
        stAxisRef.stPumpRequest.rPressureSet := 0.0;
        stAxisRef.eAxisState := Stop;

        udiElapsedMs := 0;
        tPulse(IN := FALSE, PT := T#100MS);

        stStatus.bCommandActive := FALSE;
    ELSE
        (* 主控允许该轴工作时，把限幅后的目标值回写成最终命令。 *)
        stAxisRef.rSetPosition := rSafePosition;
        stAxisRef.rSetVelocity := rSafeVelocity;
        stAxisRef.rSetPressure := rSafePressure;
        stAxisRef.stPumpRequest.rFlowSet := rSafeVelocity;
        stAxisRef.stPumpRequest.rPressureSet := rSafePressure;

        stStatus.bCommandActive := stAxisRef.stPumpRequest.bRequest;

        IF stStatus.bCommandActive THEN
            tPulse(IN := TRUE, PT := T#100MS);
            IF tPulse.Q THEN
                udiElapsedMs := udiElapsedMs + 100;
                tPulse(IN := FALSE, PT := T#100MS);
            END_IF;
            stAxisRef.eAxisState := Running;
        ELSE
            udiElapsedMs := 0;
            tPulse(IN := FALSE, PT := T#100MS);
            stAxisRef.eAxisState := Idle;
        END_IF;
    END_IF;

    stStatus.bEnabled := bEnable;
    stStatus.bAlarm := (dwAxisFault <> DWORD#0);
    stStatus.bReady := bEnable AND (NOT stStatus.bAlarm);
    stStatus.dwAlarmID := dwAxisFault;
    stStatus.uiActTime := TO_UINT(udiElapsedMs / 1000);

    stStatus.rCmdPosition := stAxisRef.rSetPosition;
    stStatus.rCmdVelocity := stAxisRef.rSetVelocity;
    stStatus.rCmdPressure := stAxisRef.rSetPressure;

    stStatus.bInPosition := ABS(stAxisRef.rActualPosition - stStatus.rCmdPosition) <= rPosTolerance;
    stStatus.bInVelocity := ABS(stAxisRef.rActualVelocity - stStatus.rCmdVelocity) <= rVelTolerance;
    stStatus.bInPressure := ABS(stAxisRef.rActualPressure - stStatus.rCmdPressure) <= rPresTolerance;

    (* 统一把轴层最终报警码回写到共享轴故障码，便于上层直接读取。 *)
    stAxisRef.nFaultCode := TO_INT(stStatus.dwAlarmID);
END_IF;
END_FUNCTION_BLOCK
