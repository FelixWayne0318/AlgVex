# AlgVex 执行方案

> **版本**: 4.4
> **日期**: 2025-12-31
> **目标**: 基于 Qlib v0.9.7 + Hummingbot v2.11.0 构建加密货币量化交易系统

---

## 目录

- [一、项目概述](#一项目概述)
- [二、系统架构](#二系统架构)
- [三、功能清单与能力矩阵](#三功能清单与能力矩阵)
- [四、文件结构](#四文件结构)
- [五、详细实现规范](#五详细实现规范)
- [六、实施阶段](#六实施阶段)
- [七、本地测试方案](#七本地测试方案)
- [八、服务器部署方案](#八服务器部署方案)
- [九、验收标准](#九验收标准)
- [十、风险偏差声明](#十风险偏差声明)
- [十一、交付物清单](#十一交付物清单)
- [附录 A: 参考资源](#附录-a-参考资源)
- [附录 B: 源码路径参考表](#附录-b-源码路径参考表)
- [附录 C: 常见问题排查](#附录-c-常见问题排查)

---

## 一、项目概述

### 1.1 项目目标

构建一个加密货币量化交易系统，实现最小闭环：

```
数据收集 → 因子计算 → 模型训练 → 回测验证 → 信号生成 → 交易执行 → 风控监控
```

### 1.2 核心原则

| 原则 | 说明 |
|------|------|
| **双服务架构** | Research (Qlib) 与 Execution (Hummingbot) 强制分离，消息层为唯一通信路径 |
| **零自造格式** | 数据落盘使用官方脚本，不自造二进制格式 |
| **生产级可靠** | 信号桥实现幂等、去重、MQTT QoS 1 可靠投递 |
| **最小闭环优先** | 先实现核心链路，可选功能标注能力矩阵 |

### 1.3 技术选型

| 组件 | 版本 | 运行环境 | 说明 |
|------|------|----------|------|
| Qlib | 0.9.7 | Python 3.10 | Research Container |
| Hummingbot | 2.11.0 | Python 3.12 | Execution Container |
| EMQX | 5.x | Alpine | 消息层 (MQTT) - 与 Hummingbot 生态对齐 |
| 操作系统 | Ubuntu 22.04 | Docker | 容器化部署 |

### 1.4 为什么采用双容器架构

#### 依赖实际情况

| 依赖 | Qlib 要求 | Hummingbot 要求 | 兼容性 |
|------|-----------|-----------------|--------|
| numpy | 无限制 (主) / `<2.0.0` (仅RL可选) | `>=2.2.6` | ⚠️ RL模块冲突 |
| pandas | `>=0.24` | `>=2.3.2` | ✅ 兼容 (2.3.2满足两者) |
| Python | 3.8-3.12 | 3.12 | ✅ 兼容 |

> **技术事实**: 如果不使用 Qlib RL 模块 (tianshou)，两者依赖理论上兼容。

#### 仍采用双容器的理由

| 考量 | 单容器风险 | 双容器优势 |
|------|-----------|-----------|
| **未来扩展** | 可能需要 RL 模块 | 架构不变即可启用 |
| **隐性依赖** | 传递依赖可能冲突 | 完全隔离 |
| **运维稳定** | pip 依赖地狱 | 各自独立升级 |
| **故障隔离** | Research 崩溃影响 Execution | 互不影响 |
| **资源控制** | 难以限制 | Docker 原生支持 |

> **架构决策**: 生产级系统优先考虑稳定性和可维护性，双容器架构是更稳健的选择。

---

## 二、系统架构

### 2.1 双服务架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AlgVex Platform v4.4                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌───────────────────────────┐       ┌───────────────────────────┐      │
│  │    Research Container     │       │   Execution Container     │      │
│  │       (Python 3.10)       │       │      (Python 3.12)        │      │
│  │                           │       │                           │      │
│  │  ┌─────────────────────┐  │       │  ┌─────────────────────┐  │      │
│  │  │   Data Collector    │  │       │  │   Signal Consumer   │  │      │
│  │  │  (CSV/Parquet only) │  │       │  │  (paho-mqtt + QoS1) │  │      │
│  │  └──────────┬──────────┘  │       │  └──────────┬──────────┘  │      │
│  │             │             │       │             │             │      │
│  │  ┌──────────▼──────────┐  │       │  ┌──────────▼──────────┐  │      │
│  │  │  Qlib dump_bin.py   │  │       │  │   Readiness Gate    │  │      │
│  │  │   (官方格式转换)     │  │       │  │  (Connector Ready)  │  │      │
│  │  └──────────┬──────────┘  │       │  └──────────┬──────────┘  │      │
│  │             │             │       │             │             │      │
│  │  ┌──────────▼──────────┐  │       │  ┌──────────▼──────────┐  │      │
│  │  │   Factor Engine     │  │       │  │  Idempotency Check  │  │      │
│  │  │  (Alpha158 适配)    │  │       │  │   (去重 + 幂等)      │  │      │
│  │  └──────────┬──────────┘  │       │  └──────────┬──────────┘  │      │
│  │             │             │       │             │             │      │
│  │  ┌──────────▼──────────┐  │       │  ┌──────────▼──────────┐  │      │
│  │  │   Model Training    │  │       │  │  Hummingbot Engine  │  │      │
│  │  │  (LGBModel 等)      │  │       │  │  (Executors/风控)   │  │      │
│  │  └──────────┬──────────┘  │       │  └──────────┬──────────┘  │      │
│  │             │             │       │             │             │      │
│  │  ┌──────────▼──────────┐  │       │  ┌──────────▼──────────┐  │      │
│  │  │  Signal Publisher   │  │       │  │   Status Reporter   │  │      │
│  │  │   (paho-mqtt)       │  │       │  │   (paho-mqtt)       │  │      │
│  │  └──────────┬──────────┘  │       │  └──────────┬──────────┘  │      │
│  │             │             │       │             │             │      │
│  └─────────────┼─────────────┘       └─────────────┼─────────────┘      │
│                │                                   │                     │
│                │     ┌───────────────────────┐     │                     │
│                └────►│      EMQX (MQTT)      │◄────┘                     │
│                      │    (强制架构边界)       │                          │
│                      │                       │                          │
│                      │  • algvex/signals     │ (Topic)                  │
│                      │  • algvex/status      │ (Topic)                  │
│                      │  • algvex/commands    │ (Topic)                  │
│                      │  • QoS 1 (至少一次)    │                          │
│                      │  • Dashboard :18083   │                          │
│                      └───────────────────────┘                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 消息流设计

```
Research Container                      EMQX (MQTT)                     Execution Container
       │                                    │                                  │
       │  1. 生成信号                        │                                  │
       ├───────────────────────────────────►│                                  │
       │  PUBLISH algvex/signals {          │                                  │
       │    signal_id: "uuid",              │                                  │
       │    timestamp: "2024-01-01T00:00Z", │                                  │
       │    symbol: "BTC-USDT",             │                                  │
       │    side: "BUY",                    │                                  │
       │    amount: "0.1",                  │                                  │
       │    score: "0.85"                   │                                  │
       │  } QoS=1                           │                                  │
       │                                    │  2. 推送信号 (SUBSCRIBE)          │
       │                                    ├─────────────────────────────────►│
       │                                    │                                  │
       │                                    │                    3. Readiness Check
       │                                    │                    4. 幂等检查
       │                                    │                    5. 执行交易
       │                                    │                                  │
       │                                    │  6. 状态回报                      │
       │  7. 接收状态 (SUBSCRIBE)            │◄─────────────────────────────────┤
       │◄───────────────────────────────────│  PUBLISH algvex/status {...}     │
       │                                    │                                  │
```

### 2.3 为什么用 MQTT (EMQX)

| 维度 | Redis Streams | MQTT (EMQX) | 选择 |
|------|---------------|-------------|------|
| **Hummingbot 生态** | ❌ 需自造协议 | ✅ 官方 brokers 直接兼容 | MQTT |
| **可观测性** | 需写代码监控 | ✅ EMQX Dashboard 内置 | MQTT |
| **多 bot 扩容** | 需自己设计 Consumer Group | ✅ Topic + QoS 原生支持 | MQTT |
| **权限隔离** | 需应用层实现 | ✅ ACL 原生支持 | MQTT |
| **未来迁移** | ⚠️ 接官方 Dashboard 需引入 MQTT | ✅ 已在生态内 | MQTT |
| **消息可靠性** | ✅ Streams 强 | ✅ QoS 1/2 足够 | 平 |

> **选择 MQTT 的核心理由**: Hummingbot 官方 [brokers](https://github.com/hummingbot/brokers) 使用 MQTT，未来接入官方 Dashboard/API 时无需引入第二套消息系统。

---

## 三、功能清单与能力矩阵

### 3.1 能力矩阵图例

| 状态 | 说明 |
|------|------|
| ✅ 支持 | 已验证可用，纳入最小闭环 |
| ⚠️ 受限 | 可用但有限制条件 |
| ❌ 不支持 | 不适用于加密货币或存在技术障碍 |
| 🔜 后续 | 规划中，当前版本不实现 |

### 3.2 Qlib 能力矩阵

#### 3.2.1 模型

| 类别 | 模型 | 状态 | 说明 |
|------|------|------|------|
| **传统ML** | LGBModel | ✅ 支持 | **首选模型**，稳定高效 |
| | XGBModel | ✅ 支持 | |
| | CatBoostModel | ✅ 支持 | |
| | LinearModel | ✅ 支持 | 基线模型 |
| **RNN** | LSTM, GRU | ✅ 支持 | 需 GPU |
| | ALSTM | ✅ 支持 | 注意力机制 |
| **Transformer** | TransformerModel | ✅ 支持 | 需 GPU |
| | Localformer | ✅ 支持 | |
| **CNN** | TCN, TCTS | ✅ 支持 | |
| **高级** | TRAModel, HIST | ⚠️ 受限 | 需大量数据 |
| **RL** | Tianshou 集成 | ❌ 不支持 | numpy 版本冲突 |

#### 3.2.2 操作符

| 类别 | 操作符 | 状态 | 说明 |
|------|--------|------|------|
| 统计 (14) | Sum, Mean, Std, Var, Skew, Kurt... | ✅ 支持 | |
| 极值 (4) | Max, Min, IdxMax, IdxMin | ✅ 支持 | |
| 技术 (6) | EMA, WMA, Corr, Cov, Delta, Ref | ✅ 支持 | |
| 数学 (8) | Abs, Sign, Log, Power... | ✅ 支持 | |
| 逻辑 (13) | Greater, Less, And, Or, If... | ✅ 支持 | |
| **高频 (4)** | DayCumsum, DayLast, get_calendar_day/minute | ❌ 不支持 | **硬编码 A 股时间 (9:30-15:00, 240分钟)，无法简单适配** |
| 其他 (3) | TResample, NpElemOperator... | ✅ 支持 | |

> **重要**: 高频操作符不是"改个日历就能用"，其内部逻辑深度绑定 A 股交易时段。

#### 3.2.3 数据基础设施

| 组件 | 状态 | 实现方式 |
|------|------|----------|
| CalendarProvider | ✅ 支持 | 实现 CryptoCalendarProvider (24/7) |
| InstrumentProvider | ✅ 支持 | 实现 CryptoInstrumentProvider |
| Alpha158 | ⚠️ 受限 | 需适配窗口参数，使用日线或 4h 线 |
| Alpha360 | ⚠️ 受限 | 同上 |
| **数据转换** | ✅ 支持 | **必须使用官方 `dump_bin.py`** |
| 数据处理器 | ✅ 支持 | DropnaProcessor, ZscoreNorm 等直接可用 |

#### 3.2.4 回测与工作流

| 组件 | 状态 | 说明 |
|------|------|------|
| Exchange | ✅ 支持 | 实现 CryptoExchange (杠杆/资金费率) |
| SimulatorExecutor | ✅ 支持 | 适配永续合约 |
| Position | ✅ 支持 | 实现 PerpetualPosition |
| TaskManager | ✅ 支持 | 直接可用 |
| RollingGen | ✅ 支持 | 滚动训练 |
| OnlineManager | 🔜 后续 | 在线服务 |

### 3.3 Hummingbot 能力矩阵

#### 3.3.1 连接器

| 类型 | 连接器 | 状态 | 优先级 |
|------|--------|------|--------|
| **永续合约** | binance_perpetual | ✅ 支持 | **首选** |
| | bybit_perpetual | ✅ 支持 | 高 |
| | okx_perpetual | ✅ 支持 | 高 |
| | 其他 8 个 | 🔜 后续 | 低 |
| **现货** | binance, bybit, okx | ✅ 支持 | 高 |
| | 其他 23 个 | 🔜 后续 | 低 |

#### 3.3.2 执行器

| 执行器 | 状态 | 说明 |
|--------|------|------|
| PositionExecutor | ✅ 支持 | **首选**，含 Triple Barrier |
| OrderExecutor | ✅ 支持 | 简单订单 |
| TWAPExecutor | ✅ 支持 | 大单拆分 |
| DCAExecutor | 🔜 后续 | |
| GridExecutor | 🔜 后续 | |
| ArbitrageExecutor | 🔜 后续 | |
| XEMMExecutor | 🔜 后续 | |

#### 3.3.3 风控

| 功能 | 状态 | 说明 |
|------|------|------|
| Triple Barrier | ✅ 支持 | 止盈/止损/时间 |
| Kill Switch | ✅ 支持 | 紧急停止 |
| Position Limit | ✅ 支持 | 仓位限制 |
| Rate Limiter | ✅ 支持 | API 限速 |

### 3.4 适配工作量汇总

| 类别 | ✅ 支持 | ⚠️ 受限 | ❌ 不支持 | 🔜 后续 |
|------|---------|---------|----------|---------|
| Qlib 模型 | 25 | 2 | 1 (RL) | 4 |
| Qlib 操作符 | 48 | 0 | 4 (高频) | 0 |
| Qlib 基础设施 | 15 | 2 | 0 | 1 |
| Hummingbot 连接器 | 6 | 0 | 0 | 31 |
| Hummingbot 执行器 | 3 | 0 | 0 | 4 |

**最小闭环所需适配类 (7 个)**:

| 序号 | 类名 | 服务 | 继承/依赖 | 关键方法 |
|------|------|------|----------|----------|
| 1 | CryptoCalendarProvider | Research | `qlib.data.data.CalendarProvider` | `calendar()` → 24/7 UTC 时间戳 |
| 2 | CryptoInstrumentProvider | Research | `qlib.data.data.InstrumentProvider` | `instruments()` → 品种列表 |
| 3 | BinancePerpetualCollector | Research | `requests` | `collect()` → Parquet 文件 |
| 4 | CryptoExchange | Research | `qlib.backtest.exchange.Exchange` | `deal()`, `get_quote()` + 杠杆/资金费率 |
| 5 | PerpetualPosition | Research | `qlib.backtest.position.Position` | `update_order()` + 保证金计算 |
| 6 | SignalPublisher | Research | `paho-mqtt` | `publish()` → MQTT QoS 1 |
| 7 | SignalConsumer | Execution | `paho-mqtt` | `on_message()`, `_wait_for_connector_ready()`, `_is_duplicate()` |

**适配器类详细规格**:

| 类名 | 文件路径 | 代码行数估算 | 复杂度 |
|------|----------|-------------|--------|
| CryptoCalendarProvider | `research/algvex_research/data/calendar.py` | ~50 | 低 |
| CryptoInstrumentProvider | `research/algvex_research/data/instrument.py` | ~80 | 低 |
| BinancePerpetualCollector | `research/algvex_research/data/collector.py` | ~150 | 中 |
| CryptoExchange | `research/algvex_research/backtest/exchange.py` | ~300 | 高 |
| PerpetualPosition | `research/algvex_research/backtest/position.py` | ~200 | 中 |
| SignalPublisher | `research/algvex_research/signals/publisher.py` | ~60 | 低 |
| SignalConsumer | `execution/algvex_execution/consumer/signal_consumer.py` | ~250 | 高 |

> **总代码量估算**: ~1100 行核心代码 + ~500 行测试代码

---

## 四、文件结构

```
AlgVex/
├── libs/                              # Git Submodules (只读引用)
│   ├── qlib/                          # Qlib v0.9.7
│   └── hummingbot/                    # Hummingbot v2.11.0
│
├── research/                          # Research 服务代码
│   ├── Dockerfile                     # Python 3.10 环境
│   ├── requirements.txt
│   ├── algvex_research/
│   │   ├── __init__.py
│   │   ├── data/
│   │   │   ├── collector.py           # 只存 CSV/Parquet
│   │   │   ├── calendar.py            # CryptoCalendarProvider
│   │   │   ├── instrument.py          # CryptoInstrumentProvider
│   │   │   └── convert.py             # 调用 dump_bin.py 的封装
│   │   ├── factors/
│   │   │   ├── alpha158.py            # 窗口适配
│   │   │   └── custom.py              # 自定义因子
│   │   ├── backtest/
│   │   │   ├── exchange.py            # CryptoExchange
│   │   │   ├── position.py            # PerpetualPosition
│   │   │   └── funding.py             # 资金费率
│   │   ├── models/
│   │   │   └── trainer.py             # 模型训练
│   │   ├── signals/
│   │   │   └── publisher.py           # SignalPublisher (MQTT)
│   │   └── cli.py                     # 命令行入口
│   └── tests/
│
├── execution/                         # Execution 服务代码
│   ├── Dockerfile                     # Python 3.12 环境
│   ├── requirements.txt
│   ├── algvex_execution/
│   │   ├── __init__.py
│   │   ├── consumer/
│   │   │   ├── signal_consumer.py     # Async Consumer
│   │   │   ├── readiness_gate.py      # Connector 就绪检查
│   │   │   └── idempotency.py         # 幂等去重
│   │   ├── executor/
│   │   │   └── manager.py             # 执行器管理
│   │   ├── risk/
│   │   │   ├── kill_switch.py
│   │   │   └── position_limit.py
│   │   ├── reporter/
│   │   │   └── status_publisher.py    # 状态回报
│   │   └── cli.py
│   └── tests/
│
├── docker/
│   ├── docker-compose.yml             # 编排文件
│   ├── docker-compose.dev.yml         # 开发环境
│   └── docker-compose.prod.yml        # 生产环境
│
├── config/
│   ├── research.yaml                  # Research 服务配置
│   ├── execution.yaml                 # Execution 服务配置
│   └── exchanges/
│       ├── binance.yaml
│       └── bybit.yaml
│
├── data/                              # 数据目录 (挂载卷)
│   ├── raw/                           # 原始 CSV/Parquet
│   └── qlib_data/                     # Qlib 二进制格式
│
├── scripts/
│   ├── install.sh
│   ├── start.sh
│   └── convert_data.sh                # 调用 dump_bin.py
│
├── docs/
│   └── EXECUTION-PLAN.md              # 本文档
│
└── README.md
```

---

## 五、详细实现规范

### 5.1 数据层实现 (Research 服务)

#### 5.1.1 数据收集器 (只存原始数据)

```python
# research/algvex_research/data/collector.py
"""
数据收集器 - 只负责拉取原始数据并存储为 CSV/Parquet

重要: 不做任何格式转换，转换由官方 dump_bin.py 完成
"""
import pandas as pd
from pathlib import Path
from typing import List, Iterator
import requests
import time
import logging

logger = logging.getLogger(__name__)


class BinancePerpetualCollector:
    """币安永续合约数据收集器"""

    BASE_URL = "https://fapi.binance.com"
    RATE_LIMIT = 0.1  # 100ms between requests
    MAX_LIMIT = 1000  # Binance API 单次最大返回条数

    def __init__(self, output_dir: str = "./data/raw"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def collect(
        self,
        symbols: List[str],
        start_date: str,
        end_date: str,
        interval: str = "1h",
    ) -> Path:
        """
        收集数据并保存为 Parquet

        注意: 自动分页获取完整数据，不受 1000 条限制

        Returns:
            Path: 保存的文件路径
        """
        all_data = []

        for symbol in symbols:
            binance_symbol = symbol.replace("-", "")
            logger.info(f"Fetching {symbol} from {start_date} to {end_date}")

            # 使用分页迭代器获取完整数据
            for row in self._fetch_klines_paginated(
                binance_symbol, start_date, end_date, interval
            ):
                all_data.append({
                    # 统一使用 UTC 时区，以 open_time 为锚点
                    "date": pd.Timestamp(row[0], unit="ms", tz="UTC"),
                    "symbol": symbol,
                    "open": float(row[1]),
                    "high": float(row[2]),
                    "low": float(row[3]),
                    "close": float(row[4]),
                    "volume": float(row[5]),
                    "amount": float(row[7]),
                })

            logger.info(f"Fetched {len(all_data)} rows for {symbol}")

        df = pd.DataFrame(all_data)

        # 去重 (按 symbol + date)，保留最新
        df = df.drop_duplicates(subset=["symbol", "date"], keep="last")
        df = df.sort_values(["symbol", "date"]).reset_index(drop=True)

        # 保存为 Parquet (不是 Qlib 格式!)
        output_file = self.output_dir / f"crypto_{interval}_{start_date}_{end_date}.parquet"
        df.to_parquet(output_file, index=False)

        logger.info(f"Saved {len(df)} rows to {output_file}")
        return output_file

    def _fetch_klines_paginated(
        self, symbol: str, start: str, end: str, interval: str
    ) -> Iterator[list]:
        """
        分页获取 K 线数据 (解决 1000 条限制)

        Yields:
            list: 每条 K 线原始数据
        """
        start_ms = int(pd.Timestamp(start, tz="UTC").timestamp() * 1000)
        end_ms = int(pd.Timestamp(end, tz="UTC").timestamp() * 1000)
        current_start = start_ms

        while current_start < end_ms:
            data = self._fetch_klines_batch(symbol, current_start, end_ms, interval)

            if not data:
                break  # 无更多数据

            for row in data:
                yield row

            # 下一页起点 = 最后一条的 open_time + 1ms
            last_open_time = data[-1][0]
            current_start = last_open_time + 1

            # 如果返回不足 1000 条，说明已到末尾
            if len(data) < self.MAX_LIMIT:
                break

            time.sleep(self.RATE_LIMIT)

    def _fetch_klines_batch(
        self, symbol: str, start_ms: int, end_ms: int, interval: str
    ) -> list:
        """从币安 API 获取单批次 K 线 (最多 1000 条)"""
        url = f"{self.BASE_URL}/fapi/v1/klines"
        params = {
            "symbol": symbol,
            "interval": interval,
            "startTime": start_ms,
            "endTime": end_ms,
            "limit": self.MAX_LIMIT,
        }
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        return response.json()
```

#### 5.1.2 数据格式转换 (调用官方脚本)

```python
# research/algvex_research/data/convert.py
"""
数据格式转换 - 调用 Qlib 官方 dump_bin.py

重要: 不自造二进制格式，完全依赖官方脚本
"""
import subprocess
from pathlib import Path


class QlibDataConverter:
    """Qlib 数据格式转换器"""

    def __init__(self, qlib_path: str = "./libs/qlib"):
        self.dump_bin_script = Path(qlib_path) / "scripts" / "dump_bin.py"
        if not self.dump_bin_script.exists():
            raise FileNotFoundError(f"dump_bin.py not found: {self.dump_bin_script}")

    def convert(
        self,
        source_dir: str,
        target_dir: str,
        freq: str = "1h",
        date_field: str = "date",
        symbol_field: str = "symbol",
    ) -> bool:
        """
        调用官方 dump_bin.py 转换数据

        Args:
            source_dir: 原始数据目录 (CSV/Parquet)
            target_dir: Qlib 数据输出目录
            freq: 数据频率
            date_field: 日期字段名
            symbol_field: 品种字段名

        Returns:
            bool: 转换是否成功
        """
        cmd = [
            "python", str(self.dump_bin_script),
            "dump_all",
            f"--csv_path={source_dir}",
            f"--qlib_dir={target_dir}",
            f"--freq={freq}",
            f"--date_field_name={date_field}",
            f"--symbol_field_name={symbol_field}",
            "--include_fields=open,high,low,close,volume,amount",
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"转换失败: {result.stderr}")
            return False

        print(f"转换成功: {target_dir}")
        return True
```

#### 5.1.3 日历提供者 (24/7 + UTC)

```python
# research/algvex_research/data/calendar.py
"""
加密货币 24/7 日历提供者

继承: qlib.data.data.CalendarProvider
重要: 统一使用 UTC 时区
"""
from typing import List, Union
import pandas as pd
from qlib.data.data import CalendarProvider


class CryptoCalendarProvider(CalendarProvider):
    """24/7 加密货币交易日历"""

    FREQ_MAP = {
        "1min": "T", "5min": "5T", "15min": "15T",
        "30min": "30T", "1h": "H", "4h": "4H", "1d": "D",
    }

    def calendar(
        self,
        start_time: Union[str, pd.Timestamp],
        end_time: Union[str, pd.Timestamp],
        freq: str = "1h",
        future: bool = False,
    ) -> List[pd.Timestamp]:
        """生成连续时间戳 (无休市)"""
        if freq not in self.FREQ_MAP:
            raise ValueError(f"Unsupported freq: {freq}")

        # 统一使用 UTC 时区
        start = pd.Timestamp(start_time, tz="UTC")
        end = pd.Timestamp(end_time, tz="UTC")

        timestamps = pd.date_range(start=start, end=end, freq=self.FREQ_MAP[freq])

        if not future:
            now = pd.Timestamp.now(tz="UTC")
            timestamps = timestamps[timestamps <= now]

        return timestamps.tolist()
```

### 5.2 信号层实现

#### 5.2.1 信号发布者 (Research 服务)

```python
# research/algvex_research/signals/publisher.py
"""
信号发布者 - 发布到 MQTT (EMQX)
"""
import json
import uuid
from datetime import datetime, timezone
from typing import List, Dict
import paho.mqtt.client as mqtt


class SignalPublisher:
    """信号发布者 (MQTT)"""

    TOPIC = "algvex/signals"

    def __init__(self, broker_host: str = "emqx", broker_port: int = 1883):
        self.client = mqtt.Client(client_id=f"research-{uuid.uuid4().hex[:8]}")
        self.client.connect(broker_host, broker_port, keepalive=60)
        self.client.loop_start()

    def publish(self, signals: List[Dict]) -> List[str]:
        """
        发布信号到 MQTT

        Args:
            signals: 信号列表，每个信号包含:
                - symbol: 交易对
                - side: BUY/SELL
                - amount: 数量
                - score: 预测分数

        Returns:
            List[str]: signal_id 列表
        """
        signal_ids = []

        for signal in signals:
            signal_id = str(uuid.uuid4())
            message = {
                "signal_id": signal_id,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "symbol": signal["symbol"],
                "side": signal["side"],
                "amount": signal["amount"],
                "score": signal.get("score", 0),
            }

            # QoS 1: 至少一次投递
            self.client.publish(
                self.TOPIC,
                json.dumps(message),
                qos=1,
            )
            signal_ids.append(signal_id)

        return signal_ids

    def close(self):
        """关闭连接"""
        self.client.loop_stop()
        self.client.disconnect()
```

#### 5.2.2 信号消费者 (Execution 服务)

```python
# execution/algvex_execution/consumer/signal_consumer.py
"""
信号消费者 - MQTT + Readiness Gate + 幂等

这是信号桥的核心实现，包含生产级可靠性保障

关键设计:
1. 使用队列桥接 MQTT 回调线程和 asyncio 事件循环
2. 使用 SQLite 持久化幂等状态，重启不丢失
3. MQTT QoS 1 + 幂等 = 恰好一次语义
"""
import asyncio
import json
import logging
import queue
import sqlite3
import threading
from pathlib import Path
from typing import Dict, Optional
from datetime import datetime, timedelta, timezone
import paho.mqtt.client as mqtt

logger = logging.getLogger(__name__)


class IdempotencyStore:
    """
    幂等存储 (SQLite)

    使用 SQLite 持久化 signal_id，重启后状态不丢失。
    自动清理过期记录 (默认保留 24 小时)。
    """

    def __init__(self, db_path: str = "/data/idempotency/signals.db", ttl_hours: int = 24):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.ttl_hours = ttl_hours
        self._init_db()

    def _init_db(self):
        """初始化数据库"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS processed_signals (
                    signal_id TEXT PRIMARY KEY,
                    processed_at TEXT NOT NULL
                )
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_processed_at
                ON processed_signals(processed_at)
            """)

    def is_duplicate(self, signal_id: str) -> bool:
        """检查是否重复"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute(
                "SELECT 1 FROM processed_signals WHERE signal_id = ?",
                (signal_id,)
            )
            return cursor.fetchone() is not None

    def mark_processed(self, signal_id: str):
        """标记已处理"""
        now = datetime.now(timezone.utc).isoformat()
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT OR REPLACE INTO processed_signals (signal_id, processed_at) VALUES (?, ?)",
                (signal_id, now)
            )

    def cleanup_expired(self):
        """清理过期记录"""
        cutoff = (datetime.now(timezone.utc) - timedelta(hours=self.ttl_hours)).isoformat()
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "DELETE FROM processed_signals WHERE processed_at < ?",
                (cutoff,)
            )


class SignalConsumer:
    """
    信号消费者 (MQTT)

    关键特性:
    1. MQTT QoS 1 (至少一次)
    2. Connector Readiness Gate
    3. SQLite 持久化幂等 (重启安全)
    4. 队列桥接实现线程安全的 asyncio 调用
    """

    TOPIC = "algvex/signals"

    def __init__(
        self,
        broker_host: str,
        broker_port: int,
        connector,  # Hummingbot connector
        executor,   # Hummingbot executor
        idempotency_db: str = "/data/idempotency/signals.db",
    ):
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.connector = connector
        self.executor = executor

        # MQTT 客户端
        self.client = mqtt.Client(client_id="execution-worker")
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message

        # 幂等存储 (SQLite 持久化)
        self.idempotency = IdempotencyStore(idempotency_db)

        # 信号队列 (MQTT 回调线程 -> asyncio 工作线程)
        self._signal_queue: queue.Queue = queue.Queue()

        # asyncio 事件循环 (在独立线程运行)
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._loop_thread: Optional[threading.Thread] = None

        # 就绪状态
        self._connector_ready = False
        self._running = False

    def start(self):
        """启动消费者"""
        # 1. 等待 Connector 就绪
        self._wait_for_connector_ready()

        # 2. 启动 asyncio 工作线程
        self._start_async_worker()

        # 3. 连接 MQTT
        self.client.connect(self.broker_host, self.broker_port, keepalive=60)
        logger.info("SignalConsumer started")

        # 4. 阻塞运行 MQTT 循环
        self._running = True
        self.client.loop_forever()

    def stop(self):
        """停止消费者"""
        self._running = False
        self.client.disconnect()
        if self._loop:
            self._loop.call_soon_threadsafe(self._loop.stop)

    def _start_async_worker(self):
        """启动 asyncio 工作线程"""
        def run_loop():
            self._loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._loop)
            self._loop.run_until_complete(self._process_signals())

        self._loop_thread = threading.Thread(target=run_loop, daemon=True)
        self._loop_thread.start()

    async def _process_signals(self):
        """异步处理信号队列"""
        while self._running or not self._signal_queue.empty():
            try:
                # 非阻塞获取，超时后检查 _running
                data = await asyncio.get_event_loop().run_in_executor(
                    None, lambda: self._signal_queue.get(timeout=1.0)
                )
                await self._execute_signal_async(data)
            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"Signal processing error: {e}")

    def _on_connect(self, client, userdata, flags, rc):
        """连接成功回调"""
        if rc == 0:
            logger.info("Connected to MQTT broker")
            client.subscribe(self.TOPIC, qos=1)
        else:
            logger.error(f"MQTT connect failed: {rc}")

    def _on_message(self, client, userdata, msg):
        """
        消息回调 (在 MQTT 网络线程)

        只做轻量操作: 解析 JSON、检查幂等、入队
        重操作 (执行交易) 在 asyncio 工作线程完成
        """
        try:
            data = json.loads(msg.payload.decode())
            signal_id = data.get("signal_id")

            # 幂等检查 (SQLite 读取，轻量)
            if self.idempotency.is_duplicate(signal_id):
                logger.info(f"Duplicate signal, skip: {signal_id}")
                return

            # 入队等待处理 (不阻塞 MQTT 线程)
            self._signal_queue.put(data)
            logger.debug(f"Signal queued: {signal_id}")

        except Exception as e:
            logger.error(f"Message parse error: {e}")

    async def _execute_signal_async(self, data: Dict):
        """异步执行信号"""
        signal_id = data.get("signal_id")

        try:
            symbol = data["symbol"]
            side = data["side"]
            amount = float(data["amount"])

            # 调用 Hummingbot executor (异步)
            await self.executor.execute(
                symbol=symbol,
                side=side,
                amount=amount,
            )

            # 执行成功后标记已处理 (持久化)
            self.idempotency.mark_processed(signal_id)
            logger.info(f"Signal processed: {signal_id}")

            # 定期清理过期记录
            self.idempotency.cleanup_expired()

        except Exception as e:
            logger.error(f"Signal execution error: {signal_id}, {e}")
            # 执行失败不标记，下次重试

    def _wait_for_connector_ready(self):
        """
        Connector Readiness Gate

        等待以下条件全部满足:
        1. trading_rules 已加载
        2. 能获取价格
        3. leverage 设置已获取 (永续合约)
        """
        import time
        logger.info("Waiting for connector ready...")

        while True:
            try:
                if not self.connector.trading_rules:
                    logger.debug("Trading rules not ready")
                    time.sleep(1)
                    continue

                test_symbol = list(self.connector.trading_rules.keys())[0]
                price = self.connector.get_mid_price(test_symbol)
                if price is None or price <= 0:
                    logger.debug("Price not ready")
                    time.sleep(1)
                    continue

                if hasattr(self.connector, 'get_leverage'):
                    leverage = self.connector.get_leverage(test_symbol)
                    if leverage is None:
                        logger.debug("Leverage not ready")
                        time.sleep(1)
                        continue

                logger.info("Connector ready!")
                self._connector_ready = True
                break

            except Exception as e:
                logger.debug(f"Readiness check error: {e}")
                time.sleep(1)
```

### 5.3 Docker 编排

```yaml
# docker/docker-compose.yml
version: "3.8"

services:
  emqx:
    image: emqx:5
    ports:
      - "1883:1883"     # MQTT
      - "18083:18083"   # Dashboard
    environment:
      - EMQX_ALLOW_ANONYMOUS=true  # 开发环境，生产需配置认证
    volumes:
      - emqx_data:/opt/emqx/data
    healthcheck:
      test: ["CMD", "emqx", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  research:
    build:
      context: ../research
      dockerfile: Dockerfile
    depends_on:
      emqx:
        condition: service_healthy
    environment:
      - MQTT_BROKER=emqx
      - MQTT_PORT=1883
      - QLIB_DATA_DIR=/data/qlib_data
      - TZ=UTC
    volumes:
      - ../data:/data
      - ../libs:/libs:ro
    command: python -m algvex_research.cli run

  execution:
    build:
      context: ../execution
      dockerfile: Dockerfile
    depends_on:
      emqx:
        condition: service_healthy
    environment:
      - MQTT_BROKER=emqx
      - MQTT_PORT=1883
      - EXCHANGE=binance_perpetual
      - TZ=UTC
    volumes:
      - ../config:/config:ro
      - ../libs:/libs:ro
      - ../data/idempotency:/data/idempotency  # SQLite 持久化
    command: python -m algvex_execution.cli run
    restart: unless-stopped

volumes:
  emqx_data:
```

#### 5.3.1 Research Dockerfile

```dockerfile
# research/Dockerfile
FROM python:3.10-slim

WORKDIR /app

# 系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 应用代码
COPY algvex_research/ ./algvex_research/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PYTHONUNBUFFERED=1
ENV TZ=UTC

# Qlib 通过 volume 挂载，在 entrypoint 安装
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "-m", "algvex_research.cli", "run"]
```

**entrypoint.sh** (research/entrypoint.sh):
```bash
#!/bin/bash
set -e

# 安装 Qlib (从挂载的 /libs 目录)
if [ -d "/libs/qlib" ] && [ ! -f "/tmp/.qlib_installed" ]; then
    echo "Installing Qlib from /libs/qlib..."
    pip install -e /libs/qlib --quiet
    touch /tmp/.qlib_installed
fi

exec "$@"
```

#### 5.3.2 Research requirements.txt

```txt
# research/requirements.txt
# Qlib 核心依赖会通过 pip install -e 自动安装

# MQTT 通信
paho-mqtt>=1.6.1

# 数据处理
pyarrow>=14.0.0
requests>=2.31.0

# 配置
pyyaml>=6.0
python-dotenv>=1.0.0

# 日志
loguru>=0.7.0
```

#### 5.3.3 Execution Dockerfile

```dockerfile
# execution/Dockerfile
FROM python:3.12-slim

WORKDIR /app

# 系统依赖 (Hummingbot 需要)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 应用代码
COPY algvex_execution/ ./algvex_execution/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PYTHONUNBUFFERED=1
ENV TZ=UTC

# Hummingbot 通过 volume 挂载，在 entrypoint 安装
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "-m", "algvex_execution.cli", "run"]
```

**entrypoint.sh** (execution/entrypoint.sh):
```bash
#!/bin/bash
set -e

# 安装 Hummingbot (从挂载的 /libs 目录)
if [ -d "/libs/hummingbot" ] && [ ! -f "/tmp/.hummingbot_installed" ]; then
    echo "Installing Hummingbot from /libs/hummingbot..."
    pip install -e /libs/hummingbot --quiet
    touch /tmp/.hummingbot_installed
fi

exec "$@"
```

#### 5.3.4 Execution requirements.txt

```txt
# execution/requirements.txt
# Hummingbot 核心依赖会通过 pip install -e 自动安装

# MQTT 通信
paho-mqtt>=1.6.1

# 配置
pyyaml>=6.0
python-dotenv>=1.0.0

# 日志
loguru>=0.7.0
```

#### 5.3.5 Qlib 初始化配置

```python
# research/algvex_research/config/qlib_init.py
"""
Qlib 初始化配置

在任何 Qlib 操作前必须调用 init_qlib()
"""
import os
import qlib
from qlib.config import REG_CN  # 默认配置模板


def init_qlib(
    data_dir: str = None,
    freq: str = "1h",
):
    """
    初始化 Qlib

    Args:
        data_dir: Qlib 数据目录，默认从环境变量 QLIB_DATA_DIR 读取
        freq: 数据频率
    """
    if data_dir is None:
        data_dir = os.environ.get("QLIB_DATA_DIR", "./data/qlib_data")

    # 自定义 Provider (加密货币 24/7)
    custom_provider = {
        "calendar_provider": {
            "class": "algvex_research.data.calendar.CryptoCalendarProvider",
            "kwargs": {},
        },
        "instrument_provider": {
            "class": "algvex_research.data.instrument.CryptoInstrumentProvider",
            "kwargs": {},
        },
    }

    qlib.init(
        provider_uri=data_dir,
        region=REG_CN,  # 基础模板，会被 custom_provider 覆盖
        custom_ops=None,
        expression_cache=None,
        dataset_cache=None,
        **custom_provider,
    )

    print(f"Qlib initialized with data_dir={data_dir}, freq={freq}")


# 使用示例
if __name__ == "__main__":
    init_qlib()

    # 验证初始化成功
    from qlib.data import D
    instruments = D.instruments(market="all")
    print(f"Available instruments: {instruments}")
```

#### 5.3.6 交易所配置示例

```yaml
# config/exchanges/binance.yaml
# Binance 永续合约配置

exchange: binance_perpetual

# API 凭证 (生产环境建议使用环境变量)
api_key: ${BINANCE_API_KEY}
api_secret: ${BINANCE_API_SECRET}

# 交易设置
trading:
  # 交易对列表
  symbols:
    - BTC-USDT
    - ETH-USDT

  # 杠杆倍数
  leverage: 3

  # 仓位模式: "one-way" 或 "hedge"
  position_mode: one-way

# 风控设置
risk:
  # 最大仓位 (USD)
  max_position_usd: 10000

  # 单笔最大下单量 (USD)
  max_order_usd: 1000

  # Kill Switch: 日亏损达到此比例停止交易
  daily_loss_limit_pct: 0.05

  # Triple Barrier 默认值
  triple_barrier:
    take_profit_pct: 0.02
    stop_loss_pct: 0.01
    time_limit_hours: 24

# 网络设置
network:
  # 使用测试网 (Paper Trading)
  testnet: true

  # 请求超时 (秒)
  timeout: 30

  # 重试次数
  max_retries: 3
```

```yaml
# config/exchanges/binance_testnet.yaml
# Binance 测试网配置 (Paper Trading)

exchange: binance_perpetual

api_key: ${BINANCE_TESTNET_API_KEY}
api_secret: ${BINANCE_TESTNET_API_SECRET}

# 测试网 API 端点
base_url: https://testnet.binancefuture.com

trading:
  symbols:
    - BTC-USDT
  leverage: 1
  position_mode: one-way

risk:
  max_position_usd: 1000
  max_order_usd: 100
  daily_loss_limit_pct: 0.10

network:
  testnet: true
  timeout: 30
  max_retries: 3
```

### 5.4 数据质量规范

> 用"严格 UTC + open_time 对齐 + 可重复构建"的规则，彻底消除最难排查的时间错位/缺K/重复K问题

#### 5.4.1 核心硬规则（必须遵守）

| 规则 | 要求 | 说明 |
|------|------|------|
| **R0.1 全链路 UTC** | 所有时间戳必须是 UTC tz-aware | 禁止 `pd.Timestamp.now()` / `datetime.now()` 无时区 |
| **R0.2 open_time 锚点** | K 线时间戳以交易所 open_time 为准 | 不允许 date_range 覆盖真实锚点 |
| **R0.3 增量幂等** | 同一 instrument + open_time 必须 upsert | 重复拉取不产生重复K |

#### 5.4.2 字段标准

**K 线字段（从交易所映射）**:

| 字段 | 类型 | 说明 |
|------|------|------|
| open_time | int64 (ms) | UTC 时间戳，**唯一锚点** |
| close_time | int64 (ms) | 可选，用于一致性校验 |
| open, high, low, close | float64 | OHLC |
| volume | float64 | 成交量 |
| quote_volume (amount) | float64 | 成交额 |

**内部规范 DataFrame（进入 Qlib 前）**:

| 字段 | 类型 | 约束 |
|------|------|------|
| datetime | Timestamp (UTC) | 递增、唯一、对齐 open_time |
| instrument | str | 如 "BTC-USDT" |
| open, high, low, close, volume, amount | float64 | OHLC + 量额 |

#### 5.4.3 UTC 对齐规范

**唯一合法的时间戳转换方式**:

```python
# ✅ 正确
dt = pd.Timestamp(open_time_ms, unit="ms", tz="UTC")

# ❌ 禁止
pd.Timestamp(open_time_ms, unit="ms")           # 无 tz
pd.to_datetime(open_time_ms, unit="ms")         # 默认无 tz
datetime.fromtimestamp(open_time_ms/1000)       # 本地时区
```

**对齐校验（必须做）**:

| 频率 | 校验条件 |
|------|----------|
| 1h | `dt.minute == 0 and dt.second == 0` |
| 15m | `dt.minute % 15 == 0` |
| 5m | `dt.minute % 5 == 0` |
| 1m | `dt.second == 0` |

如果不满足 → 判定数据源/解析错误（常见于时区错位或用了 close_time）

**区间闭合性（统一左闭右开）**:

```
[start, end)
- startTime = start_open_time
- endTime = end_open_time（不包含 end 那根）
```

#### 5.4.4 增量更新规范

**水位线 (Watermark)**:

对每个 instrument 维护：
- `last_open_time_ms` (UTC ms)
- 存储：SQLite / JSON / Redis KV
- 只在"成功写入并通过校验"后推进

**回看窗口 (Lookback)**:

| 频率 | 建议回看 | 原因 |
|------|----------|------|
| 1h | 3-6 根 (3-6h) | 末端未收敛K |
| 1m | 120-300 根 (2-5h) | 重算/回补 |

```python
lookback_ms = max(3 * freq_ms, 2 * 3600 * 1000)
next_start = last_open_time_ms - lookback_ms
next_end = now_floor_to_freq_ms  # 已完成K的末端
```

**写入必须 Upsert/去重**:

```python
# 1. 拉取 df_new（可能含历史重叠）
# 2. 强制转换 UTC + 对齐校验
# 3. 以 (instrument, open_time_ms) 去重，保留最新
# 4. 排序后写入
# 5. 校验通过后更新 watermark
```

#### 5.4.5 缺口校验规范（建议实现）

**校验分层**:

| Level | 校验内容 | 建议 |
|-------|----------|------|
| L1 (轻量) | 预期日历 vs 实际数据缺口数量 | **默认开启** |
| L2 (中等) | + 重复K + OHLC 一致性 | 推荐 |
| L3 (重) | + 自动重拉缺口段 | 可选 |

**缺口阈值（1h 线一年约 8760 根）**:

| 阈值 | 处理 |
|------|------|
| <= 0.01% (<=1根) | 允许 |
| > 0.01% | 标记失败，自动重拉 3 次 |
| 仍失败 | **阻断训练/交易** |

#### 5.4.6 Qlib 对接契约

**必须保证**:
- calendar (UTC) 与 features 索引一致
- instruments 列表与 features 目录一致
- freq 全链路一致

**必须写进代码断言**:

```python
# 1. tz-aware
assert df.datetime.dt.tz is not None and str(df.datetime.dt.tz) == "UTC"

# 2. anchor
assert all(df.datetime == pd.to_datetime(df.open_time, unit="ms", utc=True))

# 3. alignment (1h)
assert all(df.datetime.dt.minute == 0)

# 4. unique
assert df.datetime.is_unique

# 5. monotonic
assert df.datetime.is_monotonic_increasing

# 6. OHLC sanity
assert all(df.high >= df[["open", "close"]].max(axis=1))
assert all(df.low <= df[["open", "close"]].min(axis=1))
assert all(df.volume >= 0)
```

#### 5.4.7 实施建议

**两层文件架构**:

```
data/
├── raw/                    # A) 真值表 (Parquet，带 open_time_ms)
│   └── crypto_1h_*.parquet
└── qlib_data/              # B) Qlib 格式 (由构建器生成，可重复构建)
    ├── calendars/
    ├── instruments/
    └── features/
```

**增量策略**:
- 增量只更新 raw layer
- qlib layer 定时重建最近 N 天窗口（如每小时 cron）
- 不要每次增量都手工写 bin

**关键原则**:
- 所有校验失败都必须阻断训练/交易
- 数据是地基，宁可停机也不要用错位/缺口数据

#### 5.4.8 默认配置

| 配置项 | 默认值 |
|--------|--------|
| time_zone | UTC (固定) |
| interval | 1h (试运行期) |
| lookback | 6h |
| gap_threshold_pct | 0.01% |
| max_gap_allowed | 1 (1h 线一年) |
| retry_gap_refetch | 3 |
| on_gap_fail | STOP_PIPELINE |

---

## 六、实施阶段

> 每个阶段包含详细子任务、交付物和依赖关系

### 阶段 1: 环境搭建 (基础设施)

**目标**: 搭建可运行的双容器开发环境

| 序号 | 子任务 | 交付物 | 验收标准 | 依赖 |
|------|--------|--------|----------|------|
| 1.1 | 创建目录结构 | `research/`, `execution/`, `docker/`, `config/` | 结构符合文档 | - |
| 1.2 | 编写 Research Dockerfile | `research/Dockerfile` | 构建成功，`import qlib` 通过 | 1.1 |
| 1.3 | 编写 Execution Dockerfile | `execution/Dockerfile` | 构建成功，`import hummingbot` 通过 | 1.1 |
| 1.4 | 编写 docker-compose.yml | `docker/docker-compose.yml` | `docker-compose up` 三服务启动 | 1.2, 1.3 |
| 1.5 | 编写 MQTT 测试脚本 | `scripts/test_mqtt.py` | paho-mqtt publish/subscribe 成功 | 1.4 |
| 1.6 | 编写开发环境配置 | `docker/docker-compose.dev.yml` | 热重载生效 | 1.4 |

**阶段 1 交付物检查清单**:
```bash
□ docker-compose build 成功 (无错误)
□ docker-compose up -d 三个容器运行
□ docker-compose exec research python -c "import qlib; print('OK')"
□ docker-compose exec execution python -c "import hummingbot; print('OK')"
□ 访问 http://localhost:18083 → EMQX Dashboard 可用
```

---

### 阶段 2: 数据层 (Research 服务)

**目标**: 实现数据收集、转换、日历、品种管理

| 序号 | 子任务 | 交付物 | 验收标准 | 依赖 |
|------|--------|--------|----------|------|
| 2.1 | 实现 BinancePerpetualCollector | `research/algvex_research/data/collector.py` | 拉取 BTC-USDT 1h 数据，保存 Parquet | 阶段 1 |
| 2.2 | 实现 dump_bin.py 封装 | `research/algvex_research/data/convert.py` | 调用官方脚本，转换成功 | 2.1 |
| 2.3 | 实现 CryptoCalendarProvider | `research/algvex_research/data/calendar.py` | 生成 24/7 UTC 时间戳列表 | 阶段 1 |
| 2.4 | 实现 CryptoInstrumentProvider | `research/algvex_research/data/instrument.py` | 返回品种列表 | 阶段 1 |
| 2.5 | 编写 Qlib 初始化配置 | `config/qlib_config.yaml` | `qlib.init()` 成功 | 2.2, 2.3, 2.4 |
| 2.6 | 编写数据层单元测试 | `research/tests/test_data.py` | pytest 全部通过 | 2.1-2.5 |
| 2.7 | 编写数据收集脚本 | `scripts/collect_data.sh` | 一键收集 + 转换 | 2.1, 2.2 |

**阶段 2 交付物检查清单**:
```bash
□ python collector.py --symbols BTC-USDT --start 2023-01-01 --end 2024-01-01
□ ls data/raw/*.parquet → 文件存在
□ python convert.py --source data/raw --target data/qlib_data
□ ls data/qlib_data/instruments/ → 文件存在
□ python -c "import qlib; qlib.init(...); from qlib.data import D; print(D.features(...))"
```

---

### 阶段 3: 模型层 (Research 服务)

**目标**: 实现因子计算、模型训练、回测框架

| 序号 | 子任务 | 交付物 | 验收标准 | 依赖 |
|------|--------|--------|----------|------|
| 3.1 | 适配 Alpha158 窗口参数 | `research/algvex_research/factors/alpha158.py` | 因子计算无 NaN | 阶段 2 |
| 3.2 | 实现 CryptoExchange | `research/algvex_research/backtest/exchange.py` | 支持杠杆、资金费率 | 阶段 2 |
| 3.3 | 实现 PerpetualPosition | `research/algvex_research/backtest/position.py` | 仓位计算正确 | 3.2 |
| 3.4 | 实现资金费率模块 | `research/algvex_research/backtest/funding.py` | 费率扣除正确 | 3.2 |
| 3.5 | 编写模型训练脚本 | `scripts/train_model.py` | LGBModel 训练成功 | 3.1 |
| 3.6 | 编写回测脚本 | `scripts/backtest.py` | 回测运行无错误 | 3.2, 3.3 |
| 3.7 | 编写模型评估报告 | `research/tests/test_model.py` | IC > 0.02 | 3.5 |

**阶段 3 交付物检查清单**:
```bash
□ python train_model.py → 模型保存成功
□ 训练日志显示 IC > 0.02
□ python backtest.py → 回测完成，生成报告
□ 回测报告包含 Sharpe, MaxDD, 收益曲线
```

---

### 阶段 4: 信号桥 (跨服务通信)

**目标**: 实现 Research → MQTT (EMQX) → Execution 的可靠通信

| 序号 | 子任务 | 交付物 | 验收标准 | 依赖 |
|------|--------|--------|----------|------|
| 4.1 | 实现 SignalPublisher | `research/algvex_research/signals/publisher.py` | MQTT publish QoS 1 成功 | 阶段 1 |
| 4.2 | 实现 SignalConsumer 框架 | `execution/algvex_execution/consumer/signal_consumer.py` | MQTT subscribe 回调成功 | 阶段 1 |
| 4.3 | 实现 Readiness Gate | `execution/algvex_execution/consumer/readiness_gate.py` | 检测 Connector 就绪 | 4.2 |
| 4.4 | 实现幂等去重 | `execution/algvex_execution/consumer/idempotency.py` | 重复 signal_id 跳过 | 4.2 |
| 4.5 | 实现状态回报 | `execution/algvex_execution/reporter/status_publisher.py` | 状态发布到 algvex/status | 4.2 |
| 4.6 | 编写信号桥集成测试 | `tests/integration/test_signal_bridge.py` | 端到端测试通过 | 4.1-4.5 |

**阶段 4 交付物检查清单**:
```bash
□ python publisher.py → EMQX Dashboard 显示 algvex/signals 有消息
□ python signal_consumer.py → 日志显示 "Signal processed"
□ 发送重复 signal_id → 日志显示 "Duplicate signal, skip"
□ EMQX Dashboard → Subscriptions 显示 execution-worker
□ mosquitto_sub -t "algvex/#" → 可监控所有消息
```

---

### 阶段 5: 执行层 (Execution 服务)

**目标**: 集成 Hummingbot 执行器和风控

| 序号 | 子任务 | 交付物 | 验收标准 | 依赖 |
|------|--------|--------|----------|------|
| 5.1 | 实现 Connector 管理器 | `execution/algvex_execution/connector/manager.py` | 初始化 Connector 成功 | 阶段 1 |
| 5.2 | 集成 PositionExecutor | `execution/algvex_execution/executor/manager.py` | 执行器可调用 | 5.1 |
| 5.3 | 实现 Kill Switch | `execution/algvex_execution/risk/kill_switch.py` | 触发条件后停止交易 | 5.1 |
| 5.4 | 实现 Position Limit | `execution/algvex_execution/risk/position_limit.py` | 超限拒绝订单 | 5.1 |
| 5.5 | 编写 Paper Trading 测试 | `scripts/paper_trading.py` | 连接 Testnet 成功 | 5.1, 5.2 |
| 5.6 | 编写执行层单元测试 | `execution/tests/test_executor.py` | pytest 全部通过 | 5.1-5.4 |
| 5.7 | 24 小时 Paper Trading | 监控日志 | 无错误、无崩溃 | 5.5 |

**阶段 5 交付物检查清单**:
```bash
□ Paper Trading 连接成功 (Testnet)
□ 发送测试信号 → 订单在 Testnet 成交
□ 触发 Kill Switch → 交易停止
□ 24 小时运行日志无 ERROR
```

---

### 阶段 6: 集成测试与上线

**目标**: 端到端验证，准备生产部署

| 序号 | 子任务 | 交付物 | 验收标准 | 依赖 |
|------|--------|--------|----------|------|
| 6.1 | 编写端到端测试 | `tests/integration/test_e2e.py` | 完整闭环测试通过 | 阶段 1-5 |
| 6.2 | 7 天 Paper Trading | 监控报告 | 稳定无错误 | 6.1 |
| 6.3 | 编写生产 docker-compose | `docker/docker-compose.prod.yml` | 生产配置完整 | 6.2 |
| 6.4 | 编写部署文档 | `docs/DEPLOYMENT.md` | 步骤清晰可执行 | 6.3 |
| 6.5 | 编写运维文档 | `docs/OPERATIONS.md` | 监控、故障处理 | 6.3 |
| 6.6 | 编写 README | `README.md` | 快速开始指南 | 6.4 |
| 6.7 | 代码审查 | 审查报告 | 无高风险问题 | 6.1-6.6 |

**阶段 6 交付物检查清单**:
```bash
□ 端到端测试: 数据 → 因子 → 模型 → 回测 → 信号 → 执行 → 状态回报
□ 7 天 Paper Trading 无 ERROR
□ docker-compose -f docker-compose.prod.yml up -d 成功
□ README.md 按步骤执行可复现
```

---

### 阶段依赖关系图

```
阶段 1 (环境搭建)
    │
    ├──────────────────┐
    ▼                  ▼
阶段 2 (数据层)    阶段 4.1-4.2 (信号桥基础)
    │                  │
    ▼                  │
阶段 3 (模型层)        │
    │                  │
    ▼                  ▼
阶段 4.3-4.6 ◄────── 阶段 5 (执行层)
    │                  │
    └────────┬─────────┘
             ▼
        阶段 6 (集成测试)
```

---

## 七、本地测试方案

### 7.1 测试环境

| 项目 | 要求 |
|------|------|
| Docker | 20.10+ |
| Docker Compose | 2.0+ |
| 内存 | >= 16GB |
| 磁盘 | >= 50GB |

### 7.2 测试命令

```bash
# 1. 构建镜像
docker-compose build

# 2. 启动服务
docker-compose up -d

# 3. 查看日志
docker-compose logs -f research
docker-compose logs -f execution

# 4. 运行测试
docker-compose exec research pytest tests/ -v
docker-compose exec execution pytest tests/ -v

# 5. 验证 MQTT (EMQX)
# 访问 Dashboard: http://localhost:18083 (默认 admin/public)
# 或使用 mosquitto 命令行工具监控消息:
mosquitto_sub -h localhost -t "algvex/#" -v

# 6. 停止服务
docker-compose down
```

### 7.3 测试检查清单

| 检查项 | 命令 | 通过标准 |
|--------|------|----------|
| EMQX 连接 | 访问 `http://localhost:18083` | Dashboard 可用 |
| Research 启动 | `docker-compose logs research` | 无错误 |
| Execution 启动 | `docker-compose logs execution` | Connector Ready |
| 数据收集 | 运行 collector | Parquet 文件生成 |
| 数据转换 | 运行 convert | qlib_data 目录生成 |
| 信号发布 | Dashboard → Topics | algvex/signals 有消息 |
| 信号消费 | 查看 Execution 日志 | Signal processed |

---

## 八、服务器部署方案

### 8.1 服务器要求

| 项目 | 最低配置 | 推荐配置 |
|------|----------|----------|
| CPU | 4 核 | 8 核 |
| 内存 | 16 GB | 32 GB |
| 磁盘 | 100 GB SSD | 500 GB SSD |
| 网络 | 100 Mbps | 1 Gbps |
| 系统 | Ubuntu 22.04 | Ubuntu 22.04 |

### 8.2 部署步骤

```bash
# 1. 安装 Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 2. 安装 Docker Compose
sudo apt install docker-compose-plugin

# 3. 克隆代码
git clone --recursive https://github.com/xxx/AlgVex.git
cd AlgVex

# 4. 配置交易所 API
cp config/exchanges/binance.yaml.example config/exchanges/binance.yaml
vim config/exchanges/binance.yaml  # 填入 API Key

# 5. 生产环境启动
docker-compose -f docker/docker-compose.prod.yml up -d

# 6. 查看状态
docker-compose ps
docker-compose logs -f
```

### 8.3 监控与运维

```bash
# 查看服务状态
docker-compose ps

# 查看资源使用
docker stats

# 查看 EMQX 状态
# 1. Dashboard: http://localhost:18083 (admin/public)
#    - Clients: 查看连接的客户端
#    - Subscriptions: 查看订阅关系
#    - Topics: 查看消息统计

# 2. 命令行监控所有消息
mosquitto_sub -h localhost -t "algvex/#" -v

# 重启服务
docker-compose restart execution

# 查看日志
docker-compose logs --tail=100 -f execution
```

---

## 九、验收标准

### 9.1 最小闭环验收

```
data → factor → train → backtest → signal → execution → risk → monitoring
  ✓       ✓        ✓        ✓          ✓          ✓         ✓        ✓
```

| 环节 | 验收标准 |
|------|----------|
| 数据收集 | BTC-USDT 1h 数据 >= 1 年 |
| 因子计算 | Alpha158 (适配窗口) 计算成功 |
| 模型训练 | LGBModel IC > 0.02 |
| 回测 | 完整运行无错误 |
| 信号发布 | MQTT 消息发布成功 (EMQX Dashboard 可见) |
| 信号消费 | 处理成功率 > 99% |
| 风控 | Kill Switch 触发正确 |
| 监控 | 状态回报正常 |

### 9.2 稳定性验收

| 指标 | 标准 |
|------|------|
| Paper Trading | 连续 7 天无错误 |
| 服务可用性 | > 99.9% |
| 消息丢失率 | 0% |
| 重复执行率 | 0% (幂等保证) |

### 9.3 性能验收

| 指标 | 标准 |
|------|------|
| 信号延迟 | 发布到执行 < 500ms |
| 模型推理 | < 100ms |
| 数据转换 | 1 年数据 < 10 分钟 |

---

## 十、风险偏差声明

> **重要**: 本系统回测与实盘存在以下偏差，仅供研究参考。

### 10.1 计算偏差

| 计算项 | 本系统实现 | 真实交易所 | 偏差影响 |
|--------|-----------|-----------|----------|
| **强平价格** | 简化公式 | 含保险基金/ADL/阶梯维持保证金 | 回测可能高估盈利 |
| **资金费率** | 历史快照 | 实时预测值 | 套利策略偏差 |
| **滑点** | 固定比例 (0.05%) | 深度加权真实滑点 | 大单执行失真 |
| **手续费** | Maker/Taker 固定 | 阶梯费率 + VIP 返佣 | 高频策略偏差 |
| **延迟** | 假设 0ms | 网络 + 交易所处理 | 高频策略失效 |

### 10.2 市场偏差

| 因素 | 说明 |
|------|------|
| 流动性 | 回测假设无限流动性，实盘大单影响价格 |
| 市场冲击 | 回测不考虑自身订单对市场的影响 |
| 行情延迟 | 回测使用收盘价，实盘使用实时价 |

### 10.3 使用建议

1. **回测结果打折**: 预期收益打 7 折，最大回撤放大 1.5 倍
2. **小资金验证**: 先用 1% 资金实盘验证 1 个月
3. **持续监控**: 实盘表现与回测偏差超过 30% 需重新评估

---

## 十一、交付物清单

| 交付物 | 说明 | 状态 |
|--------|------|------|
| Research 服务代码 | research/ 完整代码 | 待开发 |
| Execution 服务代码 | execution/ 完整代码 | 待开发 |
| Docker 编排文件 | docker-compose.yml | 待开发 |
| 配置文件模板 | config/*.yaml | 待开发 |
| 单元测试 | tests/ | 待开发 |
| 集成测试 | tests/integration/ | 待开发 |
| 部署文档 | README.md | 待开发 |
| 本文档 | EXECUTION-PLAN.md | ✅ 完成 |

---

## 附录 A: 参考资源

### 官方文档

| 资源 | 链接 |
|------|------|
| Qlib GitHub | https://github.com/microsoft/qlib |
| Qlib 文档 | https://qlib.readthedocs.io/ |
| Qlib dump_bin.py | https://github.com/microsoft/qlib/blob/main/scripts/dump_bin.py |
| Hummingbot GitHub | https://github.com/hummingbot/hummingbot |
| Hummingbot 文档 | https://hummingbot.org/docs/ |
| Quants Lab | https://github.com/hummingbot/quants-lab |
| Hummingbot Brokers | https://github.com/hummingbot/brokers |
| EMQX 文档 | https://www.emqx.io/docs/zh/latest/ |
| paho-mqtt | https://pypi.org/project/paho-mqtt/ |

### 本地源码路径

```
libs/
├── qlib/                              # Qlib v0.9.7
│   ├── qlib/
│   │   ├── contrib/model/             # 模型 (不含 RL)
│   │   ├── contrib/data/              # Alpha158, Alpha360
│   │   ├── data/ops.py                # 操作符 (不含高频)
│   │   └── backtest/                  # 回测框架
│   └── scripts/
│       └── dump_bin.py                # 官方数据转换脚本
│
└── hummingbot/                        # Hummingbot v2.11.0
    └── hummingbot/
        ├── connector/derivative/      # 永续连接器
        ├── strategy_v2/executors/     # 执行器
        └── core/                      # 异步核心
```

---

## 附录 B: 源码路径参考表

> 开发者需要经常查阅的源码位置

### Qlib 核心路径 (libs/qlib/)

| 模块 | 路径 | 关键文件/类 |
|------|------|-------------|
| **模型** | `qlib/contrib/model/` | |
| - 传统 ML | `gbdt.py`, `linear.py`, `xgboost.py`, `catboost_model.py` | LGBModel, XGBModel |
| - RNN | `pytorch_lstm.py`, `pytorch_gru.py`, `pytorch_alstm.py` | LSTM, GRU, ALSTM |
| - Transformer | `pytorch_transformer.py`, `pytorch_localformer.py` | TransformerModel |
| - CNN | `pytorch_tcn.py`, `pytorch_tcts.py` | TCN, TCTS |
| **操作符** | `qlib/data/ops.py` | Sum, Mean, EMA, Ref, Delta... |
| - 高频 (不可用) | `qlib/contrib/ops/high_freq.py` | DayCumsum, DayLast (硬编码 A 股) |
| **数据基础** | `qlib/data/data.py` | CalendarProvider, InstrumentProvider |
| **因子处理** | `qlib/contrib/data/handler.py` | Alpha158, Alpha360 |
| **数据处理器** | `qlib/contrib/data/processor.py` | DropnaProcessor, ZscoreNorm, CSRankNorm |
| **回测框架** | `qlib/backtest/` | |
| - 交易所 | `exchange.py` | Exchange 基类 |
| - 执行器 | `executor.py` | SimulatorExecutor, NestedExecutor |
| - 持仓 | `position.py` | Position 基类 |
| **工作流** | `qlib/workflow/` | |
| - 任务管理 | `task/manage.py` | TaskManager |
| - 滚动训练 | `task/gen.py` | RollingGen |
| - 在线服务 | `online/manager.py` | OnlineManager |
| **数据转换** | `scripts/dump_bin.py` | **必须使用此脚本** |
| **已有 Crypto** | `scripts/data_collector/crypto/collector.py` | CryptoCollector (CoinGecko) |

### Hummingbot 核心路径 (libs/hummingbot/)

| 模块 | 路径 | 关键文件/类 |
|------|------|-------------|
| **永续连接器** | `hummingbot/connector/derivative/` | |
| - Binance | `binance_perpetual/` | BinancePerpetualDerivative |
| - Bybit | `bybit_perpetual/` | BybitPerpetualDerivative |
| - OKX | `okx_perpetual/` | OkxPerpetualDerivative |
| - Gate.io | `gate_io_perpetual/` | GateIoPerpetualDerivative |
| **现货连接器** | `hummingbot/connector/exchange/` | |
| - Binance | `binance/` | BinanceExchange |
| **执行器** | `hummingbot/strategy_v2/executors/` | |
| - Position | `position_executor/` | PositionExecutor |
| - Order | `order_executor/` | OrderExecutor |
| - TWAP | `twap_executor/` | TWAPExecutor |
| **风控** | | |
| - Triple Barrier | `executors/position_executor/data_types.py` | TripleBarrierConfig |
| - Kill Switch | `hummingbot/core/rate_oracle/` | RateOracle |
| **异步核心** | `hummingbot/core/` | |
| - 时钟 | `clock.py` | Clock |
| - 事件 | `event/` | Event, EventForwarder |
| **数据源** | `hummingbot/data_feed/candles_feed/` | CandlesFactory |
| **策略基类** | `hummingbot/strategy_v2/` | StrategyV2Base |

### 依赖源码位置

| 文件 | 关键依赖 | 说明 |
|------|----------|------|
| `libs/qlib/pyproject.toml` | `numpy` (无限制), `pandas>=0.24` | 主依赖 |
| `libs/qlib/pyproject.toml` | `numpy<2.0.0` | 仅 `[rl]` 可选依赖 |
| `libs/hummingbot/setup.py` | `numpy>=2.2.6`, `pandas>=2.3.2` | 主依赖 |

---

## 附录 C: 常见问题排查

### C.1 环境问题

| 问题 | 症状 | 解决方案 |
|------|------|----------|
| **numpy 版本冲突** | `ImportError: numpy.core.multiarray failed to import` | 确保 Research 和 Execution 在不同容器中运行 |
| **Qlib 初始化失败** | `qlib.init() failed` | 检查 `QLIB_DATA_DIR` 路径是否存在且包含正确的 bin 文件 |
| **Hummingbot 启动失败** | `ModuleNotFoundError: No module named 'hummingbot'` | 检查 Dockerfile 中 `pip install -e libs/hummingbot` |

### C.2 数据问题

| 问题 | 症状 | 解决方案 |
|------|------|----------|
| **数据格式错误** | `ValueError: buffer size must be a multiple of element size` | 使用官方 `dump_bin.py`，不要自造 bin 格式 |
| **日期索引缺失** | `KeyError: 'datetime'` | 确保 Parquet 包含 `date` 字段且为 UTC 时区 |
| **日历不匹配** | `Calendar mismatch` | 使用 CryptoCalendarProvider (24/7) |
| **数据为空** | `D.features() returns empty` | 检查 instruments 文件是否包含正确的品种代码 |

### C.3 信号桥问题

| 问题 | 症状 | 解决方案 |
|------|------|----------|
| **MQTT 连接失败** | `ConnectionRefusedError` | 检查 EMQX 是否启动: `docker-compose logs emqx` |
| **订阅未生效** | Dashboard 无订阅者 | 检查 client_id 是否冲突，确认 `on_connect` 回调执行 |
| **消息未收到** | Consumer 无日志 | 检查 Topic 名称是否一致 (`algvex/signals`) |
| **重复执行** | 同一信号执行多次 | 检查幂等去重逻辑，QoS 1 可能重复投递 |

### C.4 执行问题

| 问题 | 症状 | 解决方案 |
|------|------|----------|
| **Connector 不就绪** | `Waiting for connector ready...` 持续输出 | 检查 API Key 是否正确，网络是否可达 |
| **交易失败** | `Order rejected` | 检查: 1) 余额是否充足 2) 交易对是否正确 3) 数量是否满足最小要求 |
| **价格获取失败** | `get_mid_price returns None` | 检查 WebSocket 连接，可能需要重启 Connector |
| **Kill Switch 触发** | 交易突然停止 | 查看 `kill_switch.py` 日志，检查触发条件 |

### C.5 调试命令

```bash
# 1. 检查 EMQX 状态
# 访问 Dashboard: http://localhost:18083 (admin/public)
# 查看: Clients, Subscriptions, Topics

# 2. 命令行监控所有消息
mosquitto_sub -h localhost -t "algvex/#" -v

# 3. 手动发送测试消息
mosquitto_pub -h localhost -t "algvex/signals" -m '{"signal_id":"test-123","symbol":"BTC-USDT","side":"BUY","amount":"0.01"}'

# 4. 查看 EMQX 容器日志
docker-compose logs emqx

# 5. 检查 Qlib 数据
docker-compose exec research python -c "
import qlib
qlib.init(provider_uri='./data/qlib_data')
from qlib.data import D
print(D.calendar(start_time='2024-01-01', end_time='2024-01-02', freq='1h'))
"

# 6. 检查 Hummingbot Connector
docker-compose exec execution python -c "
from hummingbot.connector.derivative.binance_perpetual.binance_perpetual_derivative import BinancePerpetualDerivative
print('Connector imported successfully')
"

# 7. 查看容器资源使用
docker stats --no-stream

# 8. 进入容器调试
docker-compose exec research bash
docker-compose exec execution bash
```

---

**文档版本**: 4.4
**创建日期**: 2025-12-31
**更新日期**: 2025-12-31
**更新历史**:
- v4.4: 生产级修复 - Collector分页、Dockerfile修复、asyncio线程安全、SQLite幂等持久化
- v4.3: 添加数据质量规范 (5.4) - UTC对齐、open_time锚点、增量幂等、缺口校验
- v4.2: 消息层改为 MQTT (EMQX) - 与 Hummingbot 生态对齐
- v4.1: 增强实施参考 - 源码路径、阶段子任务、适配器规格、故障排查
- v4.0: 架构重构 - 双容器分离、官方数据转换、能力矩阵、风险偏差
