class_name Cards
extends RefCounted
## Cartas como dados estruturados (no Python o efeito era deduzido do texto por regex).
## effect: heal | damage | xp | teleport | skip_turn

const DECK := [
	{ "kind": "SORTE", "effect": "heal", "value": 30, "text": "Ganhe 30 de vida!" },
	{ "kind": "SORTE", "effect": "xp", "value": 25, "text": "Ganhe 25 de XP!" },
	{ "kind": "SORTE", "effect": "teleport", "value": 0, "text": "Teleporte para uma posição aleatória!" },
	{ "kind": "AZAR", "effect": "damage", "value": 25, "text": "Perde 25 de vida!" },
	{ "kind": "AZAR", "effect": "skip_turn", "value": 0, "text": "Perde um turno!" },
	{ "kind": "SORTE", "effect": "heal", "value": 50, "text": "Ganhe 50 de vida!" },
	{ "kind": "AZAR", "effect": "damage", "value": 15, "text": "Perde 15 de vida!" },
	{ "kind": "SORTE", "effect": "teleport", "value": 0, "text": "Teleporte mágico para lugar seguro!" },
]
