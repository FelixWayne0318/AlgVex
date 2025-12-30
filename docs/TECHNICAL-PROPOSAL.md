# AlgVex 技术方案：Qlib + Hummingbot 加密货币适配

> **目标**: 完整实现 Qlib v0.9.7 和 Hummingbot v2.11.0 功能，不增加也不减少，仅适配数字货币交易
>
> **交易所**: 币安 (Binance)
> **交易类型**: 永续合约 (USDT-M Perpetual)
> **数据频率**: 1 小时 K 线

---

## 一、系统架构总览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AlgVex Platform                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Qlib (完整保留)                                    │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │   │
│  │  │  Model   │ │ Strategy │ │ Backtest │ │ Workflow │ │    RL    │  │   │
│  │  │ (ML/DL)  │ │(Portfolio)│ │(Executor)│ │(Recorder)│ │(Tianshou)│  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │   │
│  └───────────────────────────────┬─────────────────────────────────────┘   │
│                                  │                                          │
│  ┌───────────────────────────────▼─────────────────────────────────────┐   │
│  │                    Crypto Adapter Layer (新增)                       │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                 │   │
│  │  │CryptoCalendar│ │CryptoDataHdlr│ │CryptoExchange│                 │   │
│  │  │  (24/7日历)   │ │ (币安数据源)  │ │ (永续合约规则) │                 │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘                 │   │
│  └───────────────────────────────┬─────────────────────────────────────┘   │
│                                  │                                          │
│  ┌───────────────────────────────▼─────────────────────────────────────┐   │
│  │                    Signal Bridge (新增)                              │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                 │   │
│  │  │SignalConvert │ │ RiskFilter  │ │FrequencyCtrl │                 │   │
│  │  │ (格式转换)    │ │ (风险过滤)   │ │ (频率控制)    │                 │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘                 │   │
│  └───────────────────────────────┬─────────────────────────────────────┘   │
│                                  │                                          │
│  ┌───────────────────────────────▼─────────────────────────────────────┐   │
│  │                    Hummingbot (完整保留)                             │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │   │
│  │  │Connector │ │ Strategy │ │ Executor │ │   API    │ │   Risk   │  │   │
│  │  │(Binance) │ │   V2     │ │(Position)│ │ (REST)   │ │(Barrier) │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 二、Qlib 完整模块清单与适配方案

### 2.1 Qlib 模块清单 (v0.9.7)

| 模块 | 子模块 | 功能 | 适配策略 |
|------|--------|------|----------|
| **qlib.data** | DataHandler | 数据处理器 | 🔴 需适配 |
| | DataLoader | 数据加载器 | 🔴 需适配 |
| | Cache | 缓存系统 | 🟢 无需修改 |
| | Calendar | 交易日历 | 🔴 需适配 |
| | Instrument | 标的管理 | 🔴 需适配 |
| | Expression | 表达式引擎 | 🟢 无需修改 |
| **qlib.contrib.data** | Alpha158 | 158因子 | 🟡 需验证有效性 |
| | Alpha360 | 360因子 | 🟡 需验证有效性 |
| | Processor | 数据处理器 | 🟢 无需修改 |
| **qlib.model** | BaseModel | 模型基类 | 🟢 无需修改 |
| **qlib.contrib.model** | LGBModel | LightGBM | 🟢 无需修改 |
| | XGBModel | XGBoost | 🟢 无需修改 |
| | CatBoostModel | CatBoost | 🟢 无需修改 |
| | DNNModelPytorch | DNN | 🟢 无需修改 |
| | LSTM/GRU/ALSTM | RNN系列 | 🟢 无需修改 |
| | Transformer | Transformer | 🟢 无需修改 |
| | GATs | 图注意力网络 | 🟢 无需修改 |
| | TCN | 时序卷积网络 | 🟢 无需修改 |
| | TFT | 时序融合Transformer | 🟢 无需修改 |
| | TabNet | TabNet | 🟢 无需修改 |
| | DoubleEnsemble | 双重集成 | 🟢 无需修改 |
| | TCTS | 任务对比时序 | 🟢 无需修改 |
| **qlib.contrib.strategy** | TopkDropoutStrategy | TopK策略 | 🟢 无需修改 |
| | WeightStrategyBase | 权重策略 | 🟢 无需修改 |
| | EnhancedIndexingOptimizer | 增强指数 | 🟢 无需修改 |
| **qlib.backtest** | Exchange | 交易所模拟 | 🔴 需适配 |
| | Executor | 执行器 | 🟡 需修改参数 |
| | Position | 持仓管理 | 🟡 需支持做空 |
| | Account | 账户管理 | 🟡 需支持杠杆 |
| **qlib.workflow** | ExpManager | 实验管理 | 🟢 无需修改 |
| | Recorder | 记录器 | 🟢 无需修改 |
| | SignalRecord | 信号记录 | 🟢 无需修改 |
| | SigAnaRecord | 信号分析 | 🟢 无需修改 |
| | PortAnaRecord | 组合分析 | 🟢 无需修改 |
| **qlib.rl** | Simulator | RL模拟器 | 🟡 需适配环境 |
| | StateInterpreter | 状态解释器 | 🟢 无需修改 |
| | ActionInterpreter | 动作解释器 | 🟡 需适配订单类型 |
| | Reward | 奖励函数 | 🟡 需考虑资金费率 |
| | Trainer | 训练器 | 🟢 无需修改 |
| | TrainingVessel | 训练容器 | 🟢 无需修改 |

### 2.2 需要适配的核心模块详细设计

#### 2.2.1 CryptoCalendarProvider (24/7 交易日历)

```python
# algvex/adapters/crypto_calendar.py

from qlib.data import CalendarProvider
import pandas as pd

class CryptoCalendarProvider(CalendarProvider):
    """
    加密货币 24/7 交易日历
    - 无休市日
    - 支持分钟级到日级频率
    """

    FREQ_MAP = {
        '1min': '1T', '5min': '5T', '15min': '15T', '30min': '30T',
        '1h': '1H', '2h': '2H', '4h': '4H', '6h': '6H', '8h': '8H', '12h': '12H',
        '1d': '1D', '3d': '3D', '1w': '1W'
    }

    def calendar(self, start_time, end_time, freq='1h', future=False):
        """生成连续时间序列"""
        pd_freq = self.FREQ_MAP.get(freq, freq)
        return pd.date_range(start=start_time, end=end_time, freq=pd_freq)

    def get_calendar_range(self, freq='1h'):
        """返回日历的起止时间"""
        # 加密货币从 2017-01-01 开始有可靠数据
        return ('2017-01-01', pd.Timestamp.now().strftime('%Y-%m-%d'))
```

#### 2.2.2 CryptoInstrumentProvider (交易对管理)

```python
# algvex/adapters/crypto_instrument.py

from qlib.data import InstrumentProvider
import ccxt

class CryptoInstrumentProvider(InstrumentProvider):
    """
    加密货币交易对管理
    - 支持币安永续合约
    - 自动过滤低流动性交易对
    """

    def __init__(self, exchange='binance', min_volume_usdt=1_000_000):
        self.exchange = getattr(ccxt, exchange)({
            'options': {'defaultType': 'future'}  # 永续合约
        })
        self.min_volume = min_volume_usdt

    def instruments(self, market='binance_perp', filter_pipe=None):
        """
        获取交易对列表
        格式: BTC-USDT, ETH-USDT, ...
        """
        markets = self.exchange.load_markets()

        instruments = []
        for symbol, info in markets.items():
            if info.get('type') == 'swap' and info.get('quote') == 'USDT':
                # 检查交易量
                if self._check_volume(symbol):
                    # 转换格式: BTC/USDT:USDT -> BTC-USDT
                    base = info['base']
                    instruments.append(f"{base}-USDT")

        return sorted(instruments)

    def _check_volume(self, symbol):
        """检查 24h 交易量"""
        try:
            ticker = self.exchange.fetch_ticker(symbol)
            return ticker.get('quoteVolume', 0) > self.min_volume
        except:
            return False
```

#### 2.2.3 CryptoDataHandler (数据处理器)

```python
# algvex/adapters/crypto_data_handler.py

from qlib.data.dataset.handler import DataHandlerLP
import ccxt
import pandas as pd

class CryptoDataHandler(DataHandlerLP):
    """
    加密货币数据处理器
    - 从币安获取 OHLCV 数据
    - 支持资金费率数据
    - 1小时 K 线
    """

    def __init__(self,
                 instruments='binance_perp_top20',
                 start_time='2020-01-01',
                 end_time='2024-12-31',
                 freq='1h',
                 fit_start_time=None,
                 fit_end_time=None,
                 infer_processors=[],
                 learn_processors=[],
                 **kwargs):

        self.exchange = ccxt.binance({
            'options': {'defaultType': 'future'}
        })
        self.freq = freq

        super().__init__(
            instruments=instruments,
            start_time=start_time,
            end_time=end_time,
            fit_start_time=fit_start_time,
            fit_end_time=fit_end_time,
            infer_processors=infer_processors,
            learn_processors=learn_processors,
            **kwargs
        )

    def _fetch_ohlcv(self, symbol, since, until):
        """获取 OHLCV 数据"""
        all_data = []
        current = since

        while current < until:
            ohlcv = self.exchange.fetch_ohlcv(
                symbol=f"{symbol.replace('-', '/')}:USDT",
                timeframe=self.freq,
                since=current,
                limit=1000
            )
            if not ohlcv:
                break

            all_data.extend(ohlcv)
            current = ohlcv[-1][0] + 1

        df = pd.DataFrame(all_data, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
        df['datetime'] = pd.to_datetime(df['timestamp'], unit='ms')
        df.set_index('datetime', inplace=True)
        return df

    def _fetch_funding_rate(self, symbol, since, until):
        """获取资金费率"""
        funding_data = self.exchange.fetch_funding_rate_history(
            symbol=f"{symbol.replace('-', '/')}:USDT",
            since=since,
            limit=1000
        )

        df = pd.DataFrame(funding_data)
        df['datetime'] = pd.to_datetime(df['timestamp'], unit='ms')
        df.set_index('datetime', inplace=True)
        return df[['fundingRate']]
```

#### 2.2.4 CryptoExchangeConfig (交易所配置)

```python
# algvex/adapters/crypto_exchange.py

"""
币安永续合约交易所配置
- 无涨跌停限制
- Maker/Taker 手续费
- 支持做空
- 支持杠杆
"""

BINANCE_PERP_EXCHANGE_CONFIG = {
    # 基础配置
    "freq": "1h",                    # 1小时级别
    "limit_threshold": None,          # 无涨跌停
    "deal_price": "close",            # 收盘价成交

    # 手续费 (VIP0 级别)
    "open_cost": 0.0002,              # Maker 0.02%
    "close_cost": 0.0004,             # Taker 0.04%
    "min_cost": 0,                    # 无最低手续费

    # 滑点配置
    "impact_cost": 0.0005,            # 市场冲击成本 0.05%

    # 永续合约特有
    "funding_rate_interval": 8,       # 资金费率每 8 小时
    "leverage_default": 10,           # 默认杠杆
    "leverage_max": 125,              # 最大杠杆

    # 做空支持
    "allow_short": True,

    # 最小交易单位
    "min_order_amount": {
        "BTC-USDT": 0.001,
        "ETH-USDT": 0.01,
        "DEFAULT": 1.0
    }
}
```

#### 2.2.5 CryptoAlpha (加密货币因子)

```python
# algvex/adapters/crypto_alpha.py

from qlib.contrib.data.handler import Alpha158

class CryptoAlpha158(Alpha158):
    """
    加密货币适配版 Alpha158
    - 移除股票特有因子 (如: 换手率基于流通股)
    - 添加加密货币特有因子 (资金费率、链上数据)
    - 调整因子参数适应 1h 级别
    """

    def get_feature_config(self):
        # 保留原始 Alpha158 中通用的技术因子
        fields = []
        names = []

        # === 价格因子 (保留) ===
        # 收益率
        fields += ['$close/Ref($close,1)-1']
        names += ['RETURN_1H']

        fields += ['$close/Ref($close,24)-1']
        names += ['RETURN_24H']

        fields += ['$close/Ref($close,168)-1']  # 7天 = 168小时
        names += ['RETURN_7D']

        # 动量
        fields += ['Mean($close,7)/Mean($close,25)-1']
        names += ['MA7_MA25']

        fields += ['Mean($close,24)/Mean($close,168)-1']
        names += ['MA24_MA168']

        # === 波动率因子 (调整窗口) ===
        fields += ['Std($close,24)/$close']
        names += ['VOLATILITY_24H']

        fields += ['Std($close,168)/$close']
        names += ['VOLATILITY_7D']

        # 真实波动幅度
        fields += ['($high-$low)/$close']
        names += ['RANGE']

        fields += ['Mean(($high-$low)/$close,24)']
        names += ['ATR_24H']

        # === 成交量因子 (保留) ===
        fields += ['$volume/Mean($volume,24)-1']
        names += ['VOLUME_RATIO_24H']

        fields += ['$volume/Mean($volume,168)-1']
        names += ['VOLUME_RATIO_7D']

        fields += ['Corr($close,$volume,24)']
        names += ['PRICE_VOLUME_CORR']

        # === 技术指标 (调整周期) ===
        # RSI
        fields += ['Mean(Max($close-Ref($close,1),0),14)/Mean(Abs($close-Ref($close,1)),14)']
        names += ['RSI_14H']

        # MACD
        fields += ['EMA($close,12)-EMA($close,26)']
        names += ['MACD']

        # 布林带位置
        fields += ['($close-Mean($close,20))/(2*Std($close,20))']
        names += ['BBANDS_POSITION']

        # === 加密货币特有因子 (新增) ===
        # 资金费率 (需要额外数据)
        fields += ['$funding_rate']
        names += ['FUNDING_RATE']

        fields += ['Mean($funding_rate,8)']  # 8期 = 1天
        names += ['FUNDING_RATE_MA']

        # 多空比 (如果有数据)
        fields += ['$long_short_ratio']
        names += ['LONG_SHORT_RATIO']

        return fields, names

    def get_label_config(self):
        """
        标签配置: 预测下一小时收益
        """
        return ['Ref($close,-1)/$close-1'], ['LABEL']
```

---

## 三、Hummingbot 完整模块清单与适配方案

### 3.1 Hummingbot 模块清单 (v2.11.0)

| 模块 | 子模块 | 功能 | 集成方式 |
|------|--------|------|----------|
| **Connector** | binance_perpetual | 币安永续连接器 | 🟢 直接使用 |
| | OrderBookTracker | 订单簿追踪 | 🟢 直接使用 |
| | UserStreamTracker | 用户流追踪 | 🟢 直接使用 |
| **Strategy V2** | StrategyV2Base | 策略基类 | 🟢 继承使用 |
| | Controllers | 策略控制器 | 🔴 需扩展 |
| | ExecutorOrchestrator | 执行编排器 | 🟢 直接使用 |
| **Executors** | PositionExecutor | 仓位执行器 | 🟢 直接使用 |
| | ArbitrageExecutor | 套利执行器 | 🟢 直接使用 |
| | DCAExecutor | 定投执行器 | 🟢 直接使用 |
| | GridExecutor | 网格执行器 | 🟢 直接使用 |
| | TWAPExecutor | TWAP执行器 | 🟢 直接使用 |
| **Risk Management** | TripleBarrier | 三重障碍 | 🟢 直接使用 |
| | StopLoss/TakeProfit | 止损止盈 | 🟢 直接使用 |
| | TrailingStop | 追踪止损 | 🟢 直接使用 |
| **Data** | MarketDataProvider | 市场数据 | 🟢 直接使用 |
| | CandlesFeed | K线数据 | 🟢 直接使用 |
| | OrderBookData | 订单簿数据 | 🟢 直接使用 |
| **API** | REST API | HTTP接口 | 🟢 用于接收信号 |
| | WebSocket | 实时推送 | 🟢 直接使用 |

### 3.2 自定义控制器设计

#### 3.2.1 QlibSignalController

```python
# algvex/hummingbot_integration/qlib_controller.py

from hummingbot.strategy_v2.controllers.directional_trading_controller_base import (
    DirectionalTradingControllerBase,
    DirectionalTradingControllerConfigBase
)
from hummingbot.strategy_v2.executors.position_executor.data_types import (
    PositionExecutorConfig,
    TripleBarrierConf
)
from hummingbot.strategy_v2.models.executor_actions import CreateExecutorAction, StopExecutorAction
from decimal import Decimal
from typing import List
import redis
import json

class QlibControllerConfig(DirectionalTradingControllerConfigBase):
    """Qlib 信号控制器配置"""
    controller_name: str = "qlib_signal"

    # 信号来源
    signal_source: str = "redis"  # redis, sqlite, rest
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_channel: str = "qlib_signals"

    # 信号阈值
    long_threshold: Decimal = Decimal("0.6")
    short_threshold: Decimal = Decimal("-0.6")

    # 仓位配置
    leverage: int = 10
    position_size_pct: Decimal = Decimal("0.1")  # 账户 10%

    # 风险配置
    stop_loss: Decimal = Decimal("0.02")         # 2%
    take_profit: Decimal = Decimal("0.04")       # 4%
    trailing_stop_activation: Decimal = Decimal("0.02")
    trailing_stop_delta: Decimal = Decimal("0.01")
    time_limit: int = 3600 * 4  # 4小时


class QlibSignalController(DirectionalTradingControllerBase):
    """
    Qlib 信号控制器
    - 接收 Qlib 模型预测信号
    - 转换为 Hummingbot 交易动作
    - 使用 PositionExecutor 执行
    """

    def __init__(self, config: QlibControllerConfig, *args, **kwargs):
        super().__init__(config, *args, **kwargs)
        self.config = config
        self.current_signal = Decimal("0")
        self.signal_timestamp = None

        # 初始化信号接收器
        if config.signal_source == "redis":
            self._init_redis_subscriber()

    def _init_redis_subscriber(self):
        """初始化 Redis 订阅"""
        self.redis_client = redis.Redis(
            host=self.config.redis_host,
            port=self.config.redis_port
        )
        self.pubsub = self.redis_client.pubsub()
        self.pubsub.subscribe(self.config.redis_channel)

    def update_processed_data(self):
        """更新处理后的数据 (每 tick 调用)"""
        # 获取最新信号
        self._fetch_latest_signal()

        # 获取当前持仓状态
        self.active_executors = self.filter_executors(
            executors=self.executors_info,
            filter_func=lambda e: e.is_active
        )

    def _fetch_latest_signal(self):
        """从 Redis 获取最新信号"""
        try:
            message = self.pubsub.get_message(timeout=0.1)
            if message and message['type'] == 'message':
                data = json.loads(message['data'])
                if data['trading_pair'] == self.config.trading_pair:
                    self.current_signal = Decimal(str(data['signal']))
                    self.signal_timestamp = data['timestamp']
        except Exception as e:
            self.logger().warning(f"Failed to fetch signal: {e}")

    def determine_executor_actions(self) -> List:
        """确定执行器动作"""
        actions = []

        # 检查是否有活跃仓位
        has_long = any(e.side == 'BUY' for e in self.active_executors)
        has_short = any(e.side == 'SELL' for e in self.active_executors)

        # 强烈做多信号
        if self.current_signal > self.config.long_threshold:
            # 平空仓
            if has_short:
                for executor in self.active_executors:
                    if executor.side == 'SELL':
                        actions.append(StopExecutorAction(
                            executor_id=executor.id,
                            controller_id=self.config.id
                        ))

            # 开多仓
            if not has_long:
                config = self._create_position_config('BUY')
                actions.append(CreateExecutorAction(
                    executor_config=config,
                    controller_id=self.config.id
                ))

        # 强烈做空信号
        elif self.current_signal < self.config.short_threshold:
            # 平多仓
            if has_long:
                for executor in self.active_executors:
                    if executor.side == 'BUY':
                        actions.append(StopExecutorAction(
                            executor_id=executor.id,
                            controller_id=self.config.id
                        ))

            # 开空仓
            if not has_short:
                config = self._create_position_config('SELL')
                actions.append(CreateExecutorAction(
                    executor_config=config,
                    controller_id=self.config.id
                ))

        return actions

    def _create_position_config(self, side: str) -> PositionExecutorConfig:
        """创建仓位执行器配置"""
        return PositionExecutorConfig(
            connector_name=self.config.connector_name,
            trading_pair=self.config.trading_pair,
            side=side,
            leverage=self.config.leverage,
            amount=self._calculate_position_size(),
            triple_barrier_conf=TripleBarrierConf(
                stop_loss=self.config.stop_loss,
                take_profit=self.config.take_profit,
                time_limit=self.config.time_limit,
                trailing_stop_activation_price_delta=self.config.trailing_stop_activation,
                trailing_stop_trailing_delta=self.config.trailing_stop_delta
            )
        )

    def _calculate_position_size(self) -> Decimal:
        """计算仓位大小"""
        # 获取账户余额
        balance = self.get_balance(self.config.connector_name, "USDT")

        # 考虑杠杆
        position_value = balance * self.config.position_size_pct * self.config.leverage

        # 获取当前价格
        price = self.market_data_provider.get_price_by_type(
            connector_name=self.config.connector_name,
            trading_pair=self.config.trading_pair,
            price_type="MID"
        )

        # 计算数量
        amount = position_value / price

        return self.connectors[self.config.connector_name].quantize_order_amount(
            self.config.trading_pair, amount
        )

    def to_format_status(self) -> List[str]:
        """格式化状态显示"""
        lines = []
        lines.append(f"Current Signal: {self.current_signal:.4f}")
        lines.append(f"Signal Timestamp: {self.signal_timestamp}")
        lines.append(f"Active Executors: {len(self.active_executors)}")

        for executor in self.active_executors:
            lines.append(f"  - {executor.side}: {executor.amount} @ {executor.entry_price}")

        return lines
```

---

## 四、Signal Bridge 设计

### 4.1 信号桥架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Signal Bridge                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────┐│
│  │  Qlib Model    │    │   Converter    │    │  Publisher ││
│  │  Predictor     │ →  │   & Validator  │ →  │  (Redis)   ││
│  └────────────────┘    └────────────────┘    └────────────┘│
│         │                     │                     │       │
│         ▼                     ▼                     ▼       │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────┐│
│  │ Raw Prediction │    │ Signal Object  │    │ Hummingbot ││
│  │ (pd.Series)    │    │ (Normalized)   │    │ Controller ││
│  └────────────────┘    └────────────────┘    └────────────┘│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Signal Bridge 实现

```python
# algvex/bridge/signal_bridge.py

import redis
import json
from datetime import datetime
from typing import Dict, Optional
from dataclasses import dataclass, asdict
import pandas as pd
import numpy as np

@dataclass
class TradingSignal:
    """交易信号数据结构"""
    trading_pair: str
    signal: float           # -1.0 到 1.0
    confidence: float       # 0.0 到 1.0
    timestamp: str
    model_name: str
    prediction_horizon: str  # 如 "1h"

    def to_dict(self) -> Dict:
        return asdict(self)

    def to_json(self) -> str:
        return json.dumps(self.to_dict())


class SignalBridge:
    """
    Qlib → Hummingbot 信号桥

    功能:
    1. 接收 Qlib 模型预测
    2. 标准化信号格式
    3. 风险过滤
    4. 发布到 Redis
    """

    def __init__(self,
                 redis_host: str = 'localhost',
                 redis_port: int = 6379,
                 channel: str = 'qlib_signals'):

        self.redis_client = redis.Redis(host=redis_host, port=redis_port)
        self.channel = channel

        # 风险过滤参数
        self.min_confidence = 0.5
        self.signal_cooldown = {}  # 交易对 -> 上次信号时间
        self.cooldown_seconds = 300  # 5分钟冷却

    def process_prediction(self,
                          prediction: pd.Series,
                          model_name: str = 'default',
                          prediction_horizon: str = '1h') -> Dict[str, TradingSignal]:
        """
        处理 Qlib 模型预测

        Args:
            prediction: Qlib 模型输出的预测 Series
                       Index: (datetime, instrument)
                       Values: 预测值
            model_name: 模型名称
            prediction_horizon: 预测周期

        Returns:
            Dict[trading_pair, TradingSignal]
        """
        signals = {}
        timestamp = datetime.utcnow().isoformat()

        # 获取最新时间点的预测
        if isinstance(prediction.index, pd.MultiIndex):
            latest_time = prediction.index.get_level_values(0).max()
            latest_pred = prediction.loc[latest_time]
        else:
            latest_pred = prediction

        # 标准化预测值到 [-1, 1]
        normalized = self._normalize_predictions(latest_pred)

        for instrument, signal_value in normalized.items():
            trading_pair = self._convert_instrument(instrument)

            # 计算置信度 (基于信号强度和历史准确率)
            confidence = self._calculate_confidence(signal_value, instrument)

            # 风险过滤
            if not self._pass_risk_filter(trading_pair, signal_value, confidence):
                continue

            signal = TradingSignal(
                trading_pair=trading_pair,
                signal=float(signal_value),
                confidence=float(confidence),
                timestamp=timestamp,
                model_name=model_name,
                prediction_horizon=prediction_horizon
            )

            signals[trading_pair] = signal

        return signals

    def publish_signals(self, signals: Dict[str, TradingSignal]):
        """发布信号到 Redis"""
        for trading_pair, signal in signals.items():
            self.redis_client.publish(self.channel, signal.to_json())

            # 更新冷却时间
            self.signal_cooldown[trading_pair] = datetime.utcnow()

    def _normalize_predictions(self, predictions: pd.Series) -> pd.Series:
        """
        标准化预测值到 [-1, 1]
        使用 tanh 变换保持单调性
        """
        # Z-score 标准化
        mean = predictions.mean()
        std = predictions.std()

        if std > 0:
            z_scores = (predictions - mean) / std
        else:
            z_scores = predictions - mean

        # Tanh 压缩到 [-1, 1]
        normalized = np.tanh(z_scores)

        return normalized

    def _calculate_confidence(self, signal: float, instrument: str) -> float:
        """
        计算信号置信度

        考虑因素:
        - 信号强度
        - 历史准确率 (如果有)
        - 模型一致性
        """
        # 基础置信度来自信号强度
        base_confidence = abs(signal)

        # TODO: 可以加入历史准确率调整

        return min(base_confidence, 1.0)

    def _pass_risk_filter(self, trading_pair: str, signal: float, confidence: float) -> bool:
        """
        风险过滤

        检查:
        - 置信度阈值
        - 信号冷却时间
        - 信号强度阈值
        """
        # 置信度过滤
        if confidence < self.min_confidence:
            return False

        # 信号强度过滤
        if abs(signal) < 0.3:
            return False

        # 冷却时间检查
        if trading_pair in self.signal_cooldown:
            elapsed = (datetime.utcnow() - self.signal_cooldown[trading_pair]).total_seconds()
            if elapsed < self.cooldown_seconds:
                return False

        return True

    def _convert_instrument(self, instrument: str) -> str:
        """
        转换 Qlib instrument 格式到 Hummingbot 格式

        Qlib: BTCUSDT / BTC-USDT
        Hummingbot: BTC-USDT
        """
        # 移除可能的交易所前缀
        if ':' in instrument:
            instrument = instrument.split(':')[1]

        # 标准化格式
        if '-' not in instrument and 'USDT' in instrument:
            base = instrument.replace('USDT', '')
            return f"{base}-USDT"

        return instrument
```

### 4.3 实时预测服务

```python
# algvex/services/prediction_service.py

import schedule
import time
from threading import Thread
from qlib.workflow import R
from qlib.data import D
from algvex.bridge.signal_bridge import SignalBridge

class PredictionService:
    """
    实时预测服务
    - 定时运行模型预测
    - 发布信号到 Hummingbot
    """

    def __init__(self,
                 model_experiment_name: str,
                 model_recorder_id: str,
                 instruments: list,
                 prediction_interval: str = '1h'):

        self.instruments = instruments
        self.interval = prediction_interval
        self.bridge = SignalBridge()

        # 加载模型
        recorder = R.get_recorder(
            experiment_name=model_experiment_name,
            recorder_id=model_recorder_id
        )
        self.model = recorder.load_object('model')
        self.handler_config = recorder.load_object('handler_config')

    def start(self):
        """启动服务"""
        # 每小时运行一次
        schedule.every().hour.at(":00").do(self.run_prediction)

        # 启动调度线程
        thread = Thread(target=self._schedule_runner, daemon=True)
        thread.start()

        print(f"Prediction service started. Interval: {self.interval}")

    def _schedule_runner(self):
        """调度运行器"""
        while True:
            schedule.run_pending()
            time.sleep(1)

    def run_prediction(self):
        """运行一次预测"""
        try:
            # 获取最新数据
            latest_data = self._fetch_latest_data()

            # 模型预测
            predictions = self.model.predict(latest_data)

            # 处理并发布信号
            signals = self.bridge.process_prediction(
                prediction=predictions,
                model_name=self.model.__class__.__name__,
                prediction_horizon=self.interval
            )

            self.bridge.publish_signals(signals)

            print(f"Published {len(signals)} signals")

        except Exception as e:
            print(f"Prediction failed: {e}")

    def _fetch_latest_data(self):
        """获取最新市场数据"""
        # 实现数据获取逻辑
        pass
```

---

## 五、目录结构

```
AlgVex/
├── .github/workflows/          # CI/CD 工作流
├── docs/
│   ├── WORKFLOWS-GUIDE.md      # 工作流指南
│   └── TECHNICAL-PROPOSAL.md   # 本文档
├── scripts/
│   ├── setup-qlib.sh           # Qlib 安装脚本
│   └── setup-hummingbot.sh     # Hummingbot 安装脚本
│
├── algvex/                     # 主代码目录 (新增)
│   ├── __init__.py
│   │
│   ├── adapters/               # Qlib 适配层
│   │   ├── __init__.py
│   │   ├── crypto_calendar.py      # 24/7 日历
│   │   ├── crypto_instrument.py    # 交易对管理
│   │   ├── crypto_data_handler.py  # 数据处理器
│   │   ├── crypto_exchange.py      # 交易所配置
│   │   └── crypto_alpha.py         # 加密货币因子
│   │
│   ├── bridge/                 # 信号桥
│   │   ├── __init__.py
│   │   └── signal_bridge.py        # Qlib → Hummingbot
│   │
│   ├── hummingbot_integration/ # Hummingbot 集成
│   │   ├── __init__.py
│   │   ├── qlib_controller.py      # Qlib 信号控制器
│   │   └── qlib_strategy.py        # Qlib 策略脚本
│   │
│   ├── services/               # 后台服务
│   │   ├── __init__.py
│   │   ├── prediction_service.py   # 预测服务
│   │   └── data_sync_service.py    # 数据同步服务
│   │
│   └── configs/                # 配置文件
│       ├── qlib/
│       │   ├── crypto_alpha158.yaml    # 因子配置
│       │   └── model_lgb.yaml          # LightGBM 配置
│       └── hummingbot/
│           └── qlib_signal.yaml        # 控制器配置
│
├── examples/                   # 示例
│   ├── train_btc_model.py          # 训练示例
│   ├── backtest_strategy.py        # 回测示例
│   └── live_trading.py             # 实盘示例
│
├── tests/                      # 测试
│   ├── test_adapters.py
│   ├── test_bridge.py
│   └── test_integration.py
│
├── CLAUDE.md                   # Claude Code 配置
├── README.md                   # 项目说明
└── requirements.txt            # 依赖
```

---

## 六、实施计划

### Phase 1: 数据层适配 (核心)

| 任务 | 文件 | 说明 |
|------|------|------|
| 1.1 | `crypto_calendar.py` | 实现 24/7 交易日历 |
| 1.2 | `crypto_instrument.py` | 实现交易对管理器 |
| 1.3 | `crypto_data_handler.py` | 实现数据处理器 |
| 1.4 | 数据采集脚本 | 从币安获取历史数据并转为 Qlib 格式 |

### Phase 2: 回测层适配

| 任务 | 文件 | 说明 |
|------|------|------|
| 2.1 | `crypto_exchange.py` | 实现永续合约交易规则 |
| 2.2 | 仓位管理扩展 | 支持做空和杠杆 |
| 2.3 | 资金费率模拟 | 回测中考虑资金费率 |

### Phase 3: 因子库验证

| 任务 | 文件 | 说明 |
|------|------|------|
| 3.1 | `crypto_alpha.py` | 适配 Alpha158 因子 |
| 3.2 | 因子有效性测试 | 验证各因子在加密市场的 IC |
| 3.3 | 新增加密货币因子 | 资金费率、链上数据等 |

### Phase 4: 信号桥与集成

| 任务 | 文件 | 说明 |
|------|------|------|
| 4.1 | `signal_bridge.py` | 实现信号格式转换 |
| 4.2 | `qlib_controller.py` | 实现 Hummingbot 控制器 |
| 4.3 | `prediction_service.py` | 实现实时预测服务 |

### Phase 5: 测试与文档

| 任务 | 文件 | 说明 |
|------|------|------|
| 5.1 | 单元测试 | 各模块测试 |
| 5.2 | 集成测试 | 端到端测试 |
| 5.3 | 文档完善 | 使用指南 |

---

## 七、技术要求

### 7.1 依赖版本

```
# Qlib
qlib==0.9.7
torch>=2.0.0
lightgbm>=4.0.0
xgboost>=2.0.0
catboost>=1.2.0
tianshou>=0.5.0  # RL

# Hummingbot
hummingbot>=2.11.0
hummingbot-api-client>=0.1.0

# 数据
ccxt>=4.0.0
pandas>=2.0.0
numpy>=1.24.0

# 通信
redis>=5.0.0

# MLOps
mlflow>=2.10.0
```

### 7.2 环境变量

```bash
# Qlib
QLIB_DATA_PATH=/path/to/qlib_data/crypto_data

# Binance API
BINANCE_API_KEY=your_api_key
BINANCE_API_SECRET=your_api_secret

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Hummingbot
HUMMINGBOT_API_URL=http://localhost:8000
```

---

## 八、风险与注意事项

### 8.1 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Alpha158 因子在加密市场无效 | 模型效果差 | 提前做因子有效性测试 |
| 高频数据量大 | 存储/计算压力 | 使用增量更新、数据压缩 |
| 信号延迟 | 错过交易时机 | 优化预测 pipeline、使用 Redis 实时通信 |
| 交易所 API 限制 | 下单失败 | 实现重试机制、遵守 rate limit |

### 8.2 交易风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 高杠杆爆仓 | 本金损失 | 设置最大杠杆限制、强制止损 |
| 资金费率 | 持仓成本 | 在策略中考虑资金费率 |
| 极端行情 | 策略失效 | Triple Barrier 风控、最大回撤限制 |
| 滑点 | 执行成本 | 使用限价单、控制仓位大小 |

---

## 九、总结

本方案设计遵循以下原则：

1. **完整性**: Qlib 和 Hummingbot 的所有功能模块均保留，不增不减
2. **最小侵入**: 通过适配层扩展，不修改原有框架代码
3. **解耦设计**: Qlib 研究端与 Hummingbot 交易端通过 Signal Bridge 解耦
4. **可扩展性**: 预留接口支持未来扩展 (更多交易所、更多因子)

**核心工作量**:
- 🔴 数据层适配 (40%)
- 🟡 回测层适配 (20%)
- 🟢 信号桥实现 (20%)
- 🟢 控制器实现 (20%)

---

**文档版本**: 1.0
**创建日期**: 2025-12-30
**作者**: Claude (AlgVex AI Assistant)
