(*
  ClampTypes.st
  功能：
  1. 定义合模模块的状态枚举、分段参数和整套工艺参数结构。
  2. 为开模、合模、低压合模、高压锁模和调试动作提供统一参数边界。

  维护要求：
  1. 若开合模段数或中子联动字段变化，必须同步检查 `FB_Clamp` 的分段访问逻辑。
  2. 本文件只描述参数含义，不处理任何执行逻辑。
*)

TYPE E_ClampState :
(
    eState_Idle,           // 空闲
    eState_Init,           // 初始化
    eState_OpenUnload,     // 开模卸荷
    eState_Opening,        // 开模执行中
    eState_Opened,         // 开模完成
    eState_Closing,        // 合模执行中
    eState_Closed,         // 合模完成
    eState_CloseLowPress,  // 低压合模
    eState_CloseHighPress, // 高压锁模在
    eState_Error           // 故障
);
END_TYPE

TYPE ST_ClampSeg :
STRUCT
    uiPres: UINT;     // 段目标压力
    uiSpd: UINT;      // 段目标速度
    udiPos: UDINT;    // 段目标位置
    uiTime: UINT;     // 段最长执行时间
    uiPresGrad: UINT; // 压力渐进值
    uiSpdGrad: UINT;  // 速度渐进值
END_STRUCT
END_TYPE

TYPE ST_ClampPara :
STRUCT
    uiOpenSegCnt: UINT;                    // 开模段数量
    uiOpenMode: UINT;                      // 开模控制模式
    uiOpenLimitTime: UINT;                 // 开模最大允许时间
    stOpenUnloadPres: ST_ClampSeg;         // 开模卸荷段参数
    aOpenSeg: ARRAY[1..5] OF ST_ClampSeg;  // 开模段参数
    uiOpenPresStartGrad: UINT;             // 开模压力起始渐进
    uiOpenPresStopGrad: UINT;              // 开模压力停止渐进
    uiOpenSpdStartGrad: UINT;              // 开模速度起始渐进
    uiOpenSpdStopGrad: UINT;               // 开模速度停止渐进
    uiCloseSegCnt: UINT;                   // 合模段数量
    uiCloseMode: UINT;                     // 合模控制模式
    uiCloseLimitTime: UINT;                // 合模最大允许时间
    uiCloseLowPresLimitTime: UINT;         // 低压合模最长时间
    uiCloseEndMode: UINT;                  // 合模结束判定模式
    uiCloseEndHighPres: UINT;              // 合模结束高压阈值
    aCloseSeg: ARRAY[1..3] OF ST_ClampSeg; // 合模段参数
    stCloseLowPres: ST_ClampSeg;           // 低压合模段参数
    stCloseHighPres: ST_ClampSeg;          // 高压锁模段参数
    uiClosePresStartGrad: UINT;            // 合模压力起始渐进
    uiClosePresStopGrad: UINT;             // 合模压力停止渐进
    uiCloseSpdStartGrad: UINT;             // 合模速度起始渐进
    uiCloseSpdStopGrad: UINT;              // 合模速度停止渐进
    stOpenDebug: ST_ClampSeg;              // 开模调试段参数
    stCloseDebug: ST_ClampSeg;             // 合模调试段参数
    aCoreFn: ARRAY[1..8] OF UINT;          // 中子允许功能标识
    aCoreInMode: ARRAY[1..8] OF UINT;      // 中子进动作模式
    aCoreInStroke: ARRAY[1..8] OF UINT;    // 中子进行程
    aCoreInPos: ARRAY[1..8] OF UDINT;      // 中子进目标位置
    aCoreOutMode: ARRAY[1..8] OF UINT;     // 中子退动作模式
    aCoreOutStroke: ARRAY[1..8] OF UINT;   // 中子退行程
    aCoreOutPos: ARRAY[1..8] OF UDINT;     // 中子退目标位置
END_STRUCT
END_TYPE
