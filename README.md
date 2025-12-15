# 项目说明

## A_CODE_SPACE

### 结构规范

1. 目录下分为三个同学负责的代码文件夹，本地跑通后将代码放入自己对应的版块（包含design和simulation）
2. 代码写必要的注释
3. 本地跑通后将代码放入自己对应的版块（包含design和simulation）
4. 自行更新到main对应的文件夹位置
5. 顶层测试人在main的PROJ测试并反馈

### lyx

#### 顶层模块

1. 任意状态之间均可切换，切换需按**confirm**。七位数码管显示所在状态。reset回到menu

2. INPUTER模式下，使用uart每发送一条数据（如“2 3 1 2 3 4 5 6”），需按**confirm**后再发送新的数据

3. DISPLAYER模式下，目前一旦按**confirm**进入，就会在uart接收端口打印出所有存储的矩阵

4. 目前总共可存储15个矩阵，每种规格矩阵数量上限可调整范围为1-7

5. 若led_error（F6）点亮，需按**confirm**才能熄灭

## A_PROJ_WHOLE

可提交的整合版本
