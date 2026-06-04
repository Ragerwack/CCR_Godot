## CCRData.gd — 兼容层
## 各数据类已拆分为独立文件（CardColor.gd, Deck.gd, etc.）
## 此文件仅为向后兼容保留

class_name CCRData
extends RefCounted

const Deck = preload("res://Scripts/Data/Deck.gd")
const CardColor = preload("res://Scripts/Data/CardColor.gd")
const CardInfo = preload("res://Scripts/Data/CardInfo.gd")
const CardSeries = preload("res://Scripts/Data/CardSeries.gd")
const PlayerData = preload("res://Scripts/Data/PlayerData.gd")
const Vault = preload("res://Scripts/Data/Vault.gd")
