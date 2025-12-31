# AlgVex 完整执行方案

> **版本**: 1.0
> **基于**: libs/qlib v0.9.7 + libs/hummingbot v2.11.0 完整代码审计
> **日期**: 2025-12-31

---

## 一、技术方案遗漏补充

基于对 `libs/qlib` 和 `libs/hummingbot` 的完整代码审计，发现以下遗漏内容需要补充：

### 1.1 Qlib 遗漏模块

#### 1.1.1 高频操作符 (qlib/contrib/ops/high_freq.py)

| 操作符 | 说明 | 适配策略 |
|--------|------|----------|
| **DayCumsum** | 日内累计求和 | 🟢 适配小时级 |
| **DayLast** | 日内最后一个值 | 🟢 适配小时级 |
| **get_calendar_day** | 高频日历日期加载 | 🔴 需适配 24/7 |
| **get_calendar_minute** | 高频日历分钟加载 | 🔴 需适配 24/7 |

#### 1.1.2 风险模型 (qlib/model/riskmodel/)

| 模型 | 文件 | 说明 | 适配策略 |
|------|------|------|----------|
| **RiskModel (Base)** | base.py | 风险模型基类 | 🟢 无需修改 |
| **POETCovEstimator** | poet.py | POET 协方差估计 | 🟢 无需修改 |
| **ShrinkCovEstimator** | shrink.py | 收缩协方差估计 | 🟢 无需修改 |
| **StructuredCovEstimator** | structured.py | 结构化协方差估计 | 🟢 无需修改 |

**应用场景**: 组合优化、风险平价策略

#### 1.1.3 集成学习 (qlib/model/ens/)

| 组件 | 说明 | 适配策略 |
|------|------|----------|
| **RollingEnsemble** | 滚动集成 | 🟢 无需修改 |
| **AverageEnsemble** | 平均集成 | 🟢 无需修改 |
| **RollingGroup** | 滚动分组 | 🟢 无需修改 |

#### 1.1.4 超参数调优器 (qlib/contrib/tuner/)

| 组件 | 文件 | 说明 | 适配策略 |
|------|------|------|----------|
| **Tuner** | tuner.py | 超参数搜索 | 🟢 无需修改 |
| **TunerPipeline** | pipeline.py | 调优流水线 | 🟢 无需修改 |
| **SearchSpace** | space.py | 搜索空间定义 | 🟢 无需修改 |
| **TunerConfig** | config.py | 调优配置 | 🟢 无需修改 |

#### 1.1.5 组合优化策略 (qlib/contrib/strategy/optimizer/)

| 策略 | 说明 | 适配策略 |
|------|------|----------|
| **EnhancedIndexingOptimizer** | 增强指数策略 | 🟡 需适配加密货币 |
| **MeanVarianceOptimizer** | 均值方差优化 | 🟢 无需修改 |
| **RiskParityOptimizer** | 风险平价优化 | 🟢 无需修改 |

#### 1.1.6 已有 Crypto 数据收集器

**重要发现**: Qlib 已经有 `scripts/data_collector/crypto/` 目录！

```python
# 位置: libs/qlib/scripts/data_collector/crypto/collector.py
# 使用: CoinGecko API
# 功能: 加密货币历史数据收集

class CryptoCollector(BaseCollector):
    """
    支持:
    - interval: 1d (日线)
    - 数据源: CoinGecko API
    - 输出: Qlib 标准格式
    """
```

**适配建议**:
- 扩展支持 1h 间隔
- 添加 Binance API 数据源
- 支持永续合约数据

### 1.2 Hummingbot 遗漏模块

#### 1.2.1 Candles Feed (data_feed/candles_feed/)

**21+ 交易所 K线数据源**:

| 数据源 | 类型 | 状态 |
|--------|------|------|
| binance_perpetual_candles | 永续 | ✅ 直接使用 |
| binance_spot_candles | 现货 | ✅ 直接使用 |
| bybit_perpetual_candles | 永续 | ✅ 直接使用 |
| bybit_spot_candles | 现货 | ✅ 直接使用 |
| okx_perpetual_candles | 永续 | ✅ 直接使用 |
| okx_spot_candles | 现货 | ✅ 直接使用 |
| gate_io_perpetual_candles | 永续 | ✅ 直接使用 |
| gate_io_spot_candles | 现货 | ✅ 直接使用 |
| kucoin_perpetual_candles | 永续 | ✅ 直接使用 |
| kucoin_spot_candles | 现货 | ✅ 直接使用 |
| bitget_perpetual_candles | 永续 | ✅ 直接使用 |
| bitget_spot_candles | 现货 | ✅ 直接使用 |
| hyperliquid_perpetual_candles | 永续 DEX | ✅ 直接使用 |
| hyperliquid_spot_candles | 现货 DEX | ✅ 直接使用 |
| mexc_perpetual_candles | 永续 | ✅ 直接使用 |
| mexc_spot_candles | 现货 | ✅ 直接使用 |
| kraken_spot_candles | 现货 | ✅ 直接使用 |
| ascend_ex_spot_candles | 现货 | ✅ 直接使用 |
| btc_markets_spot_candles | 现货 | ✅ 直接使用 |
| dexalot_spot_candles | 现货 DEX | ✅ 直接使用 |
| bitmart_perpetual_candles | 永续 | ✅ 直接使用 |

#### 1.2.2 其他数据源 (data_feed/)

| 数据源 | 文件 | 说明 |
|--------|------|------|
| **CoinGecko** | coin_gecko_data_feed/ | 价格数据 |
| **CoinCap** | coin_cap_data_feed/ | 市值数据 |
| **AMM Gateway** | amm_gateway_data_feed.py | DEX 数据 |
| **Custom API** | custom_api_data_feed.py | 自定义 API |
| **Liquidations** | liquidations_feed/ | 清算数据 |
| **Wallet Tracker** | wallet_tracker_data_feed.py | 钱包跟踪 |
| **Market Data Provider** | market_data_provider.py | 统一数据接口 |

#### 1.2.3 策略脚本示例 (scripts/)

**30+ 社区策略脚本**:

| 类别 | 脚本 | 说明 |
|------|------|------|
| **套利** | triangular_arbitrage.py | 三角套利 |
| **套利** | spot_perp_arb.py | 现货-永续套利 |
| **套利** | simple_arbitrage_example.py | 简单套利示例 |
| **方向性** | directional_strategy_macd_bb.py | MACD+布林带 |
| **方向性** | directional_strategy_rsi_spot.py | RSI 现货策略 |
| **方向性** | directional_strategy_trend_follower.py | 趋势跟踪 |
| **方向性** | directional_strategy_bb_rsi_multi_timeframe.py | 多时间框架 |
| **做市** | simple_pmm.py | 简单 PMM |
| **做市** | simple_pmm_no_config.py | 无配置 PMM |
| **做市** | pmm_with_shifted_mid_dynamic_spreads.py | 动态价差 PMM |
| **网格** | fixed_grid.py | 固定网格 |
| **执行** | simple_vwap.py | VWAP 执行 |
| **执行** | simple_xemm.py | 跨交易所做市 |
| **DCA** | buy_dip_example.py | 逢低买入 |
| **组合** | 1overN_portfolio.py | 等权组合 |
| **组合** | buy_low_sell_high.py | 低买高卖 |

#### 1.2.4 回测引擎 (strategy_v2/backtesting/)

| 组件 | 文件 | 说明 |
|------|------|------|
| **BacktestingEngineBase** | backtesting_engine_base.py | 回测引擎基类 |
| **BacktestingDataProvider** | backtesting_data_provider.py | 回测数据提供者 |
| **ExecutorSimulatorBase** | executor_simulator_base.py | 执行器模拟基类 |
| **PositionExecutorSimulator** | executors_simulator/ | 仓位执行模拟 |

---

## 二、完整文件结构设计

```
algvex/
├── __init__.py
├── config/                          # 配置管理
│   ├── __init__.py
│   ├── base.py                      # 配置基类
│   ├── qlib_config.py               # Qlib 初始化配置
│   ├── hummingbot_config.py         # Hummingbot 配置
│   └── crypto_config.py             # 加密货币专用配置
│
├── data/                            # 数据层适配
│   ├── __init__.py
│   ├── providers/                   # 数据提供者
│   │   ├── __init__.py
│   │   ├── calendar.py              # CryptoCalendarProvider (24/7)
│   │   ├── instrument.py            # CryptoInstrumentProvider
│   │   └── feature.py               # CryptoFeatureProvider
│   ├── collectors/                  # 数据收集器
│   │   ├── __init__.py
│   │   ├── binance_collector.py     # 币安数据收集 (扩展 Qlib crypto)
│   │   ├── ccxt_collector.py        # CCXT 通用收集器
│   │   └── hummingbot_candles.py    # Hummingbot K线数据桥接
│   ├── handlers/                    # 数据处理器
│   │   ├── __init__.py
│   │   ├── crypto_handler.py        # CryptoDataHandler (继承 Alpha158Handler)
│   │   └── highfreq_handler.py      # 高频数据处理器
│   └── scripts/                     # 数据脚本
│       ├── dump_crypto.py           # 数据转换为 Qlib 格式
│       └── download_crypto.py       # 下载加密货币数据
│
├── factors/                         # 因子计算
│   ├── __init__.py
│   ├── alpha158_crypto.py           # CryptoAlpha158 (适配版)
│   ├── alpha360_crypto.py           # CryptoAlpha360 (适配版)
│   ├── highfreq_ops.py              # 高频操作符适配
│   └── custom_factors.py            # 自定义加密货币因子
│
├── models/                          # 模型适配层
│   ├── __init__.py
│   ├── base.py                      # 模型基类包装
│   ├── ensemble.py                  # 集成模型包装
│   ├── riskmodel.py                 # 风险模型包装
│   └── tuner.py                     # 超参数调优包装
│
├── backtest/                        # 回测适配层
│   ├── __init__.py
│   ├── exchange/                    # 交易所模拟
│   │   ├── __init__.py
│   │   ├── crypto_exchange.py       # CryptoExchange (继承 Exchange)
│   │   └── perpetual_rules.py       # 永续合约规则
│   ├── executor/                    # 执行器
│   │   ├── __init__.py
│   │   ├── nested_executor.py       # 嵌套执行器适配
│   │   └── crypto_executor.py       # 加密货币执行器
│   ├── position/                    # 仓位管理
│   │   ├── __init__.py
│   │   ├── perpetual_position.py    # 永续合约仓位
│   │   └── funding_rate.py          # 资金费率计算
│   └── report/                      # 回测报告
│       ├── __init__.py
│       └── crypto_report.py         # 加密货币报告适配
│
├── strategy/                        # 策略层
│   ├── __init__.py
│   ├── qlib_strategies/             # Qlib 策略包装
│   │   ├── __init__.py
│   │   ├── signal_strategy.py       # 信号策略适配
│   │   ├── optimizer_strategy.py    # 组合优化策略
│   │   └── cost_control.py          # 成本控制适配
│   └── hummingbot_strategies/       # Hummingbot 策略包装
│       ├── __init__.py
│       ├── pmm_wrapper.py           # PMM 策略包装
│       ├── directional_wrapper.py   # 方向性策略包装
│       ├── arbitrage_wrapper.py     # 套利策略包装
│       └── grid_wrapper.py          # 网格策略包装
│
├── bridge/                          # 信号桥
│   ├── __init__.py
│   ├── signal_converter.py          # 信号格式转换
│   ├── risk_filter.py               # 风险过滤器
│   ├── frequency_controller.py      # 频率控制
│   └── channels/                    # 通信渠道
│       ├── __init__.py
│       ├── redis_channel.py         # Redis 通道
│       └── mqtt_channel.py          # MQTT 通道
│
├── execution/                       # 执行层
│   ├── __init__.py
│   ├── executor_manager.py          # 执行器管理
│   ├── order_router.py              # 订单路由
│   └── executors/                   # 执行器适配
│       ├── __init__.py
│       ├── position_executor.py     # 仓位执行器
│       ├── twap_executor.py         # TWAP 执行器
│       ├── dca_executor.py          # DCA 执行器
│       └── grid_executor.py         # 网格执行器
│
├── risk/                            # 风险管理
│   ├── __init__.py
│   ├── kill_switch.py               # 紧急停止
│   ├── position_limit.py            # 仓位限制
│   ├── balance_limit.py             # 余额限制
│   ├── rate_limiter.py              # API 限速
│   └── liquidation_monitor.py       # 强平监控
│
├── workflow/                        # 工作流
│   ├── __init__.py
│   ├── task_manager.py              # 任务管理 (MongoDB)
│   ├── trainer.py                   # 训练器包装
│   ├── rolling.py                   # 滚动训练
│   └── online_service.py            # 在线服务
│
├── dashboard/                       # 可视化
│   ├── __init__.py
│   ├── app.py                       # Streamlit 主应用
│   ├── pages/                       # 页面
│   │   ├── backtest.py              # 回测页面
│   │   ├── live_trading.py          # 实盘页面
│   │   ├── portfolio.py             # 组合页面
│   │   └── optimization.py          # 优化页面
│   └── components/                  # 组件
│       ├── charts.py                # 图表组件
│       └── tables.py                # 表格组件
│
├── cli/                             # 命令行工具
│   ├── __init__.py
│   ├── main.py                      # CLI 入口
│   ├── commands/                    # 命令
│   │   ├── data.py                  # 数据命令
│   │   ├── train.py                 # 训练命令
│   │   ├── backtest.py              # 回测命令
│   │   └── trade.py                 # 交易命令
│   └── utils.py                     # CLI 工具
│
└── tests/                           # 测试
    ├── __init__.py
    ├── unit/                        # 单元测试
    │   ├── test_data.py
    │   ├── test_factors.py
    │   ├── test_backtest.py
    │   └── test_execution.py
    ├── integration/                 # 集成测试
    │   ├── test_qlib_integration.py
    │   ├── test_hummingbot_integration.py
    │   └── test_end_to_end.py
    └── fixtures/                    # 测试数据
        └── sample_data/
```

---

## 三、实施阶段

### Phase 0: 环境准备 (第1步)

#### 0.1 依赖安装

```bash
# 创建虚拟环境
python -m venv venv
source venv/bin/activate

# 克隆仓库 (含 submodule)
git clone --recursive https://github.com/FelixWayne0318/AlgVex.git
cd AlgVex

# 安装 Qlib 和 Hummingbot
pip install -e libs/qlib
pip install -e libs/hummingbot

# 安装额外依赖
pip install ccxt redis paho-mqtt pymongo streamlit optuna plotly
```

#### 0.2 基础设施配置

| 服务 | 用途 | 配置 |
|------|------|------|
| MongoDB | 任务管理 | `mongodb://localhost:27017/algvex` |
| Redis | 信号桥 | `redis://localhost:6379/0` |
| MLflow | 实验跟踪 | `http://localhost:5000` |

```yaml
# config/infrastructure.yaml
mongodb:
  host: localhost
  port: 27017
  database: algvex_tasks

redis:
  host: localhost
  port: 6379
  db: 0

mlflow:
  tracking_uri: http://localhost:5000
  experiment_name: algvex
```

---

### Phase 1: 数据层 (第2-3步)

#### 1.1 CryptoCalendarProvider

```python
# algvex/data/providers/calendar.py
from qlib.data.data import CalendarProvider

class CryptoCalendarProvider(CalendarProvider):
    """
    24/7 加密货币日历
    - 无休市
    - 支持任意时间间隔
    """

    def calendar(self, start_time=None, end_time=None, freq="1h"):
        """生成 24/7 连续时间戳"""
        # 实现逻辑...
```

#### 1.2 数据收集器

```python
# algvex/data/collectors/binance_collector.py
from libs.qlib.scripts.data_collector.crypto.collector import CryptoCollector

class BinancePerpetualCollector(CryptoCollector):
    """
    扩展 Qlib crypto collector
    - 支持 1h 间隔
    - 支持永续合约数据
    - 使用 CCXT/Binance API
    """

    def __init__(self, save_dir, interval="1h", **kwargs):
        super().__init__(save_dir, interval=interval, **kwargs)
        self.exchange = ccxt.binance({
            'options': {'defaultType': 'future'}
        })
```

#### 1.3 桥接 Hummingbot Candles Feed

```python
# algvex/data/collectors/hummingbot_candles.py
from hummingbot.data_feed.candles_feed.binance_perpetual_candles import BinancePerpetualCandles

class CandlesToQlibBridge:
    """
    将 Hummingbot candles 转换为 Qlib 格式
    """

    def __init__(self, connector_name: str):
        self.candles = self._get_candles_feed(connector_name)

    def to_qlib_format(self, df) -> pd.DataFrame:
        """转换为 Qlib 标准格式"""
        # $open, $high, $low, $close, $volume, $factor, $vwap
        return df.rename(columns={...})
```

---

### Phase 2: 因子与模型 (第4-5步)

#### 2.1 CryptoAlpha158

```python
# algvex/factors/alpha158_crypto.py
from qlib.contrib.data.handler import Alpha158

class CryptoAlpha158(Alpha158):
    """
    加密货币 Alpha158
    - 时间窗口适配小时级 (24h = 1d)
    - 无停牌处理
    """

    def get_config_template(cls):
        config = super().get_config_template()
        # 调整窗口参数
        config["data"]["handler"]["kwargs"]["windows"] = [24, 48, 120, 168, 336]
        return config
```

#### 2.2 模型验证脚本

```python
# scripts/validate_models.py
"""
验证 Qlib 31 个模型在加密货币数据上的效果
"""
MODELS = [
    "LinearModel", "LGBModel", "XGBModel", "CatBoostModel",
    "LSTM", "GRU", "ALSTM", "GATs", "KRNN", "SFM", "ADARNN",
    "TransformerModel", "LocalformerModel", "TCN", "TCTS",
    "DNNModelPytorch", "TabnetModel", "TRAModel", "DEnsembleModel",
    "IGMTF", "HIST", "ADD", ...
]

def validate_all_models():
    for model_name in MODELS:
        # 训练并评估
        ic, icir, ret = train_and_evaluate(model_name)
        print(f"{model_name}: IC={ic:.4f}, ICIR={icir:.4f}")
```

---

### Phase 3: 回测层 (第6-7步)

#### 3.1 CryptoExchange

```python
# algvex/backtest/exchange/crypto_exchange.py
from qlib.backtest.exchange import Exchange

class CryptoExchange(Exchange):
    """
    加密货币交易所模拟
    - 支持做空
    - 支持杠杆 (1x-125x)
    - 支持资金费率
    """

    def __init__(self, leverage=10, margin_mode="cross", **kwargs):
        super().__init__(**kwargs)
        self.leverage = leverage
        self.margin_mode = margin_mode
        self.funding_rate_interval = 8  # 小时

    def calculate_funding_fee(self, position, funding_rate):
        """计算资金费用"""
        return position.value * funding_rate
```

#### 3.2 嵌套执行器适配

```python
# algvex/backtest/executor/nested_executor.py
from qlib.backtest import NestedExecutor, SimulatorExecutor

class CryptoNestedExecutor(NestedExecutor):
    """
    加密货币嵌套执行
    - 外层: 1h 信号
    - 内层: 分钟级执行
    """

    def __init__(self, outer_time="1h", inner_time="1min", **kwargs):
        inner_executor = SimulatorExecutor(
            time_per_step=inner_time,
            trade_exchange=CryptoExchange(**kwargs)
        )
        super().__init__(
            time_per_step=outer_time,
            inner_executor=inner_executor
        )
```

---

### Phase 4: 信号桥 (第8-9步)

#### 4.1 信号转换器

```python
# algvex/bridge/signal_converter.py

class SignalConverter:
    """
    Qlib 信号 -> Hummingbot 订单
    """

    def convert(self, qlib_signal: pd.DataFrame) -> List[OrderConfig]:
        """
        qlib_signal: instrument x datetime -> score
        """
        orders = []
        for instrument, score in qlib_signal.iterrows():
            if score > self.threshold:
                orders.append(OrderConfig(
                    trading_pair=self._to_trading_pair(instrument),
                    side="BUY" if score > 0 else "SELL",
                    amount=self._calculate_amount(score)
                ))
        return orders
```

#### 4.2 MQTT 集成

```python
# algvex/bridge/channels/mqtt_channel.py
from hummingbot.remote_iface.mqtt import MQTTCommands

class MQTTSignalChannel:
    """
    通过 MQTT 发送交易信号
    """

    def __init__(self, broker_host, broker_port):
        self.mqtt = MQTTCommands(broker_host, broker_port)

    def send_signal(self, signal):
        self.mqtt.publish("algvex/signals", signal.to_json())
```

---

### Phase 5: 执行层 (第10-11步)

#### 5.1 执行器管理

```python
# algvex/execution/executor_manager.py
from hummingbot.strategy_v2.executors import (
    PositionExecutor, TWAPExecutor, DCAExecutor, GridExecutor
)

class ExecutorManager:
    """
    管理多种执行器
    """

    EXECUTORS = {
        "position": PositionExecutor,
        "twap": TWAPExecutor,
        "dca": DCAExecutor,
        "grid": GridExecutor,
    }

    def create_executor(self, executor_type: str, config: dict):
        return self.EXECUTORS[executor_type](**config)
```

#### 5.2 风险管理集成

```python
# algvex/risk/kill_switch.py
from hummingbot.client.config.client_config_map import KillSwitchMode

class AlgVexKillSwitch:
    """
    紧急停止开关
    - 最大亏损触发
    - 时间范围限制
    """

    def __init__(self, max_loss_pct=5.0, enabled=True):
        self.max_loss_pct = max_loss_pct
        self.enabled = enabled

    def check(self, portfolio_value, initial_value):
        loss_pct = (initial_value - portfolio_value) / initial_value * 100
        if loss_pct >= self.max_loss_pct:
            return True  # 触发停止
        return False
```

---

### Phase 6: 在线服务 (第12-13步)

#### 6.1 OnlineManager 集成

```python
# algvex/workflow/online_service.py
from qlib.contrib.online import OnlineManager, RollingGen

class AlgVexOnlineService:
    """
    整合 Qlib OnlineManager
    """

    def __init__(self):
        self.online_manager = OnlineManager()
        self.rolling_gen = RollingGen(
            step=24,  # 24小时滚动
            rtype=RollingGen.ROLL_EX
        )

    def update_predictions(self):
        """增量更新预测"""
        self.online_manager.routine()
```

#### 6.2 滚动训练

```python
# algvex/workflow/rolling.py
from qlib.contrib.rolling import RollingTrainer

class CryptoRollingTrainer(RollingTrainer):
    """
    加密货币滚动训练
    - 每24小时更新模型
    - 支持增量学习
    """

    def __init__(self, step=24, **kwargs):
        super().__init__(step=step, **kwargs)
```

---

### Phase 7: Dashboard (第14步)

#### 7.1 Streamlit 应用

```python
# algvex/dashboard/app.py
import streamlit as st

def main():
    st.set_page_config(page_title="AlgVex Dashboard", layout="wide")

    pages = {
        "回测": backtest_page,
        "实盘": live_trading_page,
        "组合": portfolio_page,
        "优化": optimization_page,
    }

    page = st.sidebar.selectbox("页面", list(pages.keys()))
    pages[page]()

if __name__ == "__main__":
    main()
```

---

## 四、测试计划

### 4.1 单元测试

| 模块 | 测试文件 | 覆盖率目标 |
|------|----------|-----------|
| 数据层 | test_data.py | 90%+ |
| 因子 | test_factors.py | 95%+ |
| 回测 | test_backtest.py | 85%+ |
| 执行 | test_execution.py | 80%+ |

### 4.2 集成测试

```python
# tests/integration/test_end_to_end.py

def test_full_workflow():
    """端到端测试"""
    # 1. 数据收集
    collector = BinancePerpetualCollector(...)
    collector.run()

    # 2. 因子计算
    handler = CryptoAlpha158(...)
    dataset = handler.fetch()

    # 3. 模型训练
    model = LGBModel(...)
    model.fit(dataset)

    # 4. 回测
    backtest_result = run_backtest(model, dataset)

    # 5. 验证指标
    assert backtest_result.ic > 0.03
    assert backtest_result.icir > 0.5
```

### 4.3 Paper Trading 测试

```bash
# 启动 Paper Trading
python -m algvex.cli trade --mode paper --exchange binance_perpetual

# 运行 24 小时测试
# 验证:
# - 订单执行正确
# - 仓位计算正确
# - 资金费率计算正确
# - 风控触发正确
```

---

## 五、依赖版本清单

```requirements.txt
# Core
qlib @ file:./libs/qlib
hummingbot @ file:./libs/hummingbot

# ML/DL
torch>=2.0.0
lightgbm>=4.0.0
xgboost>=2.0.0
catboost>=1.2.0
tianshou>=0.5.0

# Data
ccxt>=4.0.0
pandas>=2.0.0
numpy>=1.24.0

# Communication
redis>=5.0.0
paho-mqtt>=2.0.0

# Database
pymongo>=4.6.0

# MLOps
mlflow>=2.10.0

# Dashboard
streamlit>=1.30.0
optuna>=3.5.0
plotly>=5.18.0

# Testing
pytest>=7.0.0
pytest-cov>=4.0.0
pytest-asyncio>=0.21.0
```

---

## 六、里程碑

| 里程碑 | 内容 | 验收标准 |
|--------|------|----------|
| M1 | 数据层完成 | 成功收集 BTC-USDT 1小时数据 |
| M2 | 因子完成 | Alpha158 因子计算正确 |
| M3 | 回测完成 | 回测 IC > 0.03 |
| M4 | 信号桥完成 | 信号正确传递到 Hummingbot |
| M5 | 执行层完成 | Paper Trading 订单执行正确 |
| M6 | 在线服务完成 | 24小时自动滚动更新 |
| M7 | Dashboard完成 | Streamlit 界面可用 |
| M8 | 全流程测试通过 | 端到端测试 100% 通过 |

---

## 七、风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Qlib 版本不兼容 | 高 | 锁定 v0.9.7，使用 submodule |
| Hummingbot API 变更 | 中 | 锁定 v2.11.0，抽象适配层 |
| 交易所 API 限制 | 中 | 实现重试机制，使用 CCXT |
| 资金费率计算错误 | 高 | 单独测试模块，对比真实数据 |
| 模型过拟合 | 高 | 严格划分训练/验证/测试集 |

---

**文档版本**: 1.0
**创建日期**: 2025-12-31
**作者**: Claude (AlgVex AI Assistant)
