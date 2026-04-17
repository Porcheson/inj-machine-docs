(*
  FB_MK116 功能块
  功能：
  1. 完成 MK116 面板的按键输入解码和灯输出编码。
  2. 使用统一的 `ST_PanelButtons` 结构收口全部逻辑键，保证键值与灯值共享同一排序号。
  3. 当 MK116 面板键位顺序调整时，只需要修改本块开头的排序号定义，不需要再分别改键值和灯值绑定。
*)
FUNCTION_BLOCK FB_MK116
VAR_IN_OUT
    stPanelButtons: ST_PanelButtons;     // MK116 面板综合按键结构；本块负责写入排序号和键值，并消费其中的灯值。
END_VAR
VAR_INPUT
    wIN0: WORD;                          // MK116 面板输入字 0；承载一部分动作键输入。
    wIN1: WORD;                          // MK116 面板输入字 1；承载一部分动作键输入。
    wIN2: WORD;                          // MK116 面板输入字 2；承载模式类与工艺类按键输入。
    wIN3: WORD;                          // MK116 面板输入字 3；承载少量扩展键输入。
END_VAR
VAR_OUTPUT
    wOUT0: WORD;                         // MK116 面板输出字 0；承载排序号 `1..16` 对应的灯输出。
    wOUT1: WORD;                         // MK116 面板输出字 1；承载排序号 `17..32` 对应的灯输出。
END_VAR
VAR
    fbLampWriter: FB_PanelLampWriter;    // 通用面板灯写入器；负责把单个逻辑键的灯请求并入 `wOUT0/wOUT1`。
END_VAR

(* 先写入 MK116 固定面板排序号。 *)
stPanelButtons.stManual.uiPanelOrder := 1;             // MK116 把手动键定义为排序号 1。
stPanelButtons.stMoldOpen.uiPanelOrder := 2;           // MK116 把开模键定义为排序号 2。
stPanelButtons.stMoldClose.uiPanelOrder := 3;          // MK116 把锁模键定义为排序号 3。
stPanelButtons.stMaterialMelt.uiPanelOrder := 4;       // MK116 把储料键定义为排序号 4。
stPanelButtons.stCleanMaterial.uiPanelOrder := 5;      // MK116 把清料键定义为排序号 5。
stPanelButtons.stJetLube.uiPanelOrder := 6;            // MK116 把润滑键定义为排序号 6。
stPanelButtons.stSemiautomatic.uiPanelOrder := 7;      // MK116 把半自动键定义为排序号 7。
stPanelButtons.stEjectorFwd.uiPanelOrder := 8;         // MK116 把托模进键定义为排序号 8。
stPanelButtons.stEjectorBwd.uiPanelOrder := 9;         // MK116 把托模退键定义为排序号 9。
stPanelButtons.stInjFwd.uiPanelOrder := 10;            // MK116 把射出键定义为排序号 10。
stPanelButtons.stInjBwd.uiPanelOrder := 11;            // MK116 把射退键定义为排序号 11。
stPanelButtons.stLockFwd.uiPanelOrder := 12;           // MK116 把定位进键定义为排序号 12。
stPanelButtons.stLockBwd.uiPanelOrder := 13;           // MK116 把定位退键定义为排序号 13。
stPanelButtons.stAutomatic.uiPanelOrder := 14;         // MK116 把全自动键定义为排序号 14。
stPanelButtons.stMultiEjector.uiPanelOrder := 15;      // MK116 把多次托模键定义为排序号 15。
stPanelButtons.stBlow.uiPanelOrder := 16;              // MK116 把吹气键定义为排序号 16。
stPanelButtons.stInjUnitFwd.uiPanelOrder := 17;        // MK116 把座进键定义为排序号 17。
stPanelButtons.stInjUnitBwd.uiPanelOrder := 18;        // MK116 把座退键定义为排序号 18。
stPanelButtons.stZipperBwd.uiPanelOrder := 19;         // MK116 把倒带键定义为排序号 19。
stPanelButtons.stZipperFwd.uiPanelOrder := 20;         // MK116 把拉带键定义为排序号 20。
stPanelButtons.stAdjustMold.uiPanelOrder := 21;        // MK116 把调模键定义为排序号 21。
stPanelButtons.stCoreFwdA.uiPanelOrder := 22;          // MK116 把中子 A 进键定义为排序号 22。
stPanelButtons.stCoreBwdA.uiPanelOrder := 23;          // MK116 把中子 A 退键定义为排序号 23。
stPanelButtons.stMotor.uiPanelOrder := 24;             // MK116 把马达键定义为排序号 24。
stPanelButtons.stHeat.uiPanelOrder := 25;              // MK116 把电热键定义为排序号 25。
stPanelButtons.stZipperClamp.uiPanelOrder := 26;       // MK116 把夹带键定义为排序号 26。
stPanelButtons.stZipperMotor.uiPanelOrder := 27;       // MK116 把拉带马达键定义为排序号 27。
stPanelButtons.stPressRise.uiPanelOrder := 0;          // MK116 不提供压力加键，因此排序号固定为 0。
stPanelButtons.stPressFall.uiPanelOrder := 0;          // MK116 不提供压力减键，因此排序号固定为 0。

(* 再按排序号统一解码当前键值。 *)
stPanelButtons.stManual.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stManual.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                      // 读取手动键当前值。
stPanelButtons.stMoldOpen.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stMoldOpen.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                  // 读取开模键当前值。
stPanelButtons.stMoldClose.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stMoldClose.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                // 读取锁模键当前值。
stPanelButtons.stMaterialMelt.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stMaterialMelt.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);          // 读取储料键当前值。
stPanelButtons.stCleanMaterial.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stCleanMaterial.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);        // 读取清料键当前值。
stPanelButtons.stJetLube.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stJetLube.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                     // 读取润滑键当前值。
stPanelButtons.stSemiautomatic.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stSemiautomatic.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);       // 读取半自动键当前值。
stPanelButtons.stEjectorFwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stEjectorFwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                // 读取托模进键当前值。
stPanelButtons.stEjectorBwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stEjectorBwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                // 读取托模退键当前值。
stPanelButtons.stInjFwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stInjFwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                        // 读取射出键当前值。
stPanelButtons.stInjBwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stInjBwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                        // 读取射退键当前值。
stPanelButtons.stLockFwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stLockFwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                      // 读取定位进键当前值。
stPanelButtons.stLockBwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stLockBwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                      // 读取定位退键当前值。
stPanelButtons.stAutomatic.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stAutomatic.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                  // 读取全自动键当前值。
stPanelButtons.stMultiEjector.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stMultiEjector.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);            // 读取多次托模键当前值。
stPanelButtons.stBlow.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stBlow.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                           // 读取吹气键当前值。
stPanelButtons.stInjUnitFwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stInjUnitFwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                // 读取座进键当前值。
stPanelButtons.stInjUnitBwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stInjUnitBwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                // 读取座退键当前值。
stPanelButtons.stZipperBwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stZipperBwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                  // 读取倒带键当前值。
stPanelButtons.stZipperFwd.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stZipperFwd.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                  // 读取拉带键当前值。
stPanelButtons.stAdjustMold.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stAdjustMold.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                // 读取调模键当前值。
stPanelButtons.stCoreFwdA.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stCoreFwdA.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                    // 读取中子 A 进键当前值。
stPanelButtons.stCoreBwdA.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stCoreBwdA.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                    // 读取中子 A 退键当前值。
stPanelButtons.stMotor.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stMotor.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                         // 读取马达键当前值。
stPanelButtons.stHeat.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stHeat.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                            // 读取电热键当前值。
stPanelButtons.stZipperClamp.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stZipperClamp.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);              // 读取夹带键当前值。
stPanelButtons.stZipperMotor.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stZipperMotor.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);              // 读取拉带马达键当前值。
stPanelButtons.stPressRise.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stPressRise.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                  // 读取压力加键当前值；当前排序号为 0 时会自然回读 FALSE。
stPanelButtons.stPressFall.bValue := F_MK116ReadKeyByOrder(uiPanelOrder := stPanelButtons.stPressFall.uiPanelOrder, wIN0 := wIN0, wIN1 := wIN1, wIN2 := wIN2, wIN3 := wIN3);                  // 读取压力减键当前值；当前排序号为 0 时会自然回读 FALSE。

(* 最后按同一排序号统一生成灯输出。 *)
wOUT0 := WORD#0;                                                         // 本扫描周期开始时先清零输出字 0，准备重新汇总灯输出。
wOUT1 := WORD#0;                                                         // 本扫描周期开始时先清零输出字 1，准备重新汇总灯输出。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stManual.uiPanelOrder, bLampValue := stPanelButtons.stManual.bLamp);                        // 并入手动键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stMoldOpen.uiPanelOrder, bLampValue := stPanelButtons.stMoldOpen.bLamp);                  // 并入开模键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stMoldClose.uiPanelOrder, bLampValue := stPanelButtons.stMoldClose.bLamp);                // 并入锁模键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stMaterialMelt.uiPanelOrder, bLampValue := stPanelButtons.stMaterialMelt.bLamp);          // 并入储料键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stCleanMaterial.uiPanelOrder, bLampValue := stPanelButtons.stCleanMaterial.bLamp);        // 并入清料键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stJetLube.uiPanelOrder, bLampValue := stPanelButtons.stJetLube.bLamp);                    // 并入润滑键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stSemiautomatic.uiPanelOrder, bLampValue := stPanelButtons.stSemiautomatic.bLamp);        // 并入半自动键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stEjectorFwd.uiPanelOrder, bLampValue := stPanelButtons.stEjectorFwd.bLamp);              // 并入托模进键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stEjectorBwd.uiPanelOrder, bLampValue := stPanelButtons.stEjectorBwd.bLamp);              // 并入托模退键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stInjFwd.uiPanelOrder, bLampValue := stPanelButtons.stInjFwd.bLamp);                       // 并入射出键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stInjBwd.uiPanelOrder, bLampValue := stPanelButtons.stInjBwd.bLamp);                       // 并入射退键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stLockFwd.uiPanelOrder, bLampValue := stPanelButtons.stLockFwd.bLamp);                     // 并入定位进键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stLockBwd.uiPanelOrder, bLampValue := stPanelButtons.stLockBwd.bLamp);                     // 并入定位退键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stAutomatic.uiPanelOrder, bLampValue := stPanelButtons.stAutomatic.bLamp);                 // 并入全自动键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stMultiEjector.uiPanelOrder, bLampValue := stPanelButtons.stMultiEjector.bLamp);          // 并入多次托模键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stBlow.uiPanelOrder, bLampValue := stPanelButtons.stBlow.bLamp);                           // 并入吹气键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stInjUnitFwd.uiPanelOrder, bLampValue := stPanelButtons.stInjUnitFwd.bLamp);              // 并入座进键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stInjUnitBwd.uiPanelOrder, bLampValue := stPanelButtons.stInjUnitBwd.bLamp);              // 并入座退键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stZipperBwd.uiPanelOrder, bLampValue := stPanelButtons.stZipperBwd.bLamp);                // 并入倒带键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stZipperFwd.uiPanelOrder, bLampValue := stPanelButtons.stZipperFwd.bLamp);                // 并入拉带键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stPressRise.uiPanelOrder, bLampValue := stPanelButtons.stPressRise.bLamp);                // 并入压力加键灯请求；当前排序号为 0 时不会写任何灯位。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stPressFall.uiPanelOrder, bLampValue := stPanelButtons.stPressFall.bLamp);                // 并入压力减键灯请求；当前排序号为 0 时不会写任何灯位。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stAdjustMold.uiPanelOrder, bLampValue := stPanelButtons.stAdjustMold.bLamp);              // 并入调模键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stCoreFwdA.uiPanelOrder, bLampValue := stPanelButtons.stCoreFwdA.bLamp);                  // 并入中子 A 进键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stCoreBwdA.uiPanelOrder, bLampValue := stPanelButtons.stCoreBwdA.bLamp);                  // 并入中子 A 退键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stMotor.uiPanelOrder, bLampValue := stPanelButtons.stMotor.bLamp);                         // 并入马达键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stHeat.uiPanelOrder, bLampValue := stPanelButtons.stHeat.bLamp);                           // 并入电热键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stZipperClamp.uiPanelOrder, bLampValue := stPanelButtons.stZipperClamp.bLamp);            // 并入夹带键灯请求。
fbLampWriter(wOUT0 := wOUT0, wOUT1 := wOUT1, uiPanelOrder := stPanelButtons.stZipperMotor.uiPanelOrder, bLampValue := stPanelButtons.stZipperMotor.bLamp);            // 并入拉带马达键灯请求。
END_FUNCTION_BLOCK
