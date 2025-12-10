# 模块整合接口文档

## 📋 各 Part 功能分工

| Part | 负责人 | 主要贡献 | 整合后用途 |
|------|--------|---------|-----------|
| part_lyx | lyx | 主FSM + UART + 7段扫描 | ✅ 作为主控框架 |
| part_hcz | hcz | 倒计时器 + 按键消抖 | ✅ 倒计时功能 |
| part_shl | shl | 矩阵存储 + 运算核心 | ✅ 计算引擎 |

---

## 🔌 关键接口对照

### 1. 从 part_lyx 复用的模块

```
part_lyx/top_module/design/
├── debounce.v      → 按键消抖 (已复用)
├── uart_rx.v       → UART接收 (已复用)
├── uart_tx.v       → UART发送 (已复用)
└── seg_scan.v      → 数码管扫描 (可选复用)
```

**接口规范：**
```verilog
// debounce 接口
debounce u_db (
    .clk(clk),
    .rst_n(rst_n),
    .key_in(raw_button),
    .key_flag(pulse_output)  // 单周期脉冲
);

// uart_rx 接口
uart_rx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115200)) u_rx (
    .clk(clk), .rst_n(rst_n),
    .rx(uart_rx_pin),
    .rx_data(received_byte),  // 8位数据
    .rx_done(rx_done_pulse)   // 接收完成脉冲
);

// uart_tx 接口
uart_tx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115200)) u_tx (
    .clk(clk), .rst_n(rst_n),
    .tx_start(start_pulse),
    .tx_data(byte_to_send),
    .tx(uart_tx_pin),
    .tx_busy(busy_flag)
);
```

---

### 2. 从 part_hcz 复用的模块

```
part_hcz/
├── ButtonDebounce.v  → 另一种消抖实现 (备选)
├── ClkDivider.v      → 时钟分频 (可选)
└── SegDisplay.v      → 数码管显示 (可参考)
```

**倒计时逻辑已集成到 integrated_top.v 中**

---

### 3. 从 part_shl 复用的模块

```
part_shl/
├── adder_validator.v        → 加法验证 ✅
├── multiplexer_validator.v  → 乘法验证 ✅
├── convoluter_validator.v   → 卷积验证 ✅
├── matrix_calculate.sv      → 计算核心 (需连接)
├── convoluter.sv            → 卷积计算 (需连接)
├── timer.v                  → 倒计时 (已有替代)
└── operand_selector.v       → 运算数选择 (可选)
```

**验证器接口：**
```verilog
// 加法验证器
adder_validator u_add_val (
    .a_row(mat_a_rows), .a_col(mat_a_cols),
    .b_row(mat_b_rows), .b_col(mat_b_cols),
    .valid_add(is_valid)  // 1=合法, 0=不合法
);

// 乘法验证器
multiplexer_validator u_mul_val (
    .a_row(), .a_col(),
    .b_row(), .b_col(),
    .valid_mul(is_valid),
    .result_row(res_r), .result_col(res_c)
);
```

---

## 🎛️ 开发板引脚映射建议

根据 part_lyx 的约束文件，建议的引脚分配：

| 信号 | 引脚 | 说明 |
|------|------|------|
| sw[7:0] | SW7-SW0 | 拨码开关 |
| sw_scalar_count_down[3:0] | SW11-SW8 | 标量/倒计时设置 |
| btn_confirm | S3 | 确认键 |
| btn_send | S0 | UART发送键 |
| uart_rx | 指定RX引脚 | UART接收 |
| uart_tx | 指定TX引脚 | UART发送 |
| led_error | LED5 | 错误指示 |
| led_idle | LED0 | 空闲状态 |
| seg_sel[7:0] | DK1-DK8 | 数码管位选 |
| seg_data[7:0] | 段选总线 | 数码管段选 |

---

## ⚠️ 整合注意事项

### 1. 时钟域
- 所有模块都使用 100MHz 主时钟
- UART 波特率统一为 115200

### 2. 复位极性
- 统一使用 `rst_n` (低电平有效)

### 3. 命名冲突
- part_lyx 的 `debounce` 和 part_hcz 的 `ButtonDebounce` 功能相同，选用一个即可
- 数组接口要注意 SystemVerilog (.sv) 和 Verilog (.v) 的兼容性

### 4. 需要手动完成的连接
```
[ ] 实例化 matrix_calculate 模块
[ ] 实例化 convoluter 模块  
[ ] 完善 UART TX 发送逻辑 (发送计算结果)
[ ] 调整数码管显示内容
[ ] 添加约束文件 (.xdc)
```

---

## 📁 文件结构建议

```
A_CODE_SPACE/
├── integrated_top.v          ← 整合顶层 (新建)
├── integrated_top.xdc        ← 约束文件 (待创建)
│
├── part_lyx/top_module/design/
│   ├── debounce.v            ← 复用
│   ├── uart_rx.v             ← 复用
│   └── uart_tx.v             ← 复用
│
└── part_shl/
    ├── adder_validator.v     ← 复用
    ├── multiplexer_validator.v ← 复用
    └── matrix_calculate.sv   ← 复用
```

---

## 🔧 下一步工作

1. **验证 integrated_top.v 语法** - Vivado 综合检查
2. **完善计算核心连接** - 实例化 matrix_calculate
3. **创建约束文件** - 引脚绑定
4. **功能仿真** - 测试各模块协作
5. **上板测试** - 逐功能验证
