# AlgVex 执行方案

> **版本**: 2.0
> **日期**: 2025-12-31
> **目标**: 基于 Qlib v0.9.7 + Hummingbot v2.11.0 构建加密货币量化交易系统

---

## 一、项目概述

### 1.1 项目目标

构建一个完整的加密货币量化交易系统，集成：
- **Qlib**: 因子挖掘、模型训练、回测框架
- **Hummingbot**: 交易执行、连接器、风控

### 1.2 核心原则

1. **适配层模式**: 继承/扩展原有代码，不复制修改
2. **100% 功能覆盖**: 完整实现 Qlib 和 Hummingbot 所有功能
3. **加密货币适配**: 24/7 交易、永续合约、资金费率

### 1.3 技术选型

| 组件 | 版本 | 说明 |
|------|------|------|
| Python | 3.10 | 兼容 Qlib 和 Hummingbot |
| Qlib | 0.9.7 | git submodule |
| Hummingbot | 2.11.0 | git submodule |
| 操作系统 | Ubuntu 22.04 | 服务器部署 |

---

## 二、系统架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AlgVex Platform                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      用户接口层                               │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │   │
│  │  │   CLI    │  │Dashboard │  │   API    │  │  Config  │    │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      适配层 (algvex/)                        │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │   │
│  │  │   数据   │  │   因子   │  │   回测   │  │   执行   │    │   │
│  │  │ 适配器  │  │  适配器  │  │  适配器  │  │  适配器  │    │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │   │
│  │  │ 信号桥  │  │ 风控管理 │  │ 工作流  │                  │   │
│  │  └──────────┘  └──────────┘  └──────────┘                  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│  ┌───────────────────────────┴───────────────────────────────────┐ │
│  │                                                                 │ │
│  │  ┌─────────────────────┐       ┌─────────────────────┐        │ │
│  │  │    Qlib v0.9.7      │       │  Hummingbot v2.11.0 │        │ │
│  │  │  ┌───────────────┐  │       │  ┌───────────────┐  │        │ │
│  │  │  │ 32 个模型     │  │       │  │ 37 个连接器   │  │        │ │
│  │  │  │ 52 个操作符   │  │       │  │ 7 个执行器    │  │        │ │
│  │  │  │ 158 个因子    │  │       │  │ 9 个V1策略    │  │        │ │
│  │  │  │ 回测框架      │  │       │  │ 风控系统      │  │        │ │
│  │  │  │ 在线服务      │  │       │  │ MQTT/API      │  │        │ │
│  │  │  └───────────────┘  │       │  └───────────────┘  │        │ │
│  │  └─────────────────────┘       └─────────────────────┘        │ │
│  │           libs/qlib                   libs/hummingbot          │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 三、功能清单

> **适配策略图例**: 🟢 无需修改 | 🟡 需验证/微调 | 🔴 需实现适配层

### 3.1 Qlib 功能清单 (libs/qlib v0.9.7)

#### 3.1.1 模型 (32个) - 全部 🟢 无需修改

| 类别 | 数量 | 模型 | 源码路径 |
|------|------|------|----------|
| 传统ML | 5 | LinearModel, LGBModel, HFLGBModel, XGBModel, CatBoostModel | `qlib/contrib/model/{linear,gbdt,highfreq_gdbt_model,xgboost,catboost_model}.py` |
| RNN | 12 | LSTM, LSTM_ts, GRU, GRU_ts, ALSTM, ALSTM_ts, GATs, GATs_ts, KRNN, SFM, ADARNN, Sandwich | `qlib/contrib/model/pytorch_*.py` |
| Transformer | 4 | TransformerModel, TransformerModel_ts, LocalformerModel, LocalformerModel_ts | `qlib/contrib/model/pytorch_{transformer,localformer}*.py` |
| CNN | 3 | TCN, TCN_ts, TCTS | `qlib/contrib/model/pytorch_tc*.py` |
| 高级 | 8 | DNNModelPytorch, GeneralPTNN, TabnetModel, TRAModel, DEnsembleModel, IGMTF, HIST, ADD | `qlib/contrib/model/pytorch_{nn,general_nn,tabnet,tra,igmtf,hist,add}.py`, `double_ensemble.py` |

> **注**: 所有模型接受标准化输入，无需修改。仅需确保数据层提供正确格式。

#### 3.1.2 操作符 (52个)

| 类别 | 操作符 | 适配 |
|------|--------|------|
| 统计 (14) | Sum, Mean, Std, Var, Skew, Kurt, Med, Mad, Slope, Rsquare, Resi, Rank, Quantile, Count | 🟢 |
| 极值 (4) | Max, Min, IdxMax, IdxMin | 🟢 |
| 技术 (6) | EMA, WMA, Corr, Cov, Delta, Ref | 🟢 |
| 数学 (8) | Abs, Sign, Log, Power, Add, Sub, Mul, Div | 🟢 |
| 逻辑 (13) | Greater, Less, Gt, Ge, Lt, Le, Eq, Ne, And, Or, Not, If, Mask | 🟢 |
| 高频 (4) | DayCumsum, DayLast, get_calendar_day, get_calendar_minute | 🔴 需适配 24/7 日历 |
| 其他 (3) | ChangeInstrument, TResample, NpElemOperator | 🟢 |

> **源码**: `qlib/data/ops.py`, `qlib/contrib/ops/high_freq.py`

#### 3.1.3 数据基础设施

| 组件 | 说明 | 适配 | 源码路径 |
|------|------|------|----------|
| CalendarProvider | 日历提供者基类 | 🔴 需实现 CryptoCalendarProvider | `qlib/data/data.py` |
| InstrumentProvider | 标的提供者基类 | 🔴 需实现 CryptoInstrumentProvider | `qlib/data/data.py` |
| Alpha158/Alpha360 | 因子处理器 | 🟡 需适配窗口参数 | `qlib/contrib/data/handler.py` |
| 数据处理器 (10+) | DropnaProcessor, ZscoreNorm, CSRankNorm 等 | 🟢 | `qlib/contrib/data/processor.py` |

#### 3.1.4 回测与执行

| 组件 | 说明 | 适配 | 源码路径 |
|------|------|------|----------|
| Exchange | 交易所模拟基类 | 🔴 需实现 CryptoExchange | `qlib/backtest/exchange.py` |
| SimulatorExecutor | 基础模拟执行器 | 🟡 需适配永续合约规则 | `qlib/backtest/executor.py` |
| NestedExecutor | 嵌套多时间尺度执行 | 🟡 需适配 | `qlib/backtest/executor.py` |
| Position | 持仓管理 | 🔴 需实现 PerpetualPosition | `qlib/backtest/position.py` |

#### 3.1.5 工作流与在线服务

| 组件 | 说明 | 适配 | 源码路径 |
|------|------|------|----------|
| TaskManager | 任务生命周期管理 | 🟢 | `qlib/workflow/task/manage.py` |
| Trainer/TrainerR | 模型训练器 | 🟢 | `qlib/model/trainer.py` |
| OnlineManager | 在线模型管理 | 🟢 | `qlib/workflow/online/manager.py` |
| RollingGen | 滚动任务生成 | 🟢 | `qlib/workflow/task/gen.py` |
| PredUpdater | 增量预测更新 | 🟢 | `qlib/workflow/online/update.py` |

#### 3.1.6 其他模块

| 模块 | 组件 | 适配 |
|------|------|------|
| 风险模型 | POETCovEstimator, ShrinkCovEstimator, StructuredCovEstimator | 🟢 |
| 集成学习 | RollingEnsemble, AverageEnsemble, RollingGroup | 🟢 |
| 调优器 | Tuner, TunerPipeline, SearchSpace | 🟢 |
| 评估 | calc_ic, risk_analysis, backtest | 🟢 |
| 报告 | cumulative_return_graph, risk_analysis_graph 等 | 🟢 |
| RL 模块 | order_execution, Tianshou 集成 | 🟢 可选，后期添加 |

#### 3.1.7 已有 Crypto 数据收集器

> **重要**: Qlib 已有加密货币数据收集器，可直接扩展！

| 组件 | 说明 | 适配 | 源码路径 |
|------|------|------|----------|
| CryptoCollector | CoinGecko API 日线数据 | 🟡 扩展支持 Binance + 1h | `scripts/data_collector/crypto/collector.py` |

### 3.2 Hummingbot 功能清单 (libs/hummingbot v2.11.0)

#### 3.2.1 连接器 (37个) - 全部 🟢 无需修改

**永续合约 (11)**:
| 连接器 | 优先级 | 源码路径 |
|--------|--------|----------|
| binance_perpetual | ✅ 首选 | `connector/derivative/binance_perpetual/` |
| bybit_perpetual | 高 | `connector/derivative/bybit_perpetual/` |
| okx_perpetual | 高 | `connector/derivative/okx_perpetual/` |
| gate_io_perpetual | 中 | `connector/derivative/gate_io_perpetual/` |
| kucoin_perpetual | 中 | `connector/derivative/kucoin_perpetual/` |
| bitget_perpetual | 中 | `connector/derivative/bitget_perpetual/` |
| bitmart_perpetual | 低 | `connector/derivative/bitmart_perpetual/` |
| derive_perpetual | 低 | `connector/derivative/derive_perpetual/` |
| dydx_v4_perpetual | 低 | `connector/derivative/dydx_v4_perpetual/` |
| hyperliquid_perpetual | 低 | `connector/derivative/hyperliquid_perpetual/` |
| injective_v2_perpetual | 低 | `connector/derivative/injective_v2_perpetual/` |

**现货 (26)**: binance, bybit, okx, kucoin, gate_io, htx, mexc, bitget, kraken, coinbase_advanced_trade, bitstamp, bitmart, bitrue, bing_x, ascend_ex, btc_markets, cube, derive, dexalot, foxbit, hyperliquid, injective_v2, ndax, vertex, xrpl, paper_trade

> **源码**: `connector/exchange/{name}/`

#### 3.2.2 执行器 (7个) - 全部 🟢 无需修改

| 执行器 | 说明 | 源码路径 |
|--------|------|----------|
| OrderExecutor | 单订单执行 | `strategy_v2/executors/order_executor/` |
| PositionExecutor | 仓位执行 (Triple Barrier) | `strategy_v2/executors/position_executor/` |
| DCAExecutor | 定投执行 | `strategy_v2/executors/dca_executor/` |
| TWAPExecutor | 时间加权均价 | `strategy_v2/executors/twap_executor/` |
| GridExecutor | 网格执行 | `strategy_v2/executors/grid_executor/` |
| ArbitrageExecutor | 两腿套利 | `strategy_v2/executors/arbitrage_executor/` |
| XEMMExecutor | 跨交易所做市 | `strategy_v2/executors/xemm_executor/` |

#### 3.2.3 V1 策略 (9个) - 全部 🟢 可直接使用

| 策略 | 说明 | 源码路径 |
|------|------|----------|
| pure_market_making | 基础做市 | `strategy/pure_market_making/` |
| avellaneda_market_making | Avellaneda-Stoikov 做市 | `strategy/avellaneda_market_making/` |
| cross_exchange_market_making | 跨交易所做市 | `strategy/cross_exchange_market_making/` |
| cross_exchange_mining | 流动性挖矿做市 | `strategy/cross_exchange_mining/` |
| perpetual_market_making | 永续合约做市 | `strategy/perpetual_market_making/` |
| amm_arb | AMM-CEX 套利 | `strategy/amm_arb/` |
| spot_perpetual_arbitrage | 现货-永续套利 | `strategy/spot_perpetual_arbitrage/` |
| liquidity_mining | 流动性挖矿 | `strategy/liquidity_mining/` |
| hedge | 风险对冲 | `strategy/hedge/` |

#### 3.2.4 V2 控制器 - 全部 🟢 无需修改

| 控制器 | 说明 | 源码路径 |
|--------|------|----------|
| DirectionalTradingControllerBase | 方向性交易基类 | `strategy_v2/controllers/` |
| MarketMakingControllerBase | 做市基类 |
| ControllerBase | 控制器基类 |

#### 3.2.5 数据源 (21+ K线源) - 全部 🟢 无需修改

> **源码**: `data_feed/candles_feed/{exchange}_candles/`

binance_perpetual_candles, binance_spot_candles, bybit_perpetual_candles, okx_perpetual_candles, gate_io_perpetual_candles, kucoin_perpetual_candles, hyperliquid_perpetual_candles, mexc_perpetual_candles, bitget_perpetual_candles 等

#### 3.2.6 风控功能 - 全部 🟢 可直接使用

| 功能 | 说明 | 源码路径 |
|------|------|----------|
| Triple Barrier | 止盈/止损/时间限制 | `strategy_v2/executors/position_executor/` |
| Trailing Stop | 追踪止损 | `strategy_v2/executors/position_executor/` |
| Kill Switch | 紧急停止 | `core/kill_switch.py` |
| Balance Limit | 资产限额 | 配置文件 |
| Position Limit | 持仓限制 | 配置文件 |
| Rate Limiter | API 限速 | `connector/*/` |

#### 3.2.7 其他模块 - 全部 🟢 可直接使用

| 模块 | 说明 | 源码路径 |
|------|------|----------|
| MQTT | 消息推送 | `remote_iface/mqtt.py` |
| Paper Trading | 模拟交易 | `connector/exchange/paper_trade/` |
| Backtesting Engine | 回测引擎 | `strategy_v2/backtesting/` |
| 日志系统 | Hummingbot 内置 | `logger/` |

### 3.3 适配工作量汇总

| 类别 | 总数 | 🟢 无需修改 | 🟡 需验证 | 🔴 需实现 |
|------|------|-------------|-----------|-----------|
| Qlib 模型 | 32 | 32 | 0 | 0 |
| Qlib 操作符 | 52 | 48 | 0 | 4 |
| Qlib 基础设施 | 15+ | 10+ | 2 | 3 |
| Hummingbot 连接器 | 37 | 37 | 0 | 0 |
| Hummingbot 执行器 | 7 | 7 | 0 | 0 |
| Hummingbot 策略 | 9 | 9 | 0 | 0 |
| **总计** | **152+** | **143+** | **2** | **7** |

> **结论**: 95%+ 的功能可直接使用，仅需实现 7 个核心适配类

---

## 四、文件结构

```
AlgVex/
├── libs/                           # Git Submodules
│   ├── qlib/                       # Qlib v0.9.7
│   └── hummingbot/                 # Hummingbot v2.11.0
│
├── algvex/                         # 适配层代码
│   ├── __init__.py
│   │
│   ├── config/                     # 配置管理
│   │   ├── __init__.py
│   │   ├── settings.py             # 全局配置
│   │   ├── qlib_init.py            # Qlib 初始化
│   │   └── exchange_config.py      # 交易所配置
│   │
│   ├── data/                       # 数据层
│   │   ├── __init__.py
│   │   ├── calendar.py             # CryptoCalendarProvider
│   │   ├── instrument.py           # CryptoInstrumentProvider
│   │   ├── collector.py            # 数据收集器 (扩展 Qlib crypto)
│   │   ├── handler.py              # CryptoDataHandler
│   │   └── converter.py            # Hummingbot Candles -> Qlib 格式
│   │
│   ├── factors/                    # 因子层
│   │   ├── __init__.py
│   │   ├── alpha158.py             # CryptoAlpha158
│   │   ├── alpha360.py             # CryptoAlpha360
│   │   └── custom.py               # 自定义因子
│   │
│   ├── backtest/                   # 回测层
│   │   ├── __init__.py
│   │   ├── exchange.py             # CryptoExchange
│   │   ├── position.py             # PerpetualPosition
│   │   ├── executor.py             # CryptoExecutor
│   │   └── funding.py              # 资金费率计算
│   │
│   ├── bridge/                     # 信号桥
│   │   ├── __init__.py
│   │   ├── converter.py            # 信号转换
│   │   ├── redis_channel.py        # Redis 通道
│   │   └── mqtt_channel.py         # MQTT 通道
│   │
│   ├── execution/                  # 执行层
│   │   ├── __init__.py
│   │   ├── manager.py              # 执行器管理
│   │   └── router.py               # 订单路由
│   │
│   ├── risk/                       # 风控层
│   │   ├── __init__.py
│   │   ├── kill_switch.py          # 紧急停止
│   │   ├── position_limit.py       # 仓位限制
│   │   └── liquidation.py          # 强平监控
│   │
│   ├── workflow/                   # 工作流
│   │   ├── __init__.py
│   │   ├── trainer.py              # 训练管理
│   │   ├── rolling.py              # 滚动训练
│   │   └── online.py               # 在线服务
│   │
│   ├── dashboard/                  # 可视化 (使用 Hummingbot Dashboard 模式)
│   │   ├── __init__.py
│   │   └── app.py                  # Streamlit 入口
│   │
│   └── cli/                        # 命令行
│       ├── __init__.py
│       └── main.py                 # CLI 入口
│
├── config/                         # 配置文件
│   ├── settings.yaml               # 全局配置
│   ├── exchanges/                  # 交易所配置
│   │   ├── binance.yaml
│   │   ├── bybit.yaml
│   │   └── okx.yaml
│   └── strategies/                 # 策略配置
│       └── default.yaml
│
├── scripts/                        # 脚本
│   ├── install.sh                  # 一键安装
│   ├── start.sh                    # 启动脚本
│   ├── stop.sh                     # 停止脚本
│   └── download_data.py            # 数据下载
│
├── tests/                          # 测试
│   ├── unit/
│   ├── integration/
│   └── fixtures/
│
├── docs/                           # 文档
│   ├── TECHNICAL-PROPOSAL.md
│   └── EXECUTION-PLAN.md
│
├── requirements.txt                # Python 依赖
├── setup.py                        # 安装配置
└── README.md
```

---

## 五、开发规范

### 5.1 适配层接口定义

#### 5.1.1 数据层接口

```python
# algvex/data/calendar.py
from qlib.data.data import CalendarProvider

class CryptoCalendarProvider(CalendarProvider):
    """24/7 加密货币日历"""

    def calendar(self, start_time, end_time, freq="1h") -> List[pd.Timestamp]:
        """
        返回连续时间戳列表
        - 无休市日
        - 支持: 1min, 5min, 15min, 1h, 4h, 1d
        """
        pass
```

```python
# algvex/data/collector.py
from libs.qlib.scripts.data_collector.crypto.collector import CryptoCollector

class BinancePerpetualCollector(CryptoCollector):
    """币安永续合约数据收集器"""

    def __init__(self, symbols: List[str], interval: str = "1h"):
        """
        symbols: ["BTC-USDT", "ETH-USDT", ...]
        interval: 1min, 5min, 15min, 1h, 4h, 1d
        """
        pass

    def collect(self, start_date: str, end_date: str) -> pd.DataFrame:
        """收集数据并返回 DataFrame"""
        pass

    def to_qlib_format(self, df: pd.DataFrame) -> None:
        """转换为 Qlib 二进制格式"""
        pass
```

#### 5.1.2 回测层接口

```python
# algvex/backtest/exchange.py
from qlib.backtest.exchange import Exchange

class CryptoExchange(Exchange):
    """加密货币交易所模拟"""

    def __init__(
        self,
        leverage: int = 10,
        margin_mode: str = "cross",  # cross / isolated
        position_mode: str = "one_way",  # one_way / hedge
        funding_interval: int = 8,  # 小时
    ):
        pass

    def calculate_funding_fee(self, position, funding_rate: float) -> float:
        """计算资金费用"""
        pass

    def calculate_liquidation_price(self, position) -> float:
        """计算强平价格"""
        pass
```

#### 5.1.3 信号桥接口

```python
# algvex/bridge/converter.py
from dataclasses import dataclass
from typing import List

@dataclass
class TradingSignal:
    symbol: str
    side: str  # BUY / SELL
    amount: float
    price: float = None
    order_type: str = "MARKET"

class SignalConverter:
    """Qlib 信号 -> Hummingbot 订单"""

    def convert(self, qlib_predictions: pd.DataFrame) -> List[TradingSignal]:
        """
        qlib_predictions: instrument x datetime -> score
        返回: TradingSignal 列表
        """
        pass
```

### 5.2 代码规范

| 规范 | 要求 |
|------|------|
| 代码风格 | PEP 8 + Black 格式化 |
| 类型注解 | 所有公开接口必须有类型注解 |
| 文档字符串 | Google 风格 docstring |
| 测试覆盖率 | 核心模块 > 80% |
| 日志 | 使用 Qlib/Hummingbot 内置日志 |

### 5.3 详细实现规范

本节提供每个模块的完整实现规范，包含类继承关系、方法签名、数据流和依赖关系。

#### 5.3.1 数据层完整实现 (algvex/data/)

**文件清单与依赖关系**:

```
algvex/data/
├── __init__.py          # 导出所有公开类
├── calendar.py          # CryptoCalendarProvider (依赖: qlib.data.data.CalendarProvider)
├── instrument.py        # CryptoInstrumentProvider (依赖: qlib.data.data.InstrumentProvider)
├── collector.py         # BinancePerpetualCollector (依赖: libs.qlib.scripts.data_collector.crypto)
├── handler.py           # CryptoDataHandler (依赖: qlib.contrib.data.handler.Alpha158)
└── converter.py         # HummingbotDataConverter (依赖: hummingbot.data_feed.candles_feed)
```

**calendar.py 完整实现**:

```python
"""
加密货币 24/7 日历提供者

继承关系: CryptoCalendarProvider -> CalendarProvider
引用路径: libs/qlib/qlib/data/data.py::CalendarProvider
"""
from typing import List, Union
import pandas as pd
from qlib.data.data import CalendarProvider

class CryptoCalendarProvider(CalendarProvider):
    """
    24/7 加密货币交易日历

    与传统股票市场不同，加密货币市场全年无休，
    本类生成连续的时间戳序列，无需排除节假日。

    Attributes:
        SUPPORTED_FREQS: 支持的时间频率列表
    """

    SUPPORTED_FREQS = {
        "1min": "T",
        "5min": "5T",
        "15min": "15T",
        "30min": "30T",
        "1h": "H",
        "4h": "4H",
        "1d": "D",
    }

    def __init__(self):
        """初始化日历提供者"""
        super().__init__()

    def calendar(
        self,
        start_time: Union[str, pd.Timestamp],
        end_time: Union[str, pd.Timestamp],
        freq: str = "1h",
        future: bool = False,
    ) -> List[pd.Timestamp]:
        """
        生成指定时间范围内的交易时间戳列表

        Args:
            start_time: 开始时间 (格式: "2024-01-01" 或 pd.Timestamp)
            end_time: 结束时间
            freq: 时间频率 ("1min", "5min", "15min", "1h", "4h", "1d")
            future: 是否包含未来时间 (通常为 False)

        Returns:
            List[pd.Timestamp]: 时间戳列表

        Raises:
            ValueError: 如果 freq 不在支持列表中

        Example:
            >>> provider = CryptoCalendarProvider()
            >>> cal = provider.calendar("2024-01-01", "2024-01-02", freq="1h")
            >>> len(cal)
            24
        """
        if freq not in self.SUPPORTED_FREQS:
            raise ValueError(f"不支持的频率: {freq}, 支持: {list(self.SUPPORTED_FREQS.keys())}")

        pd_freq = self.SUPPORTED_FREQS[freq]
        start = pd.Timestamp(start_time)
        end = pd.Timestamp(end_time)

        # 生成连续时间序列 (24/7 无休市)
        timestamps = pd.date_range(start=start, end=end, freq=pd_freq)

        if not future:
            now = pd.Timestamp.now()
            timestamps = timestamps[timestamps <= now]

        return timestamps.tolist()

    def locate_index(
        self,
        start_time: Union[str, pd.Timestamp],
        end_time: Union[str, pd.Timestamp],
        freq: str = "1h",
        future: bool = False,
    ) -> tuple:
        """
        获取时间范围在日历中的索引位置

        Args:
            start_time: 开始时间
            end_time: 结束时间
            freq: 时间频率
            future: 是否包含未来

        Returns:
            tuple: (start_index, end_index)
        """
        cal = self.calendar(start_time, end_time, freq, future)
        return 0, len(cal) - 1
```

**instrument.py 完整实现**:

```python
"""
加密货币品种提供者

继承关系: CryptoInstrumentProvider -> InstrumentProvider
引用路径: libs/qlib/qlib/data/data.py::InstrumentProvider
"""
from typing import List, Dict, Union
import pandas as pd
from qlib.data.data import InstrumentProvider

class CryptoInstrumentProvider(InstrumentProvider):
    """
    加密货币交易品种管理

    管理支持的加密货币交易对列表，提供品种筛选和查询功能。

    Attributes:
        DEFAULT_SYMBOLS: 默认支持的交易对列表
    """

    DEFAULT_SYMBOLS = [
        "BTC-USDT", "ETH-USDT", "BNB-USDT", "SOL-USDT", "XRP-USDT",
        "ADA-USDT", "DOGE-USDT", "AVAX-USDT", "DOT-USDT", "MATIC-USDT",
        "LINK-USDT", "UNI-USDT", "ATOM-USDT", "LTC-USDT", "ETC-USDT",
        "FIL-USDT", "APT-USDT", "ARB-USDT", "OP-USDT", "INJ-USDT",
    ]

    def __init__(self, symbols: List[str] = None):
        """
        初始化品种提供者

        Args:
            symbols: 自定义品种列表，None 则使用默认列表
        """
        super().__init__()
        self.symbols = symbols or self.DEFAULT_SYMBOLS

    def list_instruments(
        self,
        instruments: Union[str, List[str]] = None,
        start_time: str = None,
        end_time: str = None,
        as_list: bool = False,
    ) -> Union[Dict[str, tuple], List[str]]:
        """
        列出可用的交易品种

        Args:
            instruments: 品种筛选条件 (支持 "all", "top10", 或具体列表)
            start_time: 开始时间 (加密货币无历史限制，可忽略)
            end_time: 结束时间
            as_list: 是否返回列表格式

        Returns:
            Union[Dict, List]: 品种信息字典或列表

        Example:
            >>> provider = CryptoInstrumentProvider()
            >>> symbols = provider.list_instruments(instruments="top10", as_list=True)
            >>> len(symbols)
            10
        """
        if instruments == "all" or instruments is None:
            selected = self.symbols
        elif instruments == "top10":
            selected = self.symbols[:10]
        elif instruments == "top20":
            selected = self.symbols[:20]
        elif isinstance(instruments, list):
            selected = [s for s in instruments if s in self.symbols]
        else:
            selected = self.symbols

        if as_list:
            return selected

        # 返回 {symbol: (start_time, end_time)} 格式
        return {s: (start_time, end_time) for s in selected}
```

**collector.py 完整实现**:

```python
"""
币安永续合约数据收集器

继承关系: BinancePerpetualCollector -> CryptoCollector
引用路径: libs/qlib/scripts/data_collector/crypto/collector.py::CryptoCollector
"""
import os
import time
from typing import List, Optional
from datetime import datetime
import pandas as pd
import requests
from pathlib import Path

# 尝试导入 Qlib 的 CryptoCollector，如果不存在则使用基类
try:
    from libs.qlib.scripts.data_collector.crypto.collector import CryptoCollector
    BASE_CLASS = CryptoCollector
except ImportError:
    BASE_CLASS = object

class BinancePerpetualCollector(BASE_CLASS):
    """
    币安永续合约 OHLCV 数据收集器

    从币安 API 获取永续合约的 K 线数据，并转换为 Qlib 格式。

    Attributes:
        BASE_URL: 币安 API 基础 URL
        INTERVALS: 支持的 K 线周期映射
        RATE_LIMIT: API 请求间隔 (秒)
    """

    BASE_URL = "https://fapi.binance.com"

    INTERVALS = {
        "1min": "1m",
        "5min": "5m",
        "15min": "15m",
        "30min": "30m",
        "1h": "1h",
        "4h": "4h",
        "1d": "1d",
    }

    RATE_LIMIT = 0.1  # 100ms 间隔避免限速

    def __init__(
        self,
        symbols: List[str],
        interval: str = "1h",
        output_dir: str = "./data/crypto",
    ):
        """
        初始化收集器

        Args:
            symbols: 交易对列表 (格式: ["BTC-USDT", "ETH-USDT"])
            interval: K 线周期
            output_dir: 数据输出目录

        Raises:
            ValueError: 如果 interval 不支持
        """
        if interval not in self.INTERVALS:
            raise ValueError(f"不支持的周期: {interval}")

        self.symbols = symbols
        self.interval = interval
        self.binance_interval = self.INTERVALS[interval]
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def _convert_symbol(self, symbol: str) -> str:
        """
        转换品种格式: BTC-USDT -> BTCUSDT
        """
        return symbol.replace("-", "")

    def _fetch_klines(
        self,
        symbol: str,
        start_time: int,
        end_time: int,
        limit: int = 1000,
    ) -> List[list]:
        """
        从币安 API 获取 K 线数据

        Args:
            symbol: 币安格式的交易对 (如 BTCUSDT)
            start_time: 开始时间戳 (毫秒)
            end_time: 结束时间戳 (毫秒)
            limit: 每次请求的数据条数 (最大 1500)

        Returns:
            List[list]: K 线数据列表
        """
        url = f"{self.BASE_URL}/fapi/v1/klines"
        params = {
            "symbol": symbol,
            "interval": self.binance_interval,
            "startTime": start_time,
            "endTime": end_time,
            "limit": limit,
        }

        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        return response.json()

    def collect(
        self,
        start_date: str,
        end_date: str,
        show_progress: bool = True,
    ) -> pd.DataFrame:
        """
        收集指定时间范围的数据

        Args:
            start_date: 开始日期 (格式: "2024-01-01")
            end_date: 结束日期
            show_progress: 是否显示进度

        Returns:
            pd.DataFrame: 包含所有品种数据的 DataFrame

        Columns:
            - datetime: 时间戳
            - instrument: 品种代码
            - open, high, low, close: OHLC 价格
            - volume: 成交量
            - amount: 成交额
        """
        start_ts = int(pd.Timestamp(start_date).timestamp() * 1000)
        end_ts = int(pd.Timestamp(end_date).timestamp() * 1000)

        all_data = []

        for i, symbol in enumerate(self.symbols):
            if show_progress:
                print(f"收集 {symbol} ({i+1}/{len(self.symbols)})...")

            binance_symbol = self._convert_symbol(symbol)
            symbol_data = []
            current_start = start_ts

            while current_start < end_ts:
                try:
                    klines = self._fetch_klines(
                        binance_symbol,
                        current_start,
                        end_ts,
                        limit=1000,
                    )

                    if not klines:
                        break

                    for k in klines:
                        symbol_data.append({
                            "datetime": pd.Timestamp(k[0], unit="ms"),
                            "instrument": symbol,
                            "open": float(k[1]),
                            "high": float(k[2]),
                            "low": float(k[3]),
                            "close": float(k[4]),
                            "volume": float(k[5]),
                            "amount": float(k[7]),  # Quote asset volume
                        })

                    # 更新起始时间为最后一条数据的时间 + 1
                    current_start = klines[-1][0] + 1
                    time.sleep(self.RATE_LIMIT)

                except Exception as e:
                    print(f"获取 {symbol} 数据失败: {e}")
                    break

            all_data.extend(symbol_data)

        df = pd.DataFrame(all_data)
        if not df.empty:
            df = df.sort_values(["instrument", "datetime"]).reset_index(drop=True)

        return df

    def to_qlib_format(
        self,
        df: pd.DataFrame,
        qlib_dir: str = None,
    ) -> None:
        """
        将数据转换为 Qlib 二进制格式

        Args:
            df: 收集的原始数据 DataFrame
            qlib_dir: Qlib 数据目录 (默认: output_dir/qlib_data)

        生成文件结构:
            qlib_dir/
            ├── calendars/
            │   └── crypto.txt
            ├── instruments/
            │   └── all.txt
            └── features/
                ├── BTC-USDT/
                │   ├── open.bin
                │   ├── high.bin
                │   └── ...
                └── ETH-USDT/
                    └── ...
        """
        if qlib_dir is None:
            qlib_dir = self.output_dir / "qlib_data"

        qlib_dir = Path(qlib_dir)

        # 创建目录结构
        (qlib_dir / "calendars").mkdir(parents=True, exist_ok=True)
        (qlib_dir / "instruments").mkdir(parents=True, exist_ok=True)
        (qlib_dir / "features").mkdir(parents=True, exist_ok=True)

        # 生成日历文件
        calendar = df["datetime"].drop_duplicates().sort_values()
        calendar_file = qlib_dir / "calendars" / "crypto.txt"
        with open(calendar_file, "w") as f:
            for dt in calendar:
                f.write(dt.strftime("%Y-%m-%d %H:%M:%S") + "\n")

        # 生成品种列表文件
        instruments = df["instrument"].unique()
        instruments_file = qlib_dir / "instruments" / "all.txt"
        with open(instruments_file, "w") as f:
            for inst in instruments:
                start = df[df["instrument"] == inst]["datetime"].min()
                end = df[df["instrument"] == inst]["datetime"].max()
                f.write(f"{inst}\t{start.strftime('%Y-%m-%d')}\t{end.strftime('%Y-%m-%d')}\n")

        # 生成特征文件 (简化版本，实际应使用 Qlib 的 dump_bin)
        features = ["open", "high", "low", "close", "volume", "amount"]
        for inst in instruments:
            inst_dir = qlib_dir / "features" / inst
            inst_dir.mkdir(parents=True, exist_ok=True)

            inst_data = df[df["instrument"] == inst].set_index("datetime").sort_index()
            for feat in features:
                feat_file = inst_dir / f"{feat}.bin"
                inst_data[feat].values.astype("float32").tofile(feat_file)

        print(f"Qlib 数据已保存到: {qlib_dir}")
```

**handler.py 完整实现**:

```python
"""
加密货币数据处理器

继承关系: CryptoDataHandler -> Alpha158
引用路径: libs/qlib/qlib/contrib/data/handler.py::Alpha158
"""
from typing import List, Dict, Any
from qlib.contrib.data.handler import Alpha158
from qlib.contrib.data.loader import Alpha158DL

class CryptoAlpha158Config:
    """Alpha158 加密货币配置"""

    # 窗口模式
    WINDOW_MODE = "compressed"  # "compressed" 或 "equivalent"

    # 压缩窗口 (适合高频交易)
    COMPRESSED_WINDOWS = [24, 48, 120, 168, 336]

    # 等价窗口 (保持与日线相同的回溯天数)
    EQUIVALENT_WINDOWS = [120, 240, 480, 720, 1440]

    @classmethod
    def get_windows(cls) -> List[int]:
        """获取当前配置的窗口列表"""
        if cls.WINDOW_MODE == "compressed":
            return cls.COMPRESSED_WINDOWS
        return cls.EQUIVALENT_WINDOWS


class CryptoDataHandler(Alpha158):
    """
    加密货币 Alpha158 数据处理器

    扩展 Qlib Alpha158，适配加密货币市场特性:
    - 24/7 交易日历
    - 小时级别数据
    - 自定义窗口参数

    Attributes:
        CUSTOM_FACTORS: 加密货币特有因子
    """

    CUSTOM_FACTORS = [
        "funding_rate",      # 资金费率
        "open_interest",     # 持仓量
        "long_short_ratio",  # 多空比
    ]

    def __init__(
        self,
        instruments: str = "all",
        start_time: str = None,
        end_time: str = None,
        freq: str = "1h",
        window_mode: str = "compressed",
        include_custom_factors: bool = True,
        **kwargs,
    ):
        """
        初始化处理器

        Args:
            instruments: 品种范围
            start_time: 开始时间
            end_time: 结束时间
            freq: 数据频率 (默认 1h)
            window_mode: 窗口模式 ("compressed" 或 "equivalent")
            include_custom_factors: 是否包含自定义因子
            **kwargs: 传递给父类的其他参数
        """
        CryptoAlpha158Config.WINDOW_MODE = window_mode
        self.include_custom_factors = include_custom_factors

        super().__init__(
            instruments=instruments,
            start_time=start_time,
            end_time=end_time,
            freq=freq,
            **kwargs,
        )

    @classmethod
    def get_feature_config(cls) -> Dict[str, Any]:
        """
        获取特征配置

        重写父类方法，使用加密货币适配的窗口参数

        Returns:
            Dict: 特征配置字典
        """
        windows = CryptoAlpha158Config.get_windows()

        config = {
            "price": {
                "windows": [0, 1, 2, 3, 4],
                "feature": ["open", "high", "low", "close"],
            },
            "volume": {
                "windows": [0, 1, 2, 3, 4],
            },
            "rolling": {
                "windows": windows,
            },
        }

        return Alpha158DL.get_feature_config(config)
```

#### 5.3.2 回测层完整实现 (algvex/backtest/)

**文件清单与依赖关系**:

```
algvex/backtest/
├── __init__.py
├── exchange.py          # CryptoExchange (依赖: qlib.backtest.exchange.Exchange)
├── position.py          # PerpetualPosition (依赖: qlib.backtest.position.Position)
├── executor.py          # CryptoExecutor (依赖: qlib.backtest.executor.SimulatorExecutor)
└── funding.py           # FundingRateCalculator (独立模块)
```

**exchange.py 完整实现**:

```python
"""
加密货币交易所模拟器

继承关系: CryptoExchange -> Exchange
引用路径: libs/qlib/qlib/backtest/exchange.py::Exchange
"""
from typing import Dict, Optional, Tuple
from decimal import Decimal
import pandas as pd
from qlib.backtest.exchange import Exchange

class MarginMode:
    """保证金模式"""
    CROSS = "cross"      # 全仓
    ISOLATED = "isolated"  # 逐仓

class PositionMode:
    """持仓模式"""
    ONE_WAY = "one_way"  # 单向持仓
    HEDGE = "hedge"      # 双向持仓


class CryptoExchange(Exchange):
    """
    加密货币交易所模拟

    扩展 Qlib Exchange，支持:
    - 杠杆交易 (1-125x)
    - 永续合约
    - 资金费率结算
    - 强平机制

    Attributes:
        DEFAULT_LEVERAGE: 默认杠杆倍数
        DEFAULT_MARGIN_MODE: 默认保证金模式
        MAKER_FEE: Maker 手续费率
        TAKER_FEE: Taker 手续费率
    """

    DEFAULT_LEVERAGE = 10
    DEFAULT_MARGIN_MODE = MarginMode.CROSS
    MAKER_FEE = Decimal("0.0002")  # 0.02%
    TAKER_FEE = Decimal("0.0004")  # 0.04%
    FUNDING_INTERVAL = 8  # 小时

    def __init__(
        self,
        leverage: int = 10,
        margin_mode: str = MarginMode.CROSS,
        position_mode: str = PositionMode.ONE_WAY,
        funding_interval: int = 8,
        maintenance_margin_rate: float = 0.004,
        **kwargs,
    ):
        """
        初始化交易所模拟器

        Args:
            leverage: 杠杆倍数 (1-125)
            margin_mode: 保证金模式 ("cross" 或 "isolated")
            position_mode: 持仓模式 ("one_way" 或 "hedge")
            funding_interval: 资金费率结算间隔 (小时)
            maintenance_margin_rate: 维持保证金率
            **kwargs: 传递给父类的参数

        Raises:
            ValueError: 杠杆倍数超出范围
        """
        if not 1 <= leverage <= 125:
            raise ValueError(f"杠杆倍数必须在 1-125 之间，当前: {leverage}")

        super().__init__(**kwargs)

        self.leverage = leverage
        self.margin_mode = margin_mode
        self.position_mode = position_mode
        self.funding_interval = funding_interval
        self.maintenance_margin_rate = Decimal(str(maintenance_margin_rate))

        # 资金费率历史
        self._funding_rates: Dict[str, pd.DataFrame] = {}

    def set_funding_rates(self, symbol: str, rates: pd.DataFrame) -> None:
        """
        设置品种的历史资金费率

        Args:
            symbol: 交易对
            rates: 资金费率 DataFrame (index: datetime, columns: ["rate"])
        """
        self._funding_rates[symbol] = rates

    def get_funding_rate(self, symbol: str, timestamp: pd.Timestamp) -> Decimal:
        """
        获取指定时间的资金费率

        Args:
            symbol: 交易对
            timestamp: 时间戳

        Returns:
            Decimal: 资金费率 (如 0.0001 表示 0.01%)
        """
        if symbol not in self._funding_rates:
            return Decimal("0.0001")  # 默认费率

        rates = self._funding_rates[symbol]
        if timestamp in rates.index:
            return Decimal(str(rates.loc[timestamp, "rate"]))

        # 找最近的费率
        idx = rates.index.get_indexer([timestamp], method="ffill")[0]
        if idx >= 0:
            return Decimal(str(rates.iloc[idx]["rate"]))

        return Decimal("0.0001")

    def calculate_funding_fee(
        self,
        symbol: str,
        position_value: Decimal,
        funding_rate: Decimal,
        is_long: bool,
    ) -> Decimal:
        """
        计算资金费用

        Args:
            symbol: 交易对
            position_value: 仓位价值 (数量 * 价格)
            funding_rate: 资金费率
            is_long: 是否多头

        Returns:
            Decimal: 资金费用 (正数为支付，负数为收取)

        公式:
            多头: funding_fee = position_value * funding_rate
            空头: funding_fee = -position_value * funding_rate
        """
        fee = position_value * funding_rate
        return fee if is_long else -fee

    def calculate_liquidation_price(
        self,
        entry_price: Decimal,
        leverage: int,
        is_long: bool,
        margin_mode: str = None,
    ) -> Decimal:
        """
        计算强平价格

        Args:
            entry_price: 开仓价格
            leverage: 杠杆倍数
            is_long: 是否多头
            margin_mode: 保证金模式 (默认使用实例配置)

        Returns:
            Decimal: 强平价格

        公式 (全仓简化版):
            多头: liquidation_price = entry_price * (1 - 1/leverage + mmr)
            空头: liquidation_price = entry_price * (1 + 1/leverage - mmr)
        """
        margin_mode = margin_mode or self.margin_mode
        mmr = self.maintenance_margin_rate

        if is_long:
            liq_price = entry_price * (1 - Decimal(1) / leverage + mmr)
        else:
            liq_price = entry_price * (1 + Decimal(1) / leverage - mmr)

        return liq_price

    def calculate_pnl(
        self,
        entry_price: Decimal,
        exit_price: Decimal,
        quantity: Decimal,
        leverage: int,
        is_long: bool,
    ) -> Dict[str, Decimal]:
        """
        计算盈亏

        Args:
            entry_price: 开仓价格
            exit_price: 平仓价格
            quantity: 数量
            leverage: 杠杆倍数
            is_long: 是否多头

        Returns:
            Dict: 包含 pnl, roe, margin 的字典
        """
        position_value = entry_price * quantity
        margin = position_value / leverage

        if is_long:
            pnl = (exit_price - entry_price) * quantity
        else:
            pnl = (entry_price - exit_price) * quantity

        roe = pnl / margin if margin > 0 else Decimal(0)

        return {
            "pnl": pnl,
            "roe": roe,
            "margin": margin,
            "position_value": position_value,
        }
```

**funding.py 完整实现**:

```python
"""
资金费率计算模块

独立模块，不依赖 Qlib
"""
from typing import Optional, Tuple
from decimal import Decimal
from datetime import datetime, timedelta
import pandas as pd


class FundingRateCalculator:
    """
    资金费率计算器

    实现资金费率的计算和结算逻辑。

    资金费率公式:
        Funding Rate = Average Premium Index + clamp(Interest Rate - Premium Index, -0.05%, 0.05%)

    其中:
        Premium Index = (Max(0, Impact Bid Price - Mark Price) - Max(0, Mark Price - Impact Ask Price)) / Mark Price
        Interest Rate = (Quote Interest Rate - Base Interest Rate) / Funding Interval

    Attributes:
        DEFAULT_INTEREST_RATE: 默认利率 (通常为 0.03% / 天)
        CLAMP_RANGE: 费率钳制范围
    """

    DEFAULT_INTEREST_RATE = Decimal("0.0001")  # 0.01%
    CLAMP_RANGE = (Decimal("-0.0005"), Decimal("0.0005"))  # -0.05% ~ 0.05%
    FUNDING_INTERVALS = [0, 8, 16]  # UTC 时间

    @classmethod
    def calculate_premium_index(
        cls,
        impact_bid: Decimal,
        impact_ask: Decimal,
        mark_price: Decimal,
    ) -> Decimal:
        """
        计算溢价指数

        Args:
            impact_bid: 深度加权买一价
            impact_ask: 深度加权卖一价
            mark_price: 标记价格

        Returns:
            Decimal: 溢价指数
        """
        bid_premium = max(Decimal(0), impact_bid - mark_price)
        ask_premium = max(Decimal(0), mark_price - impact_ask)
        return (bid_premium - ask_premium) / mark_price

    @classmethod
    def calculate_funding_rate(
        cls,
        premium_index: Decimal,
        interest_rate: Decimal = None,
    ) -> Decimal:
        """
        计算资金费率

        Args:
            premium_index: 溢价指数
            interest_rate: 利率差 (默认使用 DEFAULT_INTEREST_RATE)

        Returns:
            Decimal: 资金费率
        """
        interest_rate = interest_rate or cls.DEFAULT_INTEREST_RATE

        # 钳制
        diff = interest_rate - premium_index
        clamped = max(cls.CLAMP_RANGE[0], min(cls.CLAMP_RANGE[1], diff))

        return premium_index + clamped

    @classmethod
    def get_next_funding_time(cls, current_time: datetime) -> datetime:
        """
        获取下一个资金费率结算时间

        Args:
            current_time: 当前时间 (UTC)

        Returns:
            datetime: 下一个结算时间
        """
        current_hour = current_time.hour

        for funding_hour in cls.FUNDING_INTERVALS:
            if current_hour < funding_hour:
                return current_time.replace(
                    hour=funding_hour, minute=0, second=0, microsecond=0
                )

        # 下一天的 00:00
        next_day = current_time + timedelta(days=1)
        return next_day.replace(hour=0, minute=0, second=0, microsecond=0)

    @classmethod
    def is_funding_time(cls, timestamp: datetime) -> bool:
        """
        检查是否为资金费率结算时间

        Args:
            timestamp: 时间戳

        Returns:
            bool: 是否为结算时间
        """
        return (
            timestamp.hour in cls.FUNDING_INTERVALS
            and timestamp.minute == 0
            and timestamp.second == 0
        )
```

#### 5.3.3 信号桥完整实现 (algvex/bridge/)

**文件清单与依赖关系**:

```
algvex/bridge/
├── __init__.py
├── converter.py         # SignalConverter (独立模块)
├── redis_channel.py     # RedisSignalChannel (依赖: redis)
└── mqtt_channel.py      # MQTTSignalChannel (依赖: hummingbot.remote_iface.mqtt)
```

**converter.py 完整实现**:

```python
"""
Qlib 信号到 Hummingbot 订单转换器
"""
from dataclasses import dataclass, field
from typing import List, Dict, Optional
from enum import Enum
from decimal import Decimal
import pandas as pd


class OrderSide(str, Enum):
    """订单方向"""
    BUY = "BUY"
    SELL = "SELL"


class OrderType(str, Enum):
    """订单类型"""
    MARKET = "MARKET"
    LIMIT = "LIMIT"
    STOP_MARKET = "STOP_MARKET"
    TAKE_PROFIT_MARKET = "TAKE_PROFIT_MARKET"


@dataclass
class TradingSignal:
    """
    交易信号数据类

    Attributes:
        symbol: 交易对 (如 "BTC-USDT")
        side: 订单方向 (BUY/SELL)
        amount: 交易数量
        score: 模型预测分数 (用于排序和分配仓位)
        price: 限价单价格 (市价单为 None)
        order_type: 订单类型
        leverage: 杠杆倍数
        stop_loss: 止损价格
        take_profit: 止盈价格
    """
    symbol: str
    side: OrderSide
    amount: Decimal
    score: float = 0.0
    price: Optional[Decimal] = None
    order_type: OrderType = OrderType.MARKET
    leverage: int = 10
    stop_loss: Optional[Decimal] = None
    take_profit: Optional[Decimal] = None

    def to_dict(self) -> Dict:
        """转换为字典格式"""
        return {
            "symbol": self.symbol,
            "side": self.side.value,
            "amount": str(self.amount),
            "score": self.score,
            "price": str(self.price) if self.price else None,
            "order_type": self.order_type.value,
            "leverage": self.leverage,
            "stop_loss": str(self.stop_loss) if self.stop_loss else None,
            "take_profit": str(self.take_profit) if self.take_profit else None,
        }


class SignalConverter:
    """
    Qlib 预测信号转换器

    将 Qlib 模型的预测结果转换为可执行的交易信号。

    Attributes:
        long_threshold: 做多阈值 (score > threshold)
        short_threshold: 做空阈值 (score < -threshold)
        max_positions: 最大持仓数量
        position_size_mode: 仓位分配模式
    """

    def __init__(
        self,
        long_threshold: float = 0.0,
        short_threshold: float = 0.0,
        max_positions: int = 10,
        position_size_mode: str = "equal",  # "equal", "score_weighted", "volatility_adjusted"
        total_capital: Decimal = Decimal("10000"),
        default_leverage: int = 10,
    ):
        """
        初始化转换器

        Args:
            long_threshold: 做多阈值
            short_threshold: 做空阈值 (使用负值)
            max_positions: 最大同时持仓数
            position_size_mode: 仓位大小计算模式
            total_capital: 总资金
            default_leverage: 默认杠杆
        """
        self.long_threshold = long_threshold
        self.short_threshold = short_threshold
        self.max_positions = max_positions
        self.position_size_mode = position_size_mode
        self.total_capital = total_capital
        self.default_leverage = default_leverage

    def convert(
        self,
        predictions: pd.DataFrame,
        current_prices: Dict[str, Decimal] = None,
    ) -> List[TradingSignal]:
        """
        转换 Qlib 预测结果为交易信号

        Args:
            predictions: Qlib 预测 DataFrame
                格式: MultiIndex (datetime, instrument) -> score
                或 columns: ["instrument", "score"]
            current_prices: 当前价格字典 {symbol: price}

        Returns:
            List[TradingSignal]: 交易信号列表

        Example:
            >>> converter = SignalConverter(long_threshold=0.02)
            >>> predictions = pd.DataFrame({
            ...     "instrument": ["BTC-USDT", "ETH-USDT"],
            ...     "score": [0.05, -0.03]
            ... })
            >>> signals = converter.convert(predictions)
            >>> len(signals)
            2
        """
        signals = []
        current_prices = current_prices or {}

        # 标准化输入格式
        if isinstance(predictions.index, pd.MultiIndex):
            df = predictions.reset_index()
            df.columns = ["datetime", "instrument", "score"]
        else:
            df = predictions.copy()

        # 筛选信号
        long_candidates = df[df["score"] > self.long_threshold].nlargest(
            self.max_positions, "score"
        )
        short_candidates = df[df["score"] < -abs(self.short_threshold)].nsmallest(
            self.max_positions, "score"
        )

        # 计算仓位大小
        total_signals = len(long_candidates) + len(short_candidates)
        if total_signals == 0:
            return signals

        position_value = self.total_capital / Decimal(min(total_signals, self.max_positions))

        # 生成多头信号
        for _, row in long_candidates.iterrows():
            symbol = row["instrument"]
            score = row["score"]
            price = current_prices.get(symbol, Decimal("1"))

            amount = self._calculate_amount(position_value, price, score)

            signals.append(TradingSignal(
                symbol=symbol,
                side=OrderSide.BUY,
                amount=amount,
                score=score,
                leverage=self.default_leverage,
            ))

        # 生成空头信号
        for _, row in short_candidates.iterrows():
            symbol = row["instrument"]
            score = row["score"]
            price = current_prices.get(symbol, Decimal("1"))

            amount = self._calculate_amount(position_value, price, abs(score))

            signals.append(TradingSignal(
                symbol=symbol,
                side=OrderSide.SELL,
                amount=amount,
                score=score,
                leverage=self.default_leverage,
            ))

        return signals

    def _calculate_amount(
        self,
        position_value: Decimal,
        price: Decimal,
        score: float,
    ) -> Decimal:
        """
        计算交易数量

        Args:
            position_value: 分配的仓位价值
            price: 当前价格
            score: 预测分数

        Returns:
            Decimal: 交易数量
        """
        if self.position_size_mode == "equal":
            return position_value / price
        elif self.position_size_mode == "score_weighted":
            weight = Decimal(str(min(abs(score) * 10, 2.0)))  # 最大 2 倍
            return (position_value * weight) / price
        else:
            return position_value / price
```

**redis_channel.py 完整实现**:

```python
"""
Redis 信号通道

用于 Qlib 和 Hummingbot 之间的实时信号传递
"""
import json
from typing import List, Optional, Callable
from dataclasses import asdict
import redis

from .converter import TradingSignal


class RedisSignalChannel:
    """
    Redis 信号通道

    使用 Redis Pub/Sub 实现 Qlib 信号到 Hummingbot 的实时传递。

    Channels:
        - algvex:signals: 交易信号发布通道
        - algvex:status: 系统状态通道
        - algvex:commands: 控制命令通道

    Attributes:
        SIGNAL_CHANNEL: 信号发布通道名
        STATUS_CHANNEL: 状态通道名
        COMMAND_CHANNEL: 命令通道名
    """

    SIGNAL_CHANNEL = "algvex:signals"
    STATUS_CHANNEL = "algvex:status"
    COMMAND_CHANNEL = "algvex:commands"

    def __init__(
        self,
        host: str = "localhost",
        port: int = 6379,
        db: int = 0,
        password: str = None,
    ):
        """
        初始化 Redis 连接

        Args:
            host: Redis 主机地址
            port: Redis 端口
            db: Redis 数据库编号
            password: Redis 密码 (可选)
        """
        self.redis = redis.Redis(
            host=host,
            port=port,
            db=db,
            password=password,
            decode_responses=True,
        )
        self.pubsub = None

    def publish_signals(self, signals: List[TradingSignal]) -> int:
        """
        发布交易信号

        Args:
            signals: 交易信号列表

        Returns:
            int: 接收到消息的订阅者数量
        """
        message = {
            "type": "signals",
            "data": [s.to_dict() for s in signals],
        }
        return self.redis.publish(self.SIGNAL_CHANNEL, json.dumps(message))

    def publish_status(self, status: dict) -> int:
        """
        发布系统状态

        Args:
            status: 状态信息字典

        Returns:
            int: 接收到消息的订阅者数量
        """
        message = {
            "type": "status",
            "data": status,
        }
        return self.redis.publish(self.STATUS_CHANNEL, json.dumps(message))

    def subscribe(
        self,
        on_signal: Callable[[List[dict]], None] = None,
        on_status: Callable[[dict], None] = None,
        on_command: Callable[[dict], None] = None,
    ) -> None:
        """
        订阅消息通道

        Args:
            on_signal: 信号回调函数
            on_status: 状态回调函数
            on_command: 命令回调函数
        """
        self.pubsub = self.redis.pubsub()

        channels = []
        if on_signal:
            channels.append(self.SIGNAL_CHANNEL)
        if on_status:
            channels.append(self.STATUS_CHANNEL)
        if on_command:
            channels.append(self.COMMAND_CHANNEL)

        self.pubsub.subscribe(*channels)

        for message in self.pubsub.listen():
            if message["type"] != "message":
                continue

            data = json.loads(message["data"])
            channel = message["channel"]

            if channel == self.SIGNAL_CHANNEL and on_signal:
                on_signal(data["data"])
            elif channel == self.STATUS_CHANNEL and on_status:
                on_status(data["data"])
            elif channel == self.COMMAND_CHANNEL and on_command:
                on_command(data["data"])

    def close(self) -> None:
        """关闭连接"""
        if self.pubsub:
            self.pubsub.close()
        self.redis.close()
```

#### 5.3.4 执行层完整实现 (algvex/execution/)

**文件清单**:

```
algvex/execution/
├── __init__.py
├── manager.py           # ExecutorManager (依赖: hummingbot.strategy_v2.executors)
└── router.py            # OrderRouter (独立模块)
```

**manager.py 核心接口**:

```python
"""
执行器管理器

集成 Hummingbot 的 7 个执行器
"""
from typing import Dict, Type, Optional
from enum import Enum

# Hummingbot 执行器导入
from hummingbot.strategy_v2.executors.order_executor.order_executor import OrderExecutor
from hummingbot.strategy_v2.executors.position_executor.position_executor import PositionExecutor
from hummingbot.strategy_v2.executors.dca_executor.dca_executor import DCAExecutor
from hummingbot.strategy_v2.executors.twap_executor.twap_executor import TWAPExecutor
from hummingbot.strategy_v2.executors.grid_executor.grid_executor import GridExecutor
from hummingbot.strategy_v2.executors.arbitrage_executor.arbitrage_executor import ArbitrageExecutor
from hummingbot.strategy_v2.executors.xemm_executor.xemm_executor import XEMMExecutor


class ExecutorType(str, Enum):
    """执行器类型"""
    ORDER = "order"
    POSITION = "position"
    DCA = "dca"
    TWAP = "twap"
    GRID = "grid"
    ARBITRAGE = "arbitrage"
    XEMM = "xemm"


class ExecutorManager:
    """
    执行器管理器

    统一管理 Hummingbot 的 7 种执行器，根据信号类型自动选择合适的执行器。

    Executors:
        - OrderExecutor: 单订单执行
        - PositionExecutor: 仓位执行 (Triple Barrier)
        - DCAExecutor: 定投执行
        - TWAPExecutor: 时间加权均价
        - GridExecutor: 网格执行
        - ArbitrageExecutor: 套利执行
        - XEMMExecutor: 跨交易所做市
    """

    EXECUTOR_CLASSES: Dict[ExecutorType, Type] = {
        ExecutorType.ORDER: OrderExecutor,
        ExecutorType.POSITION: PositionExecutor,
        ExecutorType.DCA: DCAExecutor,
        ExecutorType.TWAP: TWAPExecutor,
        ExecutorType.GRID: GridExecutor,
        ExecutorType.ARBITRAGE: ArbitrageExecutor,
        ExecutorType.XEMM: XEMMExecutor,
    }

    def __init__(self, connector, default_executor: ExecutorType = ExecutorType.POSITION):
        """
        初始化管理器

        Args:
            connector: Hummingbot 连接器实例
            default_executor: 默认执行器类型
        """
        self.connector = connector
        self.default_executor = default_executor
        self._executors: Dict[str, object] = {}

    def get_executor(self, executor_type: ExecutorType = None):
        """
        获取执行器实例

        Args:
            executor_type: 执行器类型

        Returns:
            执行器实例
        """
        executor_type = executor_type or self.default_executor

        if executor_type.value not in self._executors:
            executor_class = self.EXECUTOR_CLASSES[executor_type]
            self._executors[executor_type.value] = executor_class(
                strategy=self,
                connector=self.connector,
            )

        return self._executors[executor_type.value]
```

#### 5.3.5 风控层完整实现 (algvex/risk/)

**文件清单**:

```
algvex/risk/
├── __init__.py
├── kill_switch.py       # KillSwitch (独立模块)
├── position_limit.py    # PositionLimitChecker (独立模块)
└── liquidation.py       # LiquidationMonitor (依赖: algvex.backtest.exchange)
```

**kill_switch.py 完整实现**:

```python
"""
紧急停止开关

当满足预设条件时立即停止所有交易活动
"""
from typing import Callable, Optional
from decimal import Decimal
from datetime import datetime, timedelta
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class KillSwitchReason(str, Enum):
    """触发原因"""
    MAX_LOSS = "max_loss"
    MAX_DRAWDOWN = "max_drawdown"
    POSITION_LIMIT = "position_limit"
    API_ERROR = "api_error"
    MANUAL = "manual"
    TIME_LIMIT = "time_limit"


class KillSwitch:
    """
    紧急停止开关

    监控以下条件并在触发时停止交易:
    - 最大亏损金额/比例
    - 最大回撤
    - 持仓超限
    - API 连续错误
    - 交易时间限制

    Attributes:
        is_triggered: 是否已触发
        trigger_reason: 触发原因
        trigger_time: 触发时间
    """

    def __init__(
        self,
        max_loss_pct: float = 0.1,
        max_loss_amount: Decimal = None,
        max_drawdown_pct: float = 0.15,
        max_position_value: Decimal = None,
        max_api_errors: int = 10,
        trading_hours: tuple = None,
        on_trigger: Callable[["KillSwitch", KillSwitchReason], None] = None,
    ):
        """
        初始化 Kill Switch

        Args:
            max_loss_pct: 最大亏损比例 (0.1 = 10%)
            max_loss_amount: 最大亏损金额
            max_drawdown_pct: 最大回撤比例
            max_position_value: 最大持仓价值
            max_api_errors: 最大连续 API 错误次数
            trading_hours: 允许交易时间 (start_hour, end_hour)
            on_trigger: 触发回调函数
        """
        self.max_loss_pct = Decimal(str(max_loss_pct))
        self.max_loss_amount = max_loss_amount
        self.max_drawdown_pct = Decimal(str(max_drawdown_pct))
        self.max_position_value = max_position_value
        self.max_api_errors = max_api_errors
        self.trading_hours = trading_hours
        self.on_trigger = on_trigger

        # 状态
        self.is_triggered = False
        self.trigger_reason: Optional[KillSwitchReason] = None
        self.trigger_time: Optional[datetime] = None

        # 追踪数据
        self._initial_capital: Optional[Decimal] = None
        self._peak_value: Optional[Decimal] = None
        self._api_error_count = 0

    def initialize(self, initial_capital: Decimal) -> None:
        """
        初始化资金追踪

        Args:
            initial_capital: 初始资金
        """
        self._initial_capital = initial_capital
        self._peak_value = initial_capital

    def check(
        self,
        current_value: Decimal,
        position_value: Decimal = Decimal(0),
        has_api_error: bool = False,
    ) -> bool:
        """
        检查是否应触发 Kill Switch

        Args:
            current_value: 当前账户价值
            position_value: 当前持仓价值
            has_api_error: 是否发生 API 错误

        Returns:
            bool: 是否触发
        """
        if self.is_triggered:
            return True

        # 更新峰值
        if current_value > self._peak_value:
            self._peak_value = current_value

        # 检查最大亏损
        if self._initial_capital:
            loss_pct = (self._initial_capital - current_value) / self._initial_capital
            if loss_pct > self.max_loss_pct:
                return self._trigger(KillSwitchReason.MAX_LOSS)

            if self.max_loss_amount and (self._initial_capital - current_value) > self.max_loss_amount:
                return self._trigger(KillSwitchReason.MAX_LOSS)

        # 检查最大回撤
        if self._peak_value:
            drawdown = (self._peak_value - current_value) / self._peak_value
            if drawdown > self.max_drawdown_pct:
                return self._trigger(KillSwitchReason.MAX_DRAWDOWN)

        # 检查持仓限制
        if self.max_position_value and position_value > self.max_position_value:
            return self._trigger(KillSwitchReason.POSITION_LIMIT)

        # 检查 API 错误
        if has_api_error:
            self._api_error_count += 1
            if self._api_error_count >= self.max_api_errors:
                return self._trigger(KillSwitchReason.API_ERROR)
        else:
            self._api_error_count = 0

        # 检查交易时间
        if self.trading_hours:
            current_hour = datetime.utcnow().hour
            start, end = self.trading_hours
            if not (start <= current_hour < end):
                return self._trigger(KillSwitchReason.TIME_LIMIT)

        return False

    def _trigger(self, reason: KillSwitchReason) -> bool:
        """触发 Kill Switch"""
        self.is_triggered = True
        self.trigger_reason = reason
        self.trigger_time = datetime.utcnow()

        logger.critical(f"Kill Switch 触发! 原因: {reason.value}")

        if self.on_trigger:
            self.on_trigger(self, reason)

        return True

    def reset(self) -> None:
        """重置 Kill Switch"""
        self.is_triggered = False
        self.trigger_reason = None
        self.trigger_time = None
        self._api_error_count = 0
        logger.info("Kill Switch 已重置")
```

---

## 六、实施阶段

### 阶段 1: 环境搭建

**任务清单**:

| 编号 | 任务 | 输入 | 输出 | 验收标准 |
|------|------|------|------|----------|
| 1.1 | 创建项目结构 | 无 | algvex/ 目录结构 | 目录结构完整 |
| 1.2 | 安装 Qlib | libs/qlib | pip 可用 | `import qlib` 成功 |
| 1.3 | 安装 Hummingbot | libs/hummingbot | pip 可用 | `import hummingbot` 成功 |
| 1.4 | 编写 requirements.txt | 无 | requirements.txt | 所有依赖可安装 |
| 1.5 | 编写 install.sh | 无 | scripts/install.sh | 一键安装成功 |

**install.sh 脚本**:

```bash
#!/bin/bash
set -euo pipefail

echo "=== AlgVex 安装脚本 ==="

# 1. 检查 Python 版本
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python 版本: $python_version"

# 2. 创建虚拟环境
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "虚拟环境已创建"
fi
source venv/bin/activate

# 3. 升级 pip
pip install --upgrade pip

# 4. 安装 Qlib
echo "安装 Qlib..."
pip install -e libs/qlib

# 5. 安装 Hummingbot
echo "安装 Hummingbot..."
pip install -e libs/hummingbot

# 6. 安装其他依赖
echo "安装其他依赖..."
pip install -r requirements.txt

# 7. 安装 algvex
pip install -e .

echo "=== 安装完成 ==="
```

### 阶段 2: 数据层开发

**任务清单**:

| 编号 | 任务 | 输入 | 输出 | 验收标准 |
|------|------|------|------|----------|
| 2.1 | 实现 CryptoCalendarProvider | Qlib CalendarProvider | calendar.py | 生成 24/7 时间戳 |
| 2.2 | 实现 CryptoInstrumentProvider | Qlib InstrumentProvider | instrument.py | 返回加密货币列表 |
| 2.3 | 实现 BinancePerpetualCollector | Qlib CryptoCollector | collector.py | 收集 1h 数据成功 |
| 2.4 | 实现数据转换器 | Hummingbot Candles | converter.py | 转换格式正确 |
| 2.5 | 实现 CryptoDataHandler | Qlib Alpha158 | handler.py | 因子计算正确 |
| 2.6 | 编写数据下载脚本 | 无 | download_data.py | 可下载历史数据 |

**测试用例**:

```python
def test_calendar_provider():
    """测试日历提供者"""
    provider = CryptoCalendarProvider()
    cal = provider.calendar("2024-01-01", "2024-01-02", freq="1h")
    assert len(cal) == 24  # 24 小时

def test_data_collector():
    """测试数据收集器"""
    collector = BinancePerpetualCollector(["BTC-USDT"], interval="1h")
    df = collector.collect("2024-01-01", "2024-01-07")
    assert len(df) > 0
    assert "open" in df.columns
    assert "close" in df.columns
```

### 阶段 3: 因子层开发

**任务清单**:

| 编号 | 任务 | 输入 | 输出 | 验收标准 |
|------|------|------|------|----------|
| 3.1 | 实现 CryptoAlpha158 | Qlib Alpha158 | alpha158.py | 158 因子计算正确 |
| 3.2 | 实现 CryptoAlpha360 | Qlib Alpha360 | alpha360.py | 360 因子计算正确 |
| 3.3 | 验证 52 个操作符 | Qlib ops | 测试报告 | 所有操作符可用 |
| 3.4 | 实现自定义因子 | 无 | custom.py | 资金费率因子等 |

**CryptoAlpha158 窗口适配**:

> **设计原则**: 加密货币市场节奏比传统股市更快，因此采用**时间压缩**策略。
> 原始 Alpha158 使用 5/10/20/30/60 天窗口，这里压缩为 1/2/5/7/14 天对应的小时数。
> 如需保持原始等价性，可使用 `windows = [w * 24 for w in [5, 10, 20, 30, 60]]`。

| 原始窗口 (日线) | 适配窗口 (小时线) | 等价天数 | 压缩比 |
|----------------|-------------------|----------|--------|
| 5 days | 24 hours | 1 天 | 5:1 |
| 10 days | 48 hours | 2 天 | 5:1 |
| 20 days | 120 hours | 5 天 | 4:1 |
| 30 days | 168 hours | 7 天 | 4.3:1 |
| 60 days | 336 hours | 14 天 | 4.3:1 |

```python
# algvex/factors/alpha158.py 配置选项
WINDOW_MODE = "compressed"  # "compressed" 或 "equivalent"

COMPRESSED_WINDOWS = [24, 48, 120, 168, 336]  # 压缩模式 (默认)
EQUIVALENT_WINDOWS = [120, 240, 480, 720, 1440]  # 等价模式 (5*24, 10*24, ...)
```

### 阶段 4: 回测层开发

**任务清单**:

| 编号 | 任务 | 输入 | 输出 | 验收标准 |
|------|------|------|------|----------|
| 4.1 | 实现 CryptoExchange | Qlib Exchange | exchange.py | 支持杠杆/做空 |
| 4.2 | 实现 PerpetualPosition | Qlib Position | position.py | 仓位计算正确 |
| 4.3 | 实现资金费率计算 | 无 | funding.py | 费率计算正确 |
| 4.4 | 实现 CryptoExecutor | Qlib Executor | executor.py | 执行逻辑正确 |
| 4.5 | 集成 NestedExecutor | Qlib NestedExecutor | 测试 | 多层执行正确 |

**永续合约规则**:

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 杠杆 | 10x | 1-125 可配置 |
| 保证金模式 | 全仓 | cross/isolated |
| 持仓模式 | 单向 | one_way/hedge |
| 资金费率结算 | 8小时 | 每 8 小时 |
| 手续费 | 0.02%/0.04% | Maker/Taker |

### 阶段 5: 模型验证

**任务清单**:

| 编号 | 任务 | 输入 | 输出 | 验收标准 |
|------|------|------|------|----------|
| 5.1 | 验证传统 ML 模型 (5) | 训练数据 | 测试报告 | IC > 0.02 |
| 5.2 | 验证 RNN 模型 (12) | 训练数据 | 测试报告 | IC > 0.02 |
| 5.3 | 验证 Transformer 模型 (4) | 训练数据 | 测试报告 | IC > 0.02 |
| 5.4 | 验证 CNN 模型 (3) | 训练数据 | 测试报告 | IC > 0.02 |
| 5.5 | 验证高级模型 (8) | 训练数据 | 测试报告 | IC > 0.02 |
| 5.6 | 模型对比报告 | 所有结果 | 报告文档 | 选出最优模型 |

**模型验证流程**:

```
数据准备 -> 训练集/验证集/测试集划分 -> 模型训练 -> 预测 -> 评估指标
                                                              |
                                                              v
                                                    IC, ICIR, 年化收益, 最大回撤
```

### 阶段 6: 信号桥开发

**任务清单**:

| 编号 | 任务 | 输入 | 输出 | 验收标准 |
|------|------|------|------|----------|
| 6.1 | 实现信号转换器 | Qlib 预测 | converter.py | 转换正确 |
| 6.2 | 实现 Redis 通道 | 无 | redis_channel.py | 消息收发成功 |
| 6.3 | 实现 MQTT 通道 | Hummingbot MQTT | mqtt_channel.py | 消息收发成功 |
| 6.4 | 集成 Hummingbot 执行器 | 7 个执行器 | manager.py | 全部可用 |

**信号格式**:

```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "signals": [
    {"symbol": "BTC-USDT", "side": "BUY", "score": 0.85, "amount": 0.1},
    {"symbol": "ETH-USDT", "side": "SELL", "score": -0.72, "amount": 0.5}
  ]
}
```

### 阶段 7: 风控开发

**任务清单**:

| 编号 | 任务 | 输入 | 输出 | 验收标准 |
|------|------|------|------|----------|
| 7.1 | 实现 Kill Switch | Hummingbot KillSwitch | kill_switch.py | 触发停止正确 |
| 7.2 | 实现仓位限制 | 无 | position_limit.py | 限制生效 |
| 7.3 | 实现强平监控 | 无 | liquidation.py | 预警正确 |
| 7.4 | 集成 Triple Barrier | Hummingbot | 测试 | 止盈止损正确 |

### 阶段 8: 工作流开发

**任务清单**:

| 编号 | 任务 | 输入 | 输出 | 验收标准 |
|------|------|------|------|----------|
| 8.1 | 实现训练管理器 | Qlib Trainer | trainer.py | 训练流程正确 |
| 8.2 | 实现滚动训练 | Qlib RollingGen | rolling.py | 滚动更新正确 |
| 8.3 | 实现在线服务 | Qlib OnlineManager | online.py | 增量预测正确 |
| 8.4 | 集成 MLflow | 无 | 配置 | 实验跟踪可用 |

### 阶段 9: 用户接口开发

**任务清单**:

| 编号 | 任务 | 输入 | 输出 | 验收标准 |
|------|------|------|------|----------|
| 9.1 | 实现 CLI | 无 | cli/main.py | 命令可用 |
| 9.2 | 实现 Dashboard | Streamlit | dashboard/app.py | 界面可用 |
| 9.3 | 编写启动脚本 | 无 | start.sh | 一键启动 |
| 9.4 | 编写停止脚本 | 无 | stop.sh | 一键停止 |

**CLI 命令**:

```bash
# 数据命令
algvex data download --symbols BTC-USDT,ETH-USDT --start 2024-01-01 --end 2024-12-01

# 训练命令
algvex train --model LGBModel --config config/strategies/default.yaml

# 回测命令
algvex backtest --model ./models/lgb_model.pkl --start 2024-06-01 --end 2024-12-01

# 交易命令
algvex trade --mode paper --exchange binance_perpetual
algvex trade --mode live --exchange binance_perpetual
```

---

## 七、本地测试方案

### 7.1 测试环境

| 项目 | 要求 |
|------|------|
| 操作系统 | Ubuntu 22.04 / macOS / Windows WSL2 |
| Python | 3.10 |
| 内存 | >= 16GB |
| 磁盘 | >= 50GB |

### 7.2 测试流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        本地测试流程                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. 环境验证                                                     │
│     └── python --version                                         │
│     └── pip list (检查依赖)                                      │
│                                                                  │
│  2. 单元测试                                                     │
│     └── pytest tests/unit/ -v --cov=algvex                      │
│                                                                  │
│  3. 数据测试                                                     │
│     └── python scripts/download_data.py --test                  │
│     └── 验证数据格式和完整性                                     │
│                                                                  │
│  4. 因子测试                                                     │
│     └── 计算 Alpha158 因子                                       │
│     └── 验证因子值范围                                           │
│                                                                  │
│  5. 模型测试                                                     │
│     └── 使用小数据集快速训练                                     │
│     └── 验证模型输出格式                                         │
│                                                                  │
│  6. 回测测试                                                     │
│     └── 运行短期回测 (7天)                                       │
│     └── 验证收益/指标计算                                        │
│                                                                  │
│  7. Paper Trading 测试                                           │
│     └── 启动模拟交易                                             │
│     └── 验证订单执行                                             │
│     └── 运行 24 小时                                             │
│                                                                  │
│  8. 集成测试                                                     │
│     └── pytest tests/integration/ -v                            │
│     └── 端到端流程验证                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 测试命令

```bash
# 1. 运行所有单元测试
pytest tests/unit/ -v --cov=algvex --cov-report=html

# 2. 运行特定模块测试
pytest tests/unit/test_data.py -v
pytest tests/unit/test_factors.py -v
pytest tests/unit/test_backtest.py -v

# 3. 运行集成测试
pytest tests/integration/ -v

# 4. 运行 Paper Trading 测试
python -m algvex.cli trade --mode paper --exchange binance_perpetual --duration 24h

# 5. 生成测试报告
pytest --html=reports/test_report.html --self-contained-html
```

### 7.4 测试检查清单

| 检查项 | 通过标准 |
|--------|----------|
| 单元测试通过率 | 100% |
| 代码覆盖率 | > 80% |
| 数据收集 | BTC-USDT 1小时数据可收集 |
| 因子计算 | 158 因子全部计算成功 |
| 模型训练 | LGBModel 训练成功 |
| 回测运行 | 无错误完成 |
| Paper Trading | 24小时无错误 |
| 集成测试 | 全部通过 |

---

## 八、服务器部署方案

### 8.1 服务器要求

| 项目 | 最低配置 | 推荐配置 |
|------|----------|----------|
| 操作系统 | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |
| CPU | 4 核 | 8 核 |
| 内存 | 16 GB | 32 GB |
| 磁盘 | 100 GB SSD | 500 GB SSD |
| 网络 | 100 Mbps | 1 Gbps |
| Python | 3.10 | 3.10 |

### 8.2 部署步骤

#### 步骤 1: 系统准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础工具
sudo apt install -y git curl wget vim htop

# 安装 Python 3.10
sudo apt install -y python3.10 python3.10-venv python3.10-dev python3-pip

# 安装构建工具
sudo apt install -y build-essential libssl-dev libffi-dev

# 安装 Redis (信号桥)
sudo apt install -y redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

#### 步骤 2: 项目部署

```bash
# 创建部署目录
sudo mkdir -p /opt/algvex
sudo chown $USER:$USER /opt/algvex
cd /opt/algvex

# 克隆代码
git clone --recursive https://github.com/FelixWayne0318/AlgVex.git .

# 运行安装脚本
chmod +x scripts/install.sh
./scripts/install.sh
```

#### 步骤 3: 配置文件

```yaml
# /opt/algvex/config/settings.yaml
environment: production

# 数据配置
data:
  provider_uri: /opt/algvex/data/qlib_data
  cache_dir: /opt/algvex/cache

# 交易所配置
exchange:
  name: binance_perpetual
  leverage: 10
  margin_mode: cross

# Redis 配置
redis:
  host: localhost
  port: 6379
  db: 0

# 日志配置 (使用 Qlib/Hummingbot 内置)
logging:
  level: INFO
  dir: /opt/algvex/logs
```

#### 步骤 4: Systemd 服务

```ini
# /etc/systemd/system/algvex.service
[Unit]
Description=AlgVex Trading Service
After=network.target redis-server.service

[Service]
Type=simple
User=algvex
WorkingDirectory=/opt/algvex
ExecStart=/opt/algvex/venv/bin/python -m algvex.cli trade --mode live
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# 启用服务
sudo systemctl daemon-reload
sudo systemctl enable algvex
sudo systemctl start algvex
```

### 8.3 一键部署脚本

```bash
#!/bin/bash
# scripts/deploy.sh
set -euo pipefail

echo "=== AlgVex 服务器部署脚本 ==="

# 变量
DEPLOY_DIR="/opt/algvex"
SERVICE_USER="algvex"

# 1. 创建用户
if ! id "$SERVICE_USER" &>/dev/null; then
    sudo useradd -r -s /bin/false $SERVICE_USER
    echo "用户 $SERVICE_USER 已创建"
fi

# 2. 创建目录
sudo mkdir -p $DEPLOY_DIR
sudo chown $SERVICE_USER:$SERVICE_USER $DEPLOY_DIR

# 3. 安装系统依赖
sudo apt update
sudo apt install -y python3.10 python3.10-venv python3-pip redis-server git

# 4. 克隆代码
cd $DEPLOY_DIR
if [ ! -d ".git" ]; then
    sudo -u $SERVICE_USER git clone --recursive https://github.com/FelixWayne0318/AlgVex.git .
fi

# 5. 运行安装
sudo -u $SERVICE_USER bash scripts/install.sh

# 6. 复制配置
if [ ! -f "config/settings.yaml" ]; then
    sudo -u $SERVICE_USER cp config/settings.yaml.example config/settings.yaml
    echo "请编辑 config/settings.yaml 配置交易所 API 密钥"
fi

# 7. 设置 Systemd 服务
sudo cp scripts/algvex.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable algvex

echo "=== 部署完成 ==="
echo "启动服务: sudo systemctl start algvex"
echo "查看日志: sudo journalctl -u algvex -f"
```

### 8.4 运维命令

```bash
# 启动服务
sudo systemctl start algvex

# 停止服务
sudo systemctl stop algvex

# 重启服务
sudo systemctl restart algvex

# 查看状态
sudo systemctl status algvex

# 查看日志
sudo journalctl -u algvex -f

# 查看 Hummingbot 日志
tail -f /opt/algvex/logs/hummingbot.log

# 查看 Qlib 日志
tail -f /opt/algvex/logs/qlib.log
```

---

## 九、验收标准

### 9.1 功能验收

| 模块 | 验收标准 |
|------|----------|
| 数据层 | 成功收集 BTC-USDT 1小时数据 >= 1年 |
| 因子层 | Alpha158 全部 158 因子计算正确 |
| 模型层 | 32 个模型全部可训练 |
| 回测层 | 回测 IC > 0.02, 无计算错误 |
| 信号桥 | Qlib 信号成功传递到 Hummingbot |
| 执行层 | 7 个执行器全部可用 |
| 风控层 | Kill Switch 正确触发 |
| Paper Trading | 24 小时无错误运行 |

### 9.2 性能验收

| 指标 | 标准 |
|------|------|
| 数据收集速度 | >= 1000 条/秒 |
| 因子计算速度 | 1 年数据 < 5 分钟 |
| 模型推理延迟 | < 100ms |
| 订单执行延迟 | < 500ms |
| 系统内存占用 | < 8GB |

### 9.3 稳定性验收

| 指标 | 标准 |
|------|------|
| Paper Trading | 连续 7 天无错误 |
| 服务可用性 | > 99.9% |
| 自动重启 | 异常后 30 秒内恢复 |

---

## 十、交付物清单

| 交付物 | 说明 | 状态 |
|--------|------|------|
| 源代码 | algvex/ 完整代码 | 待开发 |
| 配置文件 | config/ 目录 | 待开发 |
| 安装脚本 | scripts/install.sh | 待开发 |
| 部署脚本 | scripts/deploy.sh | 待开发 |
| 启动/停止脚本 | scripts/start.sh, stop.sh | 待开发 |
| Systemd 服务文件 | scripts/algvex.service | 待开发 |
| 单元测试 | tests/unit/ | 待开发 |
| 集成测试 | tests/integration/ | 待开发 |
| 本文档 | EXECUTION-PLAN.md | ✅ 完成 |

---

## 附录 A: 参考资源

### Qlib 官方资源

| 资源 | 链接 |
|------|------|
| GitHub | https://github.com/microsoft/qlib |
| 文档 | https://qlib.readthedocs.io/ |
| 表达式操作符 | https://github.com/microsoft/qlib/blob/main/qlib/data/ops.py |
| 任务管理 | https://qlib.readthedocs.io/en/latest/advanced/task_management.html |
| 在线服务 | https://qlib.readthedocs.io/en/latest/component/online.html |
| 嵌套执行 | https://qlib.readthedocs.io/en/latest/component/highfreq.html |

### Hummingbot 官方资源

| 资源 | 链接 |
|------|------|
| GitHub | https://github.com/hummingbot/hummingbot |
| 文档 | https://hummingbot.org |
| Dashboard | https://github.com/hummingbot/dashboard |
| 连接器 | https://hummingbot.org/exchanges/ |
| Strategy V2 | https://hummingbot.org/v2-strategies/ |
| API 参考 | https://hummingbot.org/hummingbot-api/ |

### 本地源码路径

```
libs/
├── qlib/                              # Qlib v0.9.7
│   ├── qlib/
│   │   ├── contrib/
│   │   │   ├── model/                 # 32 个模型
│   │   │   ├── data/                  # Alpha158, Alpha360
│   │   │   ├── strategy/              # 策略
│   │   │   ├── ops/                   # 高频操作符
│   │   │   └── tuner/                 # 超参数调优
│   │   ├── data/
│   │   │   └── ops.py                 # 52 个操作符
│   │   ├── backtest/                  # 回测框架
│   │   ├── workflow/                  # 工作流
│   │   └── model/
│   │       ├── riskmodel/             # 风险模型
│   │       └── ens/                   # 集成学习
│   └── scripts/
│       └── data_collector/crypto/     # 已有 Crypto 收集器
│
└── hummingbot/                        # Hummingbot v2.11.0
    └── hummingbot/
        ├── connector/
        │   ├── derivative/            # 11 永续连接器
        │   └── exchange/              # 26 现货连接器
        ├── strategy/                  # 9 V1 策略
        ├── strategy_v2/
        │   ├── executors/             # 7 执行器
        │   ├── controllers/           # V2 控制器
        │   └── backtesting/           # 回测引擎
        ├── data_feed/
        │   └── candles_feed/          # 21+ K线数据源
        └── remote_iface/
            └── mqtt.py                # MQTT 消息
```

---

**文档版本**: 3.0 (合并技术方案)
**创建日期**: 2025-12-31
**更新日期**: 2025-12-31
**更新历史**:
- v3.0: 合并 TECHNICAL-PROPOSAL.md，添加适配策略标记、源码路径、参考资源附录
- v2.1: 修复模型计数错误 (31→32), 修正 VWAPExecutor 描述, 补充 Alpha158 窗口适配说明, 添加 5.3 节详细实现规范
- v2.0: 重写执行方案结构
- v1.0: 初始版本
