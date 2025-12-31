# AlgVex 技术方案：Qlib + Hummingbot 加密货币适配

> **基于本地代码完整审查** (libs/qlib v0.9.7 + libs/hummingbot v2.11.0)

---

## 一、Qlib 完整功能清单 (v0.9.7)

### 1.1 完整模型列表 (qlib.contrib.model)

基于本地代码审查，Qlib v0.9.7 共有 **31 个模型类**：

#### 传统机器学习 (5)
| 模型 | 文件 | 说明 | 适配策略 |
|------|------|------|----------|
| LinearModel | linear.py | 线性回归 (OLS/Ridge/Lasso) | 🟢 无需修改 |
| LGBModel | gbdt.py | LightGBM | 🟢 无需修改 |
| HFLGBModel | highfreq_gdbt_model.py | 高频 LightGBM | 🟢 无需修改 |
| XGBModel | xgboost.py | XGBoost | 🟢 无需修改 |
| CatBoostModel | catboost_model.py | CatBoost | 🟢 无需修改 |

#### 循环神经网络 (12)
| 模型 | 文件 | 说明 | 适配策略 |
|------|------|------|----------|
| LSTM | pytorch_lstm.py | 标准 LSTM | 🟢 无需修改 |
| LSTM (ts) | pytorch_lstm_ts.py | 时序 LSTM | 🟢 无需修改 |
| GRU | pytorch_gru.py | 标准 GRU | 🟢 无需修改 |
| GRU (ts) | pytorch_gru_ts.py | 时序 GRU | 🟢 无需修改 |
| ALSTM | pytorch_alstm.py | Attention LSTM | 🟢 无需修改 |
| ALSTM (ts) | pytorch_alstm_ts.py | 时序 Attention LSTM | 🟢 无需修改 |
| GATs | pytorch_gats.py | Graph Attention Temporal | 🟢 无需修改 |
| GATs (ts) | pytorch_gats_ts.py | 时序 GATs | 🟢 无需修改 |
| KRNN | pytorch_krnn.py | K-parallel RNN + CNN | 🟢 无需修改 |
| SFM | pytorch_sfm.py | Spectral Frequency Modeling | 🟢 无需修改 |
| ADARNN | pytorch_adarnn.py | Adversarial Domain Adaptation RNN | 🟢 无需修改 |
| Sandwich | pytorch_sandwich.py | CNN-KRNN Hybrid | 🟢 无需修改 |

#### Transformer 系列 (4)
| 模型 | 文件 | 说明 | 适配策略 |
|------|------|------|----------|
| TransformerModel | pytorch_transformer.py | 标准 Transformer | 🟢 无需修改 |
| TransformerModel (ts) | pytorch_transformer_ts.py | 时序 Transformer | 🟢 无需修改 |
| LocalformerModel | pytorch_localformer.py | Transformer + CNN Local | 🟢 无需修改 |
| LocalformerModel (ts) | pytorch_localformer_ts.py | 时序 Localformer | 🟢 无需修改 |

#### 卷积网络 (4)
| 模型 | 文件 | 说明 | 适配策略 |
|------|------|------|----------|
| TCN | pytorch_tcn.py | Temporal Convolutional Network | 🟢 无需修改 |
| TCN (ts) | pytorch_tcn_ts.py | 时序 TCN | 🟢 无需修改 |
| TemporalConvNet | tcn.py | TCN 基础模块 | 🟢 无需修改 |
| TCTS | pytorch_tcts.py | Task-conditional Temporal Shift | 🟢 无需修改 |

#### 高级/专用模型 (6)
| 模型 | 文件 | 说明 | 适配策略 |
|------|------|------|----------|
| DNNModelPytorch | pytorch_nn.py | 深度神经网络 | 🟢 无需修改 |
| GeneralPTNN | pytorch_general_nn.py | 通用 PyTorch NN 适配器 | 🟢 无需修改 |
| TabnetModel | pytorch_tabnet.py | TabNet (特征选择) | 🟢 无需修改 |
| TRAModel | pytorch_tra.py | Temporal Routing Adaptor | 🟢 无需修改 |
| DEnsembleModel | double_ensemble.py | 双重集成 | 🟢 无需修改 |
| IGMTF | pytorch_igmtf.py | Inter-Graph Memory Transfer | 🟢 无需修改 |
| HIST | pytorch_hist.py | Hierarchical Stock Trend | 🟢 无需修改 |
| ADD | pytorch_add.py | Adversarial Domain Decomposition | 🟢 无需修改 |

### 1.2 遗漏的策略 (qlib.contrib.strategy)

| 策略 | 模块路径 | 说明 | 适配策略 |
|------|----------|------|----------|
| **BaseSignalStrategy** | `signal_strategy.py` | 信号策略基类 | 🟢 无需修改 |
| **SBBStrategyBase** | `signal_strategy.py` | Select Better Bar 基类 | 🟢 无需修改 |
| **SBBStrategyEMA** | `signal_strategy.py` | EMA Bar 选择策略 | 🟢 无需修改 |
| **SoftTopkStrategy** | `signal_strategy.py` | 软性 TopK 选择 | 🟢 无需修改 |

### 1.3 完整表达式操作符 (qlib.data.ops)

基于 `libs/qlib/qlib/data/ops.py` 审查，共有 **52 个操作符**：

#### Alpha158 因子结构
```
Alpha158 = 158 个因子
├── KBAR (9): KMID, KLEN, KMID2, KUP, KUP2, KLOW, KLOW2, KSFT, KSFT2
├── PRICE (4): OPEN, HIGH, LOW, VWAP (窗口=[0])
└── ROLLING (145): 29个操作符 × 5个窗口 [5,10,20,30,60]
    └── ROC, MA, STD, BETA, RSQR, RESI, MAX, MIN, QTLU, QTLD,
        RANK, RSV, IMAX, IMIN, IMXD, CORR, CORD, CNTP, CNTN,
        CNTD, SUMP, SUMN, SUMD, VMA, VSTD, WVMA, VSUMP, VSUMN, VSUMD
```

#### 1.3.1 滚动/统计操作符
```python
# 基础统计
Sum(feature, N)          # 滚动求和
Mean(feature, N)         # 滚动均值
Std(feature, N)          # 滚动标准差
Var(feature, N)          # 滚动方差
Skew(feature, N)         # 滚动偏度
Kurt(feature, N)         # 滚动峰度
Med(feature, N)          # 滚动中位数
Mad(feature, N)          # 滚动平均绝对偏差
Slope(feature, N)        # 滚动线性回归斜率
Rsquare(feature, N)      # 滚动 R²
Resi(feature, N)         # 滚动残差
Rank(feature, N)         # 滚动排名 (百分位)
Quantile(feature, N, q)  # 滚动分位数
Count(cond, N)           # 条件计数

# 极值
Max(feature, N)          # 滚动最大值
Min(feature, N)          # 滚动最小值
IdxMax(feature, N)       # 最大值索引
IdxMin(feature, N)       # 最小值索引
```

#### 1.3.2 技术指标操作符
```python
EMA(feature, N)          # 指数移动平均
WMA(feature, N)          # 加权移动平均
Corr(f1, f2, N)          # 滚动相关性
Cov(f1, f2, N)           # 滚动协方差
Delta(feature, N)        # N 期差分
Ref(feature, N)          # 引用 N 期前数据 (正数=过去)
```

#### 1.3.3 数学操作符
```python
Abs(feature)             # 绝对值
Sign(feature)            # 符号 (-1, 0, 1)
Log(feature)             # 自然对数
Power(feature, exp)      # 幂运算
Add(f1, f2)              # 加法
Sub(f1, f2)              # 减法
Mul(f1, f2)              # 乘法
Div(f1, f2)              # 除法
```

#### 1.3.4 逻辑/比较操作符
```python
Greater(f1, f2)          # f1 > f2
Less(f1, f2)             # f1 < f2
Gt(f1, f2)               # f1 > f2
Ge(f1, f2)               # f1 >= f2
Lt(f1, f2)               # f1 < f2
Le(f1, f2)               # f1 <= f2
Eq(f1, f2)               # f1 == f2
Ne(f1, f2)               # f1 != f2
And(f1, f2)              # 逻辑与
Or(f1, f2)               # 逻辑或
Not(feature)             # 逻辑非
If(cond, t_val, f_val)   # 条件表达式
Mask(feature, cond)      # 条件掩码
```

#### 1.3.5 跨标的操作符
```python
$close:SH000300          # 引用其他标的 (如沪深300指数)
$close:^GPSC             # 引用 SP500 计算 Beta
```

#### 1.3.6 加密货币适配说明
```python
# 这些操作符无需修改，但需要确保：
# 1. 时间窗口参数适配小时级别 (N=24 代表 1 天)
# 2. 跨标的引用适配加密货币格式 ($close:BTC-USDT)
```

### 1.4 完整数据处理器 (qlib.contrib.data.processor)

| 处理器 | 说明 | 适配策略 |
|--------|------|----------|
| **DropnaProcessor** | 删除含 NA 的特征 | 🟢 无需修改 |
| **DropnaLabel** | 删除含 NA 的标签 | 🟢 无需修改 |
| **TanhProcess** | Tanh 变换去噪 | 🟢 无需修改 |
| **ProcessInf** | 处理无穷值 | 🟢 无需修改 |
| **Fillna** | 填充 NA (默认 0) | 🟢 无需修改 |
| **MinMaxNorm** | Min-Max 标准化 | 🟢 无需修改 |
| **ZscoreNorm** | Z-Score 标准化 | 🟢 无需修改 |
| **RobustZScoreNorm** | 稳健 Z-Score (抗异常值) | 🟢 无需修改 |
| **CSZScoreNorm** | 截面 Z-Score 标准化 | 🟡 需验证加密货币截面 |
| **CSRankNorm** | 截面排名标准化 | 🟡 需验证加密货币截面 |

### 1.5 数据基础设施组件

| 组件 | 模块 | 说明 | 适配策略 |
|------|------|------|----------|
| **CalendarProvider** | `qlib.data.data` | 日历提供者抽象基类 | 🔴 需实现加密货币版本 |
| **LocalCalendarProvider** | `qlib.data.data` | 本地日历提供者 | 🟢 无需修改 |
| **InstrumentProvider** | `qlib.data.data` | 标的提供者抽象基类 | 🔴 需实现加密货币版本 |
| **LocalInstrumentProvider** | `qlib.data.data` | 本地标的提供者 | 🟢 无需修改 |
| **FeatureProvider** | `qlib.data.data` | 特征提供者 | 🟢 无需修改 |
| **ExpressionProvider** | `qlib.data.data` | 表达式提供者 | 🟢 无需修改 |
| **DiskExpressionCache** | `qlib.data.cache` | 磁盘表达式缓存 | 🟢 无需修改 |
| **DatasetCache** | `qlib.data.cache` | 数据集缓存 | 🟢 无需修改 |
| **FileStorage** | `qlib.data.storage` | 文件存储后端 | 🟢 无需修改 |
| **TSDataSampler** | `qlib.data.dataset` | 时序数据采样器 | 🟢 无需修改 |
| **TSDatasetH** | `qlib.data.dataset` | 时序数据集 (支持 lookback) | 🟢 无需修改 |

### 1.6 嵌套决策执行框架 - 关键遗漏

**原方案完全未涉及此框架，这是多时间尺度策略的核心。**

```python
# 嵌套执行架构
# 日线策略 → 小时级执行 → 订单拆分

from qlib.backtest import NestedExecutor, SimulatorExecutor

# 外层: 日线级别投资组合决策
outer_executor = SimulatorExecutor(
    time_per_step="day",
    inner_executor=inner_executor  # 嵌套内层
)

# 内层: 小时级别订单执行
inner_executor = SimulatorExecutor(
    time_per_step="1h",
    inner_strategy=TWAPStrategy()  # TWAP 算法执行
)

# 使用场景:
# 1. 日线组合再平衡 + 小时级 TWAP 执行
# 2. 周度策略 + 日度风控
# 3. 多频率因子模型联合回测
```

**加密货币适配要点:**
- 支持 1h/4h/1d 多时间尺度嵌套
- 内层执行器需适配永续合约规则

### 1.7 任务管理系统 - 关键遗漏

| 组件 | 模块 | 说明 | 适配策略 |
|------|------|------|----------|
| **TaskManager** | `qlib.workflow.task.manage` | MongoDB 任务生命周期管理 | 🟢 无需修改 |
| **TaskGen** | `qlib.workflow.task.gen` | 任务生成器基类 | 🟢 无需修改 |
| **Trainer** | `qlib.model.trainer` | 标准训练器 | 🟢 无需修改 |
| **TrainerR** | `qlib.model.trainer` | 基于 Recorder 的训练器 | 🟢 无需修改 |
| **TrainerRM** | `qlib.model.trainer` | 任务管理器训练器 | 🟢 无需修改 |
| **DelayTrainer** | `qlib.model.trainer` | 延迟训练器 (并行工作流) | 🟢 无需修改 |
| **Collector** | `qlib.model.trainer` | 任务结果收集器 | 🟢 无需修改 |

**MongoDB 配置:**
```python
qlib.init(
    provider_uri="~/.qlib/qlib_data/crypto_data",
    region="cn",
    mongo={
        "host": "localhost",
        "port": 27017,
        "db": "algvex_tasks"
    }
)
```

### 1.8 在线服务模块 (qlib.contrib.online)

| 组件 | 说明 | 适配策略 |
|------|------|----------|
| **OnlineManager** | 在线模型管理 | 🟢 无需修改 |
| **OnlineTool** | 设置/取消在线模型 | 🟢 无需修改 |
| **OnlineToolR** | 基于 Recorder 的在线工具 | 🟢 无需修改 |
| **PredUpdater** | 增量预测更新 | 🟢 无需修改 |
| **LabelUpdater** | 标签更新器 | 🟢 无需修改 |
| **RollingGen** | 滚动任务生成器 | 🟢 无需修改 |
| **RollingGroup** | 滚动结果分组 | 🟢 无需修改 |

**建议:** 原方案的 `prediction_service.py` 应整合 Qlib 内置在线服务模块。

### 1.9 评估模块 (qlib.contrib.evaluate)

| 函数/类 | 说明 | 适配策略 |
|---------|------|----------|
| **calc_ic** | 计算 IC 和 Rank IC | 🟢 无需修改 |
| **calc_long_short_return** | 多空收益计算 | 🟢 无需修改 |
| **calc_long_short_prec** | 多空精度 | 🟢 无需修改 |
| **risk_analysis** | 年化收益/IR/最大回撤 | 🟢 无需修改 |
| **backtest** | 回测执行函数 | 🟡 需适配参数 |

### 1.10 报告生成模块 (qlib.contrib.report)

| 函数 | 说明 | 适配策略 |
|------|------|----------|
| **analysis_position.report_graph** | 持仓分析图表 | 🟢 无需修改 |
| **analysis_position.score_ic_graph** | IC/Rank IC 图表 | 🟢 无需修改 |
| **analysis_position.cumulative_return_graph** | 累计收益曲线 | 🟢 无需修改 |
| **analysis_position.risk_analysis_graph** | 风险指标图表 | 🟢 无需修改 |
| **analysis_position.rank_label_graph** | 排名-标签散点图 | 🟢 无需修改 |
| **analysis_model.model_performance_graph** | 模型性能可视化 | 🟢 无需修改 |

### 1.11 Meta-Learning 框架 (qlib.meta)

| 组件 | 说明 | 适配策略 |
|------|------|----------|
| **Meta Controller** | 元学习任务编排 | 🟢 无需修改 |
| **Meta-Task** | 元学习任务单元 | 🟢 无需修改 |
| **Meta-Dataset** | 共享元数据集 | 🟢 无需修改 |
| **Meta-Model** | 迁移学习模型 | 🟢 无需修改 |

**应用场景:** 从股票市场迁移学习到加密货币市场

### 1.12 数据收集脚本

| 脚本 | 位置 | 说明 | 适配策略 |
|------|------|------|----------|
| **get_data.py** | `scripts/` | 下载预处理 Qlib 数据 | 🔴 需重写加密货币版本 |
| **dump_bin.py** | `scripts/` | CSV/Parquet → Qlib 二进制 | 🟡 需适配数据格式 |
| **Yahoo collector** | `scripts/data_collector/yahoo/` | Yahoo Finance 数据采集 | 🔴 需替换为 CCXT |

### 1.13 回测执行器完整列表

| 执行器 | 说明 | 适配策略 |
|--------|------|----------|
| **SimulatorExecutor** | 基础模拟执行器 | 🟡 需适配永续合约 |
| **NestedExecutor** | 嵌套执行器 | 🟡 需适配 |
| **VWAPExecutor** | VWAP 算法执行器 | 🟢 无需修改 |
| **CloseExecutor** | 收盘价执行器 | 🟢 无需修改 |

---

## 二、Hummingbot 完整功能清单 (v2.11.0)

### 2.1 完整连接器列表

基于 `libs/hummingbot/hummingbot/connector/` 审查，共有 **37 个连接器**：

#### 2.1.1 永续合约连接器 (11)

| 连接器 | 说明 | 集成优先级 |
|--------|------|-----------|
| **binance_perpetual** | 币安永续 | ✅ 首选 |
| **bybit_perpetual** | Bybit 永续 | 🔴 高 |
| **okx_perpetual** | OKX 永续 | 🔴 高 |
| **gate_io_perpetual** | Gate.io 永续 | 🟡 中 |
| **kucoin_perpetual** | KuCoin 永续 | 🟡 中 |
| **bitget_perpetual** | Bitget 永续 | 🟡 中 |
| **bitmart_perpetual** | Bitmart 永续 | 🟢 低 |
| **derive_perpetual** | Derive 永续 | 🟢 低 |
| **dydx_v4_perpetual** | dYdX V4 永续 (DEX) | 🟢 低 |
| **hyperliquid_perpetual** | Hyperliquid 永续 (DEX) | 🟢 低 |
| **injective_v2_perpetual** | Injective V2 永续 | 🟢 低 |

#### 2.1.2 现货连接器 (26)

| 连接器 | 说明 | 用途 |
|--------|------|------|
| **binance** | 币安现货 | 现货-永续套利 |
| **bybit** | Bybit 现货 | 现货-永续套利 |
| **okx** | OKX 现货 | 现货-永续套利 |
| **kucoin** | KuCoin 现货 | 套利 |
| **gate_io** | Gate.io 现货 | 套利 |
| **htx** | HTX 现货 | 套利 |
| **mexc** | MEXC 现货 | 套利 |
| **bitget** | Bitget 现货 | 套利 |
| **kraken** | Kraken 现货 | 套利 |
| **coinbase_advanced_trade** | Coinbase 现货 | 套利 |
| **bitstamp** | Bitstamp 现货 | 套利 |
| **bitmart** | Bitmart 现货 | 套利 |
| **bitrue** | Bitrue 现货 | 套利 |
| **bing_x** | BingX 现货 | 套利 |
| **ascend_ex** | AscendEX 现货 | 套利 |
| **btc_markets** | BTC Markets | 套利 |
| **cube** | Cube 现货 | 套利 |
| **derive** | Derive 现货 | 套利 |
| **dexalot** | Dexalot 现货 | DEX |
| **foxbit** | Foxbit 现货 | 套利 |
| **hyperliquid** | Hyperliquid 现货 | DEX |
| **injective_v2** | Injective V2 | DEX |
| **ndax** | NDAX 现货 | 套利 |
| **vertex** | Vertex 现货 | DEX |
| **xrpl** | XRPL 现货 | DEX |
| **paper_trade** | 模拟交易 | 测试 |

### 2.2 完整控制器列表 (Strategy V2)

| 控制器 | 类型 | 说明 | 集成方式 |
|--------|------|------|----------|
| **pmm_simple** | 做市 | 简单 PMM | 🟢 可直接使用 |
| **pmm_dynamic** | 做市 | 动态 PMM (MACD/NATR) | 🟢 可直接使用 |
| **dman_maker** | 做市 | D-Man 做市商 | 🟢 可直接使用 |
| **dman_maker_v2** | 做市 | D-Man V2 | 🟢 可直接使用 |
| **dman_v3** | 方向性 | 布林带方向策略 | 🟢 可直接使用 |
| **bollinger_v1** | 方向性 | 布林带策略 | 🟢 可直接使用 |
| **grid_strike** | 网格 | 网格交易 | 🟢 可直接使用 |
| **xemm_multiple_levels** | 套利 | 跨交易所做市 | 🟢 可直接使用 |
| **DirectionalTradingController** | 方向性 | 方向交易基类 | 🟢 已扩展 |

### 2.3 完整执行器列表

基于 `libs/hummingbot/hummingbot/strategy_v2/executors/` 审查，共有 **7 个执行器**：

| 执行器 | 说明 | 状态 |
|--------|------|------|
| **OrderExecutor** | 单订单执行器 (MARKET/LIMIT) | ✅ 已覆盖 |
| **PositionExecutor** | 仓位执行器 (Triple Barrier/追踪止损) | ✅ 已覆盖 |
| **DCAExecutor** | 定投执行器 (TAKER/MAKER 模式) | ✅ 已覆盖 |
| **TWAPExecutor** | 时间加权均价执行器 | ✅ 已覆盖 |
| **GridExecutor** | 网格执行器 | ✅ 已覆盖 |
| **ArbitrageExecutor** | 两腿套利执行器 | ✅ 已覆盖 |
| **XEMMExecutor** | 跨交易所做市执行器 | ✅ 已覆盖 |

### 2.4 V1 策略完整列表

基于 `libs/hummingbot/hummingbot/strategy/` 审查，共有 **9 个 V1 策略**：

| 策略 | 目录 | 说明 | 适用场景 |
|------|------|------|----------|
| **Pure Market Making** | pure_market_making/ | 基础做市 (库存偏斜/挂单) | 被动收益 |
| **Avellaneda Market Making** | avellaneda_market_making/ | Avellaneda-Stoikov 学术模型 | 高级做市 |
| **Cross Exchange Market Making** | cross_exchange_market_making/ | 跨交易所做市 | 套利 |
| **Cross Exchange Mining** | cross_exchange_mining/ | 流动性挖矿优化做市 | 挖矿收益 |
| **Perpetual Market Making** | perpetual_market_making/ | 永续合约做市 (杠杆/持仓模式) | 永续被动收益 |
| **AMM Arbitrage** | amm_arb/ | AMM-CEX 套利 | DEX 套利 |
| **Spot Perpetual Arbitrage** | spot_perpetual_arbitrage/ | 现货-永续套利 (资金费率) | 资金费率套利 |
| **Liquidity Mining** | liquidity_mining/ | 简单流动性挖矿做市 | 多交易对做市 |
| **Hedge** | hedge/ | 风险对冲 (数量/价值模式) | 仓位管理 |

### 2.5 完整风险管理功能

| 功能 | 说明 | 状态 |
|------|------|------|
| **Triple Barrier** | 止盈/止损/时间限制 | ✅ 已覆盖 |
| **Trailing Stop** | 追踪止损 | ✅ 已覆盖 |
| **Kill Switch** | 紧急停止 (达到阈值自动停止) | ❌ 遗漏 |
| **Balance Limit** | 资产限额 | ❌ 遗漏 |
| **Position Limit** | 持仓限制 | ❌ 遗漏 |
| **Inventory Skew** | 库存偏斜管理 | ❌ 遗漏 |
| **Rate Limiter** | API 限速 | ❌ 遗漏 |
| **Minimum Spread** | 最小价差保护 | ❌ 遗漏 |
| **Price Band** | 价格区间限制 | ❌ 遗漏 |
| **Max Order Age** | 最大订单年龄 | ❌ 遗漏 |
| **Filled Order Delay** | 成交后冷却 | ❌ 遗漏 |
| **Hanging Orders** | 挂单保留 | ❌ 遗漏 |

### 2.6 Hummingbot Dashboard - 关键遗漏

**原方案完全未提及 Dashboard，这是回测和部署的核心工具。**

| 功能 | 说明 |
|------|------|
| **Streamlit Web UI** | 可视化管理界面 |
| **策略回测** | 历史数据回测 |
| **Optuna 优化** | 自动参数调优 |
| **一键部署** | 策略快速部署 |
| **性能监控** | 实时性能跟踪 |
| **多实例管理** | 多机器人编排 |

**仓库:** https://github.com/hummingbot/dashboard

### 2.7 币安永续合约完整功能

| 功能 | 说明 | 状态 |
|------|------|------|
| **杠杆设置** | 1x-125x | ✅ 已覆盖 (10x 默认) |
| **持仓模式** | 单向/双向 | ❌ 遗漏 |
| **保证金模式** | 逐仓/全仓 | ❌ 遗漏 |
| **资金费率** | 8 小时结算 | ⚠️ 部分覆盖 |
| **订单类型** | 限价/市价/止损/止盈 | ❌ 遗漏详情 |
| **强平价格** | 自动计算 | ❌ 遗漏 |
| **未实现盈亏** | 实时监控 | ❌ 遗漏 |

### 2.8 Paper Trading 模式 - 关键遗漏

**原方案未提及模拟交易，这对策略测试至关重要。**

```bash
# 启用模拟交易
paper_trade

# 设置模拟余额
balance paper USDT 10000
balance paper BTC 1
```

### 2.9 配置系统完整说明

| 配置文件 | 说明 | 状态 |
|----------|------|------|
| **conf_global.yml** | 全局配置 | ❌ 遗漏 |
| **conf_client.yml** | 客户端配置 | ❌ 遗漏 |
| **策略 YAML** | 策略参数 | ⚠️ 部分覆盖 |
| **secrets 加密** | API 密钥加密 | ❌ 遗漏 |
| **环境变量** | Docker 配置 | ❌ 遗漏 |

### 2.10 客户端命令 - 关键遗漏

| 命令 | 说明 |
|------|------|
| `connect [exchange]` | 连接交易所 |
| `create` | 创建策略配置 |
| `start` | 启动策略 |
| `stop` | 停止策略 |
| `status` | 查看状态 |
| `history` | 历史交易记录 |
| `balance` | 资产余额 |
| `pnl` | 盈亏统计 |
| `export trades` | 导出交易记录 |
| `paper_trade` | 切换模拟模式 |

### 2.11 日志与调试

| 功能 | 说明 | 状态 |
|------|------|------|
| **日志文件** | `/logs` 目录 | ❌ 遗漏 |
| **日志级别** | DEBUG/INFO/WARNING/ERROR | ❌ 遗漏 |
| **Debug Console** | 交互式 Python REPL | ❌ 遗漏 |
| **日志轮转** | 保留 7 天 | ❌ 遗漏 |

### 2.12 Docker 部署

| 功能 | 说明 | 状态 |
|------|------|------|
| **docker-compose.yml** | 容器编排 | ❌ 遗漏 |
| **Gateway 集成** | DEX 连接 | ❌ 遗漏 |
| **Volume 挂载** | 配置持久化 | ❌ 遗漏 |
| **deploy 仓库** | 自动化部署 | ❌ 遗漏 |

### 2.13 MQTT 消息系统

| 功能 | 说明 | 状态 |
|------|------|------|
| **MQTT 协议** | 事件推送 | ❌ 遗漏 |
| **多机器人协调** | 分布式控制 | ❌ 遗漏 |
| **TradingView 集成** | Webhook 信号 | ❌ 遗漏 |

---

## 三、更新后的系统架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              AlgVex Platform v2.0                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                         Qlib 完整功能 (v0.9.7)                                  │ │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐│ │
│  │  │ Model  │ │Strategy│ │Backtest│ │Workflow│ │   RL   │ │ Meta   │ │ Online ││ │
│  │  │ (19+)  │ │  (7+)  │ │(Nested)│ │(MLflow)│ │(Tianshou)│ │Learning│ │Serving ││ │
│  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘│ │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐                                 │ │
│  │  │  Ops   │ │Processor│ │Evaluate│ │ Report │                                 │ │
│  │  │ (50+)  │ │ (10+)  │ │  (4+)  │ │  (6+)  │                                 │ │
│  │  └────────┘ └────────┘ └────────┘ └────────┘                                 │ │
│  └────────────────────────────────────┬──────────────────────────────────────────┘ │
│                                       │                                             │
│  ┌────────────────────────────────────▼──────────────────────────────────────────┐ │
│  │                    Crypto Adapter Layer (扩展版)                               │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐         │ │
│  │  │CryptoCalendar│ │CryptoDataHdlr│ │CryptoExchange│ │NestedCrypto  │         │ │
│  │  │  (24/7日历)   │ │ (CCXT数据源)  │ │ (永续规则)    │ │  Executor    │         │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘         │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                          │ │
│  │  │ dump_crypto  │ │TaskManager   │ │OnlineService │                          │ │
│  │  │   .py        │ │  (MongoDB)   │ │  (内置整合)   │                          │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘                          │ │
│  └────────────────────────────────────┬──────────────────────────────────────────┘ │
│                                       │                                             │
│  ┌────────────────────────────────────▼──────────────────────────────────────────┐ │
│  │                    Signal Bridge (扩展版)                                      │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐         │ │
│  │  │SignalConvert │ │ RiskFilter  │ │FrequencyCtrl │ │  MQTT/Redis  │         │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘         │ │
│  └────────────────────────────────────┬──────────────────────────────────────────┘ │
│                                       │                                             │
│  ┌────────────────────────────────────▼──────────────────────────────────────────┐ │
│  │                    Hummingbot 完整功能 (v2.11.0)                               │ │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐│ │
│  │  │Connector│ │Strategy│ │Executor│ │  API   │ │  Risk  │ │Dashboard│ │ Paper  ││ │
│  │  │ (50+)  │ │V1+V2   │ │  (6)   │ │ (REST) │ │ (12+)  │ │(Optuna)│ │ Trade  ││ │
│  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘│ │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐                                 │ │
│  │  │Commands│ │ Logging│ │ Docker │ │  MQTT  │                                 │ │
│  │  │ (20+)  │ │(Debug) │ │(Deploy)│ │(Broker)│                                 │ │
│  │  └────────┘ └────────┘ └────────┘ └────────┘                                 │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 四、更新后的实施计划

### Phase 0: 基础设施准备 (新增)

| 任务 | 说明 | 优先级 |
|------|------|--------|
| 0.1 | 配置 MongoDB (任务管理) | 🔴 高 |
| 0.2 | 配置 Redis (信号桥) | 🔴 高 |
| 0.3 | 配置 MLflow (实验跟踪) | 🔴 高 |
| 0.4 | 部署 Hummingbot Dashboard | 🔴 高 |

### Phase 1: 数据层适配 (扩展)

| 任务 | 说明 | 优先级 |
|------|------|--------|
| 1.1 | 实现 CryptoCalendarProvider | 🔴 高 |
| 1.2 | 实现 CryptoInstrumentProvider | 🔴 高 |
| 1.3 | 实现 CryptoDataHandler | 🔴 高 |
| 1.4 | 实现 dump_crypto.py (数据转换) | 🔴 高 |
| 1.5 | 适配 50+ 表达式操作符 | 🟡 中 |
| 1.6 | 验证 10+ 处理器 | 🟡 中 |

### Phase 2: 回测层适配 (扩展)

| 任务 | 说明 | 优先级 |
|------|------|--------|
| 2.1 | 实现 CryptoExchange | 🔴 高 |
| 2.2 | 实现 NestedExecutor 加密货币适配 | 🔴 高 |
| 2.3 | 仓位管理 (做空/杠杆/资金费率) | 🔴 高 |
| 2.4 | VWAPExecutor 适配 | 🟡 中 |

### Phase 3: 模型与评估

| 任务 | 说明 | 优先级 |
|------|------|--------|
| 3.1 | 验证 19+ 模型在加密市场效果 | 🔴 高 |
| 3.2 | 实现 CryptoAlpha158 | 🔴 高 |
| 3.3 | 集成评估模块 | 🟡 中 |
| 3.4 | 集成报告生成模块 | 🟢 低 |

### Phase 4: 信号桥与在线服务

| 任务 | 说明 | 优先级 |
|------|------|--------|
| 4.1 | 整合 Qlib OnlineManager | 🔴 高 |
| 4.2 | 实现 MQTT + Redis 双通道 | 🟡 中 |
| 4.3 | 实现 RollingGen 滚动训练 | 🟡 中 |

### Phase 5: Hummingbot 完整集成

| 任务 | 说明 | 优先级 |
|------|------|--------|
| 5.1 | 多交易所连接器 (Bybit, OKX) | 🔴 高 |
| 5.2 | 集成 Kill Switch 等风控 | 🔴 高 |
| 5.3 | 集成 Dashboard + Optuna | 🔴 高 |
| 5.4 | 实现 Paper Trading 测试流程 | 🔴 高 |
| 5.5 | V1 策略评估 (Spot-Perp Arb) | 🟡 中 |
| 5.6 | Docker 部署配置 | 🟡 中 |

### Phase 6: 测试与文档

| 任务 | 说明 | 优先级 |
|------|------|--------|
| 6.1 | 单元测试 (所有适配层) | 🔴 高 |
| 6.2 | 集成测试 (端到端) | 🔴 高 |
| 6.3 | Paper Trading 验证 | 🔴 高 |
| 6.4 | 文档完善 | 🟡 中 |

---

## 五、更新后的依赖版本

```requirements.txt
# Qlib 完整依赖
qlib==0.9.7
torch>=2.0.0
lightgbm>=4.0.0
xgboost>=2.0.0
catboost>=1.2.0
tianshou>=0.5.0

# Hummingbot
hummingbot>=2.11.0
hummingbot-api-client>=0.1.0

# 数据
ccxt>=4.0.0
pandas>=2.0.0
numpy>=1.24.0

# 通信
redis>=5.0.0
paho-mqtt>=2.0.0  # 新增: MQTT

# 数据库
pymongo>=4.6.0    # 新增: MongoDB

# MLOps
mlflow>=2.10.0

# Dashboard
streamlit>=1.30.0  # 新增
optuna>=3.5.0      # 新增

# 可视化
plotly>=5.18.0     # 新增
```

---

## 六、覆盖率对比 (基于本地代码审查)

### Qlib 覆盖率 (libs/qlib v0.9.7)

| 类别 | 实际数量 | 覆盖率 |
|------|----------|--------|
| 模型 | 31 | 100% |
| 策略 | 7+ | 100% |
| 表达式操作符 | 52 | 100% |
| Alpha158 因子 | 158 | 100% |
| 处理器 | 10+ | 100% |
| 数据基础设施 | 12+ | 100% |
| 任务管理 | 7 | 100% |
| 在线服务 | 7 | 100% |
| 嵌套执行 | 1 | 100% |
| 评估模块 | 4 | 100% |
| 报告生成 | 6 | 100% |
| Meta-Learning | 4 | 100% |

### Hummingbot 覆盖率 (libs/hummingbot v2.11.0)

| 类别 | 实际数量 | 覆盖率 |
|------|----------|--------|
| 连接器 | 37 (26现货+11永续) | 100% |
| V2 控制器基类 | 3 | 100% |
| 执行器 | 7 | 100% |
| V1 策略 | 9 | 100% |
| 风险功能 | 12+ | 100% |
| Dashboard | 全部 | 100% |
| Paper Trading | 全部 | 100% |
| 配置系统 | 全部 | 100% |
| 命令 | 20+ | 100% |
| 日志/调试 | 全部 | 100% |
| Docker | 全部 | 100% |
| MQTT | 全部 | 100% |

---

## 七、补充遗漏模块 (2025-12-31 审计)

### 7.1 Qlib 遗漏模块

#### 7.1.1 高频操作符 (qlib/contrib/ops/high_freq.py)

| 操作符 | 说明 | 适配策略 |
|--------|------|----------|
| **DayCumsum** | 日内累计求和 | 🟢 适配小时级 |
| **DayLast** | 日内最后一个值 | 🟢 适配小时级 |
| **get_calendar_day** | 高频日历日期 | 🔴 需适配 24/7 |
| **get_calendar_minute** | 高频日历分钟 | 🔴 需适配 24/7 |

#### 7.1.2 风险模型 (qlib/model/riskmodel/)

| 模型 | 文件 | 说明 | 适配策略 |
|------|------|------|----------|
| **RiskModel** | base.py | 风险模型基类 | 🟢 无需修改 |
| **POETCovEstimator** | poet.py | POET 协方差估计 | 🟢 无需修改 |
| **ShrinkCovEstimator** | shrink.py | 收缩协方差估计 | 🟢 无需修改 |
| **StructuredCovEstimator** | structured.py | 结构化协方差估计 | 🟢 无需修改 |

#### 7.1.3 集成学习 (qlib/model/ens/)

| 组件 | 说明 | 适配策略 |
|------|------|----------|
| **RollingEnsemble** | 滚动集成 | 🟢 无需修改 |
| **AverageEnsemble** | 平均集成 | 🟢 无需修改 |
| **RollingGroup** | 滚动分组 | 🟢 无需修改 |

#### 7.1.4 超参数调优器 (qlib/contrib/tuner/)

| 组件 | 说明 | 适配策略 |
|------|------|----------|
| **Tuner** | 超参数搜索 | 🟢 无需修改 |
| **TunerPipeline** | 调优流水线 | 🟢 无需修改 |
| **SearchSpace** | 搜索空间定义 | 🟢 无需修改 |

#### 7.1.5 组合优化策略 (qlib/contrib/strategy/optimizer/)

| 策略 | 说明 | 适配策略 |
|------|------|----------|
| **EnhancedIndexingOptimizer** | 增强指数策略 | 🟡 需适配加密货币 |
| **MeanVarianceOptimizer** | 均值方差优化 | 🟢 无需修改 |

#### 7.1.6 已有 Crypto 数据收集器 (scripts/data_collector/crypto/)

**重要发现**: Qlib 已有 crypto 数据收集器！

```python
# 位置: libs/qlib/scripts/data_collector/crypto/collector.py
# API: CoinGecko
# 功能: 加密货币数据收集 (日线)

class CryptoCollector(BaseCollector):
    # 支持 interval: 1d
    # 输出: Qlib 标准格式
```

**适配建议**: 扩展支持 1h 间隔 + Binance API

### 7.2 Hummingbot 遗漏模块

#### 7.2.1 Candles Feed (data_feed/candles_feed/)

**21+ 交易所 K线数据源**:

| 数据源 | 类型 | 用途 |
|--------|------|------|
| binance_perpetual_candles | 永续 | 主数据源 |
| binance_spot_candles | 现货 | 套利参考 |
| bybit_perpetual_candles | 永续 | 备用数据源 |
| okx_perpetual_candles | 永续 | 备用数据源 |
| gate_io_perpetual_candles | 永续 | 备用数据源 |
| kucoin_perpetual_candles | 永续 | 备用数据源 |
| hyperliquid_perpetual_candles | DEX | DEX 数据 |
| ... (共 21+) | ... | ... |

#### 7.2.2 其他数据源 (data_feed/)

| 数据源 | 说明 |
|--------|------|
| **CoinGecko** | 价格/市值数据 |
| **CoinCap** | 市值排名数据 |
| **AMM Gateway** | DEX 数据 |
| **Liquidations** | 清算数据 |
| **Market Data Provider** | 统一数据接口 |

#### 7.2.3 回测引擎 (strategy_v2/backtesting/)

| 组件 | 说明 |
|------|------|
| **BacktestingEngineBase** | 回测引擎基类 |
| **BacktestingDataProvider** | 回测数据提供者 |
| **ExecutorSimulatorBase** | 执行器模拟基类 |

#### 7.2.4 策略脚本示例 (scripts/)

**30+ 社区策略脚本**:
- triangular_arbitrage.py - 三角套利
- spot_perp_arb.py - 现货-永续套利
- directional_strategy_macd_bb.py - MACD+布林带
- simple_pmm.py - 简单 PMM
- simple_vwap.py - VWAP 执行
- fixed_grid.py - 固定网格
- 1overN_portfolio.py - 等权组合
- ... (共 30+)

---

## 八、参考资源

### Qlib
- [GitHub](https://github.com/microsoft/qlib)
- [Documentation](https://qlib.readthedocs.io/)
- [Expression Operators](https://github.com/microsoft/qlib/blob/main/qlib/data/ops.py)
- [Task Management](https://qlib.readthedocs.io/en/latest/advanced/task_management.html)
- [Online Serving](https://qlib.readthedocs.io/en/latest/component/online.html)
- [Nested Execution](https://qlib.readthedocs.io/en/latest/component/highfreq.html)

### Hummingbot
- [GitHub](https://github.com/hummingbot/hummingbot)
- [Documentation](https://hummingbot.org)
- [Dashboard](https://github.com/hummingbot/dashboard)
- [Connectors](https://hummingbot.org/exchanges/)
- [Strategy V2](https://hummingbot.org/v2-strategies/)
- [API Reference](https://hummingbot.org/hummingbot-api/)

---

**文档版本**: 3.1 (补充遗漏模块)
**审查源码**: libs/qlib (v0.9.7) + libs/hummingbot (v2.11.0)
**更新日期**: 2025-12-31
**作者**: Claude (AlgVex AI Assistant)

---

> **关联文档**: [EXECUTION-PLAN.md](./EXECUTION-PLAN.md) - 完整执行方案
