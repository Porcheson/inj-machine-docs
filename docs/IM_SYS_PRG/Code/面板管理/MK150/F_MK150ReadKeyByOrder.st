(*
  F_MK150ReadKeyByOrder 函数
  功能：
  1. 按 MK150 面板固定硬件接线，把面板排序号翻译为对应输入字中的实际按键值。
  2. 供 `FB_MK150` 统一按“排序号 -> 键值”的方式回写综合按键结构。
  3. 排序号 `0` 或未定义排序号统一返回 `FALSE`，表示当前无有效按键输入。
*)
FUNCTION F_MK150ReadKeyByOrder : BOOL
VAR_INPUT
    uiPanelOrder: UINT;       // MK150 面板排序号；由 `FB_MK150` 写入综合按键结构后再回传到本函数做解码。
    wIN0: WORD;               // MK150 面板输入字 0；承载一部分动作键输入。
    wIN1: WORD;               // MK150 面板输入字 1；承载一部分动作键输入。
    wIN2: WORD;               // MK150 面板输入字 2；承载模式类与工艺类按键输入。
    wIN3: WORD;               // MK150 面板输入字 3；当前型号未使用，但保留统一接口。
END_VAR

CASE uiPanelOrder OF
    1: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN2, uiBitIndex := 0);    // 排序号 1 对应手动键，硬件位为 `wIN2.0`。
    2: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN2, uiBitIndex := 1);    // 排序号 2 对应半自动键，硬件位为 `wIN2.1`。
    3: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN2, uiBitIndex := 2);    // 排序号 3 对应全自动键，硬件位为 `wIN2.2`。
    4: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN2, uiBitIndex := 3);    // 排序号 4 对应调模键，硬件位为 `wIN2.3`。
    5: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN2, uiBitIndex := 4);    // 排序号 5 对应电热键，硬件位为 `wIN2.4`。
    6: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN2, uiBitIndex := 5);    // 排序号 6 对应马达键，硬件位为 `wIN2.5`。
    7: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN0, uiBitIndex := 6);    // 排序号 7 对应开模键，硬件位为 `wIN0.6`。
    8: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN0, uiBitIndex := 7);    // 排序号 8 对应锁模键，硬件位为 `wIN0.7`。
    9: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN2, uiBitIndex := 8);    // 排序号 9 对应储料键，硬件位为 `wIN2.8`。
    10: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN2, uiBitIndex := 9);   // 排序号 10 对应清料键，硬件位为 `wIN2.9`。
    11: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN0, uiBitIndex := 10);  // 排序号 11 对应润滑键，硬件位为 `wIN0.10`。
    12: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN0, uiBitIndex := 11);  // 排序号 12 对应射出键，硬件位为 `wIN0.11`。
    13: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN0, uiBitIndex := 12);  // 排序号 13 对应射退键，硬件位为 `wIN0.12`。
    14: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN0, uiBitIndex := 13);  // 排序号 14 对应倒带键，硬件位为 `wIN0.13`。
    15: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN0, uiBitIndex := 14);  // 排序号 15 对应拉带键，硬件位为 `wIN0.14`。
    16: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN0, uiBitIndex := 15);  // 排序号 16 对应压力加键，硬件位为 `wIN0.15`。
    17: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 0);   // 排序号 17 对应压力减键，硬件位为 `wIN1.0`。
    18: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 1);   // 排序号 18 对应托模进键，硬件位为 `wIN1.1`。
    19: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 2);   // 排序号 19 对应托模退键，硬件位为 `wIN1.2`。
    20: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 3);   // 排序号 20 对应多次托模键，硬件位为 `wIN1.3`。
    21: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 4);   // 排序号 21 对应吹气键，硬件位为 `wIN1.4`。
    22: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 5);   // 排序号 22 对应夹带键，硬件位为 `wIN1.5`。
    23: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 6);   // 排序号 23 对应拉带马达键，硬件位为 `wIN1.6`。
    24: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 7);   // 排序号 24 对应座进键，硬件位为 `wIN1.7`。
    25: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 8);   // 排序号 25 对应座退键，硬件位为 `wIN1.8`。
    26: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 9);   // 排序号 26 对应定位进键，硬件位为 `wIN1.9`。
    27: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 10);  // 排序号 27 对应定位退键，硬件位为 `wIN1.10`。
    28: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 11);  // 排序号 28 对应中子 A 进键，硬件位为 `wIN1.11`。
    29: F_MK150ReadKeyByOrder := F_PanelGetBit(wValue := wIN1, uiBitIndex := 12);  // 排序号 29 对应中子 A 退键，硬件位为 `wIN1.12`。
ELSE
    F_MK150ReadKeyByOrder := FALSE;                                                    // 未定义排序号统一返回 FALSE，表示当前无有效输入。
END_CASE;
END_FUNCTION
