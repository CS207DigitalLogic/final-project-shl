# CS307 数字逻辑设计 Project 1 实验报告

## 1. 开发者说明 (Developer Information)

| 学号  | 姓名  | 负责的工作 | 贡献百分比  |
| :--- | :--- | :--- | :--- |
| 12410148 | 刘以煦| 顶层架构，矩阵生成，UART，随机选择运算数，存储 | 36 |
| 12413323 | 邵浩林| 卷积，运算，存储，矩阵输入，矩阵展示 | 36 |
| 12411443 | 何成卓| 倒计时，按键消抖 | 28 |

## 2. 开发计划日程安排和实施情况 

详见以下github链接

*   **GitHub Link**: [https://github.com/CS207DigitalLogic/final-project-shl](https://github.com/CS207DigitalLogic/final-project-shl)

*   **提交记录**: 
[master分支](https://github.com/CS207DigitalLogic/final-project-shl/commits/master/)
[display分支](https://github.com/CS207DigitalLogic/final-project-shl/commits/display)

## 3. 项目架构设计说明

> 基于第13周提交的架构设计文档，描述改进后的最终实现方案。

### 3.1 系统总体架构

[在此处简述系统的顶层模块划分，例如：顶层模块 `integrated_top` 包含 `part_lyx` (主控/UART), `part_hcz` (倒计时), `part_shl` (矩阵运算) 等。可以使用简单的框图描述数据流向。]

### 3.2 核心模块设计

*   **主控与状态机 (FSM)**: [描述状态流转，如 Menu -> Inputer -> Operator 等]

*   **矩阵存储 (Matrix Storage)**: [描述存储结构，如 `mem_data` 数组，以及 Inputer/Generator 的工作方式]

*   **矩阵运算 (Matrix Calculation)**: [描述计算单元如何支持转置、加法、乘法，状态机流程]

*   **UART 通信**: [描述 RX/TX 的复用机制和协议]

## 4. 开源及 AI 对于本次大作业的启发和帮助 (Open Source & AI Inspiration)

### 4.1 网络代码资源

*   [列出使用的开源代码或参考资源，说明它们提供了哪些帮助]

### 4.2 AI 辅助开发

*   **使用的 AI 工具**: [例如: GitHub Copilot, ChatGPT, Claude]

*   **参与环节**: [例如: 代码生成、Bug 调试、文档编写]

*   **主要提示词 (Prompts)**:
    *   "[例如: 帮我写一个 Verilog 矩阵乘法模块]"
    *   "[例如: 解释这段 UART 接收代码的时序]"

*   **带来的优化与启发**:
    *   [AI 如何帮助优化了状态机逻辑]
    *   [AI 提供的代码片段如何加速了开发]

## 5. Bonus 实现说明

### 5.1 输出对齐 / 参数配置

*   **设计思路**: [简述如何实现矩阵打印的对齐，或者参数配置状态机的设计]
*   **与周边模块的关系**: [例如: 设置模块如何修改寄存器，进而影响倒计时或存储限制]

### 5.2 卷积运算

*   *(注：如果实现了卷积，详细报告由 PPT+视频 替代，此处可简要提及已实现)*

## 6. 问题及总结

### 6.1 开发过程中遇到的问题

1.  **问题描述**: [例如: UART 发送乱码]
    *   **解决方案**: [例如: 调整波特率分频系数，增加停止位等待]
2.  **问题描述**: [例如: 矩阵乘法时序违例]
    *   **解决方案**: [例如: 增加流水线级数，优化状态机]

### 6.2 思考与总结

*   [对数字逻辑设计的理解加深]
*   [对 FPGA 开发流程的感悟]
*   [未来的改进方向]
