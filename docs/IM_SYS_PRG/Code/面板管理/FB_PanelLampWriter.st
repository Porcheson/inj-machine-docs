(*
  FB_PanelLampWriter 功能块
  功能：
  1. 按统一的面板排序号，把单个逻辑键的灯请求写入 `wOUT0/wOUT1`。
  2. 约定排序号 `1..16` 对应 `wOUT0` 的 `0..15` 位，排序号 `17..32` 对应 `wOUT1` 的 `0..15` 位。
  3. 供 `FB_MK110`、`FB_MK116`、`FB_MK150` 复用，避免每个面板块重复展开灯位写入分支。

  使用约束：
  1. 调用方必须在本扫描周期开始前先把 `wOUT0`、`wOUT1` 清零。
  2. 本块只负责把单个逻辑键的灯请求并入输出字，不负责排序号唯一性检查。
*)
FUNCTION_BLOCK FB_PanelLampWriter
VAR_IN_OUT
    wOUT0: WORD;              // 输出字 0；承载排序号 `1..16` 对应的面板灯位。
    wOUT1: WORD;              // 输出字 1；承载排序号 `17..32` 对应的面板灯位。
END_VAR
VAR_INPUT
    uiPanelOrder: UINT;       // 当前逻辑键在当前面板型号中的排序号；`0` 表示本次不写任何灯位。
    bLampValue: BOOL;         // 当前逻辑键的灯请求；TRUE=点亮对应灯位，FALSE=保持输出字当前值不变。
END_VAR

IF NOT bLampValue THEN
    (* 当前逻辑键灯请求为 FALSE 时不做任何写入。
       调用方已在扫描周期开始时统一清零输出字，因此这里不需要再重复清位。
    *)
ELSIF (uiPanelOrder >= 1) AND (uiPanelOrder <= 16) THEN
    wOUT0 := F_PanelSetBit(wValue := wOUT0, uiBitIndex := uiPanelOrder - 1, bBitValue := TRUE);      // 排序号落在 `1..16` 时，把灯写入 `wOUT0` 的对应位。
ELSIF (uiPanelOrder >= 17) AND (uiPanelOrder <= 32) THEN
    wOUT1 := F_PanelSetBit(wValue := wOUT1, uiBitIndex := uiPanelOrder - 17, bBitValue := TRUE);     // 排序号落在 `17..32` 时，把灯写入 `wOUT1` 的对应位。
END_IF;
END_FUNCTION_BLOCK
