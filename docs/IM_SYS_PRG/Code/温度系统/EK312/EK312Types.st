(*
  EK312Types.st
  功能：
  1. 定义 EK312 温控模块使用的输入参数、输出参数和状态枚举。
  2. 统一 12 路温控段的设定值、反馈值与 I/O 地址边界。

  维护要求：
  1. 数组长度变更后，必须同步检查 `FB_EK312` 中的循环上限。
  2. 现场若接入真实温控器，应优先复用本文件结构，避免再次拆散接口。
*)

TYPE E_EK312State :
(
    eState_Idle,     // 空闲：等待启动
    eState_Init,     // 初始化：装载初值并进入升温阶段
    eState_Heating,  // 升温：按设定温度驱动各段
    eState_Error     // 故障：出现超温等异常
);
END_TYPE

TYPE ST_EK312InSeg :
STRUCT
    uiSetTemp: UINT;  // 目标温度
    uiFunc: UINT;     // 段功能选择，1 表示启用该段
    uiP: UINT;        // PID 比例参数
    uiD: UINT;        // PID 微分参数
    uiMax: UINT;      // 允许最高温度
    uiMin: UINT;      // 允许最低温度
END_STRUCT
END_TYPE

TYPE ST_EK312InPara :
STRUCT
    aSeg: ARRAY[1..12] OF ST_EK312InSeg;  // 12 路温控段设定
    aInputAddr: ARRAY[1..50] OF UINT;     // 输入地址映射
    uiStationNo: UINT;                    // 站号
    uiColorSelect: UINT;                  // 配色方案选择
    uiAColor: UINT;                       // A 组颜色参数
    uiBColor: UINT;                       // B 组颜色参数
    uiCColor: UINT;                       // C 组颜色参数
    uiANozMode: UINT;                     // A 组喷嘴控制模式
    uiBNozMode: UINT;                     // B 组喷嘴控制模式
    uiCNozMode: UINT;                     // C 组喷嘴控制模式
    uiANozPerc: UINT;                     // A 组喷嘴功率百分比
    uiBNozPerc: UINT;                     // B 组喷嘴功率百分比
    uiCNozPerc: UINT;                     // C 组喷嘴功率百分比
    uiContSSR: UINT;                      // 连续 SSR 控制参数
    uiNozCtrlCycle: UINT;                 // 喷嘴控制周期
END_STRUCT
END_TYPE

TYPE ST_EK312OutSeg :
STRUCT
    uiActualTemp: UINT;  // 实际温度
    uiState: UINT;       // 段状态码
END_STRUCT
END_TYPE

TYPE ST_EK312OutPara :
STRUCT
    aSeg: ARRAY[1..12] OF ST_EK312OutSeg;   // 12 路段状态输出
    aOutputAddr: ARRAY[1..100] OF UINT;     // 输出地址映射
END_STRUCT
END_TYPE
