extends RefCounted
class_name Names

## Flavour text: the people who live in your tower and the films you show them.

const FIRST := [
	"Ada", "Bruno", "Carla", "Dario", "Elena", "Fabio", "Giulia", "Ivano",
	"Lucia", "Marco", "Nadia", "Orso", "Paola", "Quirino", "Rita", "Sergio",
	"Teresa", "Ugo", "Valeria", "Zeno", "Amedeo", "Bianca", "Cesare", "Delia",
	"Enrico", "Franca", "Gino", "Ilaria", "Luigi", "Marta", "Nino", "Ornella",
]

const LAST := [
	"Rossi", "Bianchi", "Ferrari", "Russo", "Esposito", "Colombo", "Ricci",
	"Marino", "Greco", "Bruno", "Gallo", "Conti", "De Luca", "Costa", "Giordano",
	"Mancini", "Rizzo", "Lombardi", "Moretti", "Barbieri", "Fontana", "Santoro",
]

const ROLES := {
	"office": "Impiegato",
	"condo": "Residente",
	"hotel": "Ospite",
	"shop": "Commesso",
	"food": "Cliente",
	"housekeeping": "Addetto pulizie",
	"security": "Guardia",
	"medical": "Medico",
	"visitor": "Visitatore",
	"vip": "VIP",
}

const MOVIES_NEW := [
	"Il vento del nord", "Ultima chiamata", "Diciotto piani", "Rosso cobalto",
	"La grande discesa", "Vertigine", "Nove vite", "Il ladro di ascensori",
]

const MOVIES_CLASSIC := [
	"Ladri di biciclette", "La dolce vita", "Il gattopardo", "Otto e mezzo",
	"Roma citta aperta", "Il sorpasso", "Miracolo a Milano", "I soliti ignoti",
]

const WEATHER := ["sereno", "nuvoloso", "pioggia", "neve"]

static func random_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]]
