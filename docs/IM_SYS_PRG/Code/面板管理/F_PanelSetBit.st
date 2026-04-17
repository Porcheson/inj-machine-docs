(*
  F_PanelSetBit 函数
  功能：
  1. 按位索引对一个 `WORD` 做置位或清位操作。
  2. 供面板灯输出逻辑按“排序号 -> 输出位”的方式统一生成输出字。
  3. 越界位索引会直接返回原字，避免上层输出字被非法写坏。
*)
FUNCTION F_PanelSetBit : WORD
VAR_INPUT
    wValue: WORD;          // 待修改的目标字；通常来自面板输出字 `wOUT0` 或 `wOUT1`。
    uiBitIndex: UINT;      // 目标位索引；有效范围为 `0..15`。
    bBitValue: BOOL;       // TRUE=把目标位置 1；FALSE=把目标位清 0。
END_VAR

IF uiBitIndex > 15 THEN
    F_PanelSetBit := wValue;                                                      // 位索引越界时保持原字不变，避免误改无关输出位。
ELSIF bBitValue THEN
    F_PanelSetBit := wValue OR SHL(WORD#1, uiBitIndex);                           // 需要点亮时，用位掩码把目标位置 1。
ELSE
    F_PanelSetBit := wValue AND NOT SHL(WORD#1, uiBitIndex);                      // 需要熄灭时，用位掩码把目标位清 0。
END_IF;
END_FUNCTION
