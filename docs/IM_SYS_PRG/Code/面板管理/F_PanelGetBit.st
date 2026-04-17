(*
  F_PanelGetBit 函数
  功能：
  1. 从一个 `WORD` 中按位索引读取单个布尔值。
  2. 供面板输入解码函数按“字 + 位”的方式统一读取按键输入。
  3. 越界位索引会直接返回 `FALSE`，避免上层再额外做边界保护。
*)
FUNCTION F_PanelGetBit : BOOL
VAR_INPUT
    wValue: WORD;          // 待读取的源字；通常来自面板输入字 `wIN0~wIN3`。
    uiBitIndex: UINT;      // 目标位索引；有效范围为 `0..15`。
END_VAR

IF uiBitIndex > 15 THEN
    F_PanelGetBit := FALSE;                                                        // 位索引越界时直接返回 FALSE，避免把非法位误判为有效输入。
ELSE
    F_PanelGetBit := ((SHR(wValue, uiBitIndex) AND WORD#1) = WORD#1);              // 位索引有效时，把目标位右移到最低位后判断其是否为 1。
END_IF;
END_FUNCTION
