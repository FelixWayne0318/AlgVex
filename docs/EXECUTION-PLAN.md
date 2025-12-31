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
│  │  │  │ 31 个模型     │  │       │  │ 37 个连接器   │  │        │ │
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

### 3.1 Qlib 功能清单 (libs/qlib v0.9.7)

#### 3.1.1 模型 (31个)

| 类别 | 模型 | 文件 |
|------|------|------|
| 传统ML (5) | LinearModel, LGBModel, HFLGBModel, XGBModel, CatBoostModel | linear.py, gbdt.py, highfreq_gdbt_model.py, xgboost.py, catboost_model.py |
| RNN (12) | LSTM, LSTM_ts, GRU, GRU_ts, ALSTM, ALSTM_ts, GATs, GATs_ts, KRNN, SFM, ADARNN, Sandwich | pytorch_*.py |
| Transformer (4) | TransformerModel, TransformerModel_ts, LocalformerModel, LocalformerModel_ts | pytorch_transformer*.py, pytorch_localformer*.py |
| CNN (4) | TCN, TCN_ts, TemporalConvNet, TCTS | pytorch_tcn*.py, tcn.py, pytorch_tcts.py |
| 高级 (6) | DNNModelPytorch, GeneralPTNN, TabnetModel, TRAModel, DEnsembleModel, IGMTF, HIST, ADD | pytorch_nn.py, pytorch_general_nn.py, etc. |

#### 3.1.2 操作符 (52个)

| 类别 | 操作符 |
|------|--------|
| 统计 (14) | Sum, Mean, Std, Var, Skew, Kurt, Med, Mad, Slope, Rsquare, Resi, Rank, Quantile, Count |
| 极值 (4) | Max, Min, IdxMax, IdxMin |
| 技术 (6) | EMA, WMA, Corr, Cov, Delta, Ref |
| 数学 (8) | Abs, Sign, Log, Power, Add, Sub, Mul, Div |
| 逻辑 (13) | Greater, Less, Gt, Ge, Lt, Le, Eq, Ne, And, Or, Not, If, Mask |
| 高频 (4) | DayCumsum, DayLast, get_calendar_day, get_calendar_minute |
| 其他 (3) | ChangeInstrument, TResample, NpElemOperator |

#### 3.1.3 其他模块

| 模块 | 组件 |
|------|------|
| 数据处理器 | DropnaProcessor, TanhProcess, ZscoreNorm, CSRankNorm 等 10+ |
| 策略 | BaseSignalStrategy, SBBStrategyEMA, SoftTopkStrategy, EnhancedIndexingOptimizer |
| 回测 | SimulatorExecutor, NestedExecutor, VWAPExecutor |
| 风险模型 | POETCovEstimator, ShrinkCovEstimator, StructuredCovEstimator |
| 集成学习 | RollingEnsemble, AverageEnsemble, RollingGroup |
| 调优器 | Tuner, TunerPipeline, SearchSpace |
| 在线服务 | OnlineManager, RollingGen, PredUpdater |
| 任务管理 | TaskManager, Trainer, TrainerR, Collector |

#### 3.1.4 RL 模块 (可选)

| 组件 | 说明 | 状态 |
|------|------|------|
| order_execution | 订单执行 RL | 可选，后期添加 |
| Tianshou 集成 | RL 框架 | 可选，后期添加 |

### 3.2 Hummingbot 功能清单 (libs/hummingbot v2.11.0)

#### 3.2.1 连接器 (37个)

**永续合约 (11)**:
| 连接器 | 优先级 |
|--------|--------|
| binance_perpetual | ✅ 首选 |
| bybit_perpetual | 高 |
| okx_perpetual | 高 |
| gate_io_perpetual | 中 |
| kucoin_perpetual | 中 |
| bitget_perpetual | 中 |
| bitmart_perpetual | 低 |
| derive_perpetual | 低 |
| dydx_v4_perpetual | 低 |
| hyperliquid_perpetual | 低 |
| injective_v2_perpetual | 低 |

**现货 (26)**: binance, bybit, okx, kucoin, gate_io, htx, mexc, bitget, kraken, coinbase_advanced_trade, bitstamp, bitmart, bitrue, bing_x, ascend_ex, btc_markets, cube, derive, dexalot, foxbit, hyperliquid, injective_v2, ndax, vertex, xrpl, paper_trade

#### 3.2.2 执行器 (7个)

| 执行器 | 说明 |
|--------|------|
| OrderExecutor | 单订单执行 |
| PositionExecutor | 仓位执行 (Triple Barrier) |
| DCAExecutor | 定投执行 |
| TWAPExecutor | 时间加权均价 |
| GridExecutor | 网格执行 |
| ArbitrageExecutor | 两腿套利 |
| XEMMExecutor | 跨交易所做市 |

#### 3.2.3 V1 策略 (9个)

| 策略 | 说明 |
|------|------|
| pure_market_making | 基础做市 |
| avellaneda_market_making | Avellaneda-Stoikov 做市 |
| cross_exchange_market_making | 跨交易所做市 |
| cross_exchange_mining | 流动性挖矿做市 |
| perpetual_market_making | 永续合约做市 |
| amm_arb | AMM-CEX 套利 |
| spot_perpetual_arbitrage | 现货-永续套利 |
| liquidity_mining | 流动性挖矿 |
| hedge | 风险对冲 |

#### 3.2.4 V2 控制器

| 控制器 | 说明 |
|--------|------|
| DirectionalTradingControllerBase | 方向性交易基类 |
| MarketMakingControllerBase | 做市基类 |
| ControllerBase | 控制器基类 |

#### 3.2.5 数据源 (21+ K线源)

binance_perpetual_candles, binance_spot_candles, bybit_perpetual_candles, okx_perpetual_candles, gate_io_perpetual_candles, kucoin_perpetual_candles, 等

#### 3.2.6 风控功能

| 功能 | 说明 |
|------|------|
| Triple Barrier | 止盈/止损/时间限制 |
| Trailing Stop | 追踪止损 |
| Kill Switch | 紧急停止 |
| Balance Limit | 资产限额 |
| Position Limit | 持仓限制 |
| Rate Limiter | API 限速 |

#### 3.2.7 其他模块

| 模块 | 说明 |
|------|------|
| MQTT | 消息推送 |
| Paper Trading | 模拟交易 |
| Backtesting Engine | 回测引擎 |
| 日志系统 | Hummingbot 内置 |

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

| 原始窗口 (日线) | 适配窗口 (小时线) | 说明 |
|----------------|-------------------|------|
| 5 | 24 | 1 天 |
| 10 | 48 | 2 天 |
| 20 | 120 | 5 天 |
| 30 | 168 | 7 天 |
| 60 | 336 | 14 天 |

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
| 5.4 | 验证 CNN 模型 (4) | 训练数据 | 测试报告 | IC > 0.02 |
| 5.5 | 验证高级模型 (6) | 训练数据 | 测试报告 | IC > 0.02 |
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
| 模型层 | 31 个模型全部可训练 |
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
| 技术方案 | TECHNICAL-PROPOSAL.md | ✅ 完成 |

---

**文档版本**: 2.0
**创建日期**: 2025-12-31
**更新日期**: 2025-12-31
