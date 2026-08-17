class_name FlankEffect
extends Resource

## 基础逻辑链：伺机（离开攻击范围触发）。
## 打出后本回合内，当出牌者移动离开原本在其攻击范围内的敌人时，
## 对该敌人造成 value 点伤害（由 battle_map 在移动结算时触发）。

@export var value: int = 7
