# 内部数据接口说明

## Read Channel

支持burst传输的单通道总线

|名称|驱动|描述|
|:--|:--|:--|
|en|master|该通道是否使能|
|valid|master|准备接受单次传输|
|ready|slave|当前传输为合法数据|
|addr|基址|