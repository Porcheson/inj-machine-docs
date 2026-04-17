(*
  PanelTypes.st
  功能：
  1. 定义面板管理层统一使用的按键点位结构和综合按键结构。
  2. 统一收口“面板排序号 + 按键值 + 按键灯”三类信息，避免键值与灯值分散绑定。
  3. 为 `FB_MK110`、`FB_MK116`、`FB_MK150` 提供稳定的数据边界。

  说明：
  1. `uiPanelOrder` 由具体面板功能块按各自型号写入，`0` 表示当前面板未安装该逻辑键位。
  2. `bValue` 由面板输入解码逻辑回写，表示当前逻辑键是否被按下。
  3. `bLamp` 由上层控制逻辑写入，表示当前逻辑键对应的灯是否需要点亮。
*)

TYPE ST_PanelButton :
STRUCT
    uiPanelOrder: UINT;     // 当前逻辑键在当前面板型号中的排序号；`0` 表示该面板型号不提供此键位。
    bValue: BOOL;           // 当前逻辑键输入值；由面板功能块根据输入字和排序号解码后回写。
    bLamp: BOOL;            // 当前逻辑键灯输出请求；由上层写入，再由面板功能块按排序号编码到输出字。
END_STRUCT
END_TYPE

TYPE ST_PanelButtons :
STRUCT
    stManual: ST_PanelButton;            // 手动键综合点位，统一收口其排序号、键值和灯值。
    stSemiautomatic: ST_PanelButton;     // 半自动键综合点位，统一收口其排序号、键值和灯值。
    stAutomatic: ST_PanelButton;         // 全自动键综合点位，统一收口其排序号、键值和灯值。
    stAdjustMold: ST_PanelButton;        // 调模键综合点位，统一收口其排序号、键值和灯值。
    stHeat: ST_PanelButton;              // 电热键综合点位，统一收口其排序号、键值和灯值。
    stMotor: ST_PanelButton;             // 马达键综合点位，统一收口其排序号、键值和灯值。
    stMoldOpen: ST_PanelButton;          // 开模键综合点位，统一收口其排序号、键值和灯值。
    stMoldClose: ST_PanelButton;         // 锁模键综合点位，统一收口其排序号、键值和灯值。
    stMaterialMelt: ST_PanelButton;      // 储料键综合点位，统一收口其排序号、键值和灯值。
    stCleanMaterial: ST_PanelButton;     // 清料键综合点位，统一收口其排序号、键值和灯值。
    stJetLube: ST_PanelButton;           // 润滑键综合点位，统一收口其排序号、键值和灯值。
    stInjFwd: ST_PanelButton;            // 射出键综合点位，统一收口其排序号、键值和灯值。
    stInjBwd: ST_PanelButton;            // 射退键综合点位，统一收口其排序号、键值和灯值。
    stZipperBwd: ST_PanelButton;         // 倒带键综合点位，统一收口其排序号、键值和灯值。
    stZipperFwd: ST_PanelButton;         // 拉带键综合点位，统一收口其排序号、键值和灯值。
    stPressRise: ST_PanelButton;         // 压力加键综合点位，统一收口其排序号、键值和灯值。
    stPressFall: ST_PanelButton;         // 压力减键综合点位，统一收口其排序号、键值和灯值。
    stEjectorFwd: ST_PanelButton;        // 托模进键综合点位，统一收口其排序号、键值和灯值。
    stEjectorBwd: ST_PanelButton;        // 托模退键综合点位，统一收口其排序号、键值和灯值。
    stMultiEjector: ST_PanelButton;      // 多次托模键综合点位，统一收口其排序号、键值和灯值。
    stBlow: ST_PanelButton;              // 吹气键综合点位，统一收口其排序号、键值和灯值。
    stZipperClamp: ST_PanelButton;       // 夹带键综合点位，统一收口其排序号、键值和灯值。
    stZipperMotor: ST_PanelButton;       // 拉带马达键综合点位，统一收口其排序号、键值和灯值。
    stInjUnitFwd: ST_PanelButton;        // 座进键综合点位，统一收口其排序号、键值和灯值。
    stInjUnitBwd: ST_PanelButton;        // 座退键综合点位，统一收口其排序号、键值和灯值。
    stLockFwd: ST_PanelButton;           // 定位进键综合点位，统一收口其排序号、键值和灯值。
    stLockBwd: ST_PanelButton;           // 定位退键综合点位，统一收口其排序号、键值和灯值。
    stCoreFwdA: ST_PanelButton;          // 中子 A 进键综合点位，统一收口其排序号、键值和灯值。
    stCoreBwdA: ST_PanelButton;          // 中子 A 退键综合点位，统一收口其排序号、键值和灯值。
END_STRUCT
END_TYPE
