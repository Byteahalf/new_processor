# 关于模拟器设计

## 寄存器端口规划

**ALU**: 2\*GRead 1\*GWrite

**FPU**: 3\*FRead 1\*FWrite

**LSU**: 1\*GRead 1\*GWrite 1\*FRead 1\*FWrite 1\*VRead 1\*VWrite

## InstrUnit

### dataflow

描述：包含所有需要的数据信息

PC -> 当前指令的地址

RS1, RS2, RS3, RD -> 寄存器信息

imm -> 计算用立即数

offset -> PC 更新用，地址计算用

### alu

指定需求的执行器类型

## ALU

直接计算结果，1周期输出

## LSU (Load Store Unit)

两个计算：地址计算加法，原子指令乘法

两个单元：读取写入

## FPU

使用fpnew库

## 未完待续