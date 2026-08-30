extends RefCounted
class_name Names

## Flavour text: the people who live in your tower and the films you show them.

const FIRST := [
	"Ada", "Bruno", "Carla", "Derek", "Elena", "Frank", "Greta", "Ivan",
	"Lucy", "Marco", "Nadia", "Oscar", "Paula", "Quentin", "Rita", "Sergio",
	"Teresa", "Hugo", "Valerie", "Zeno", "Amos", "Bianca", "Cesar", "Delia",
	"Enrico", "Fran", "Gene", "Hilary", "Louis", "Martha", "Nino", "Ornella",
]

const LAST := [
	"Rossi", "White", "Ferrari", "Russo", "Esposito", "Colomb", "Rich",
	"Marino", "Green", "Bruno", "Gallo", "Conti", "De Luca", "Costa", "Jordan",
	"Mancini", "Rizzo", "Lombard", "Moretti", "Barber", "Fontana", "Santoro",
]

const ROLES := {
	"office": "Office Worker",
	"condo": "Resident",
	"hotel": "Guest",
	"shop": "Shop Assistant",
	"food": "Customer",
	"housekeeping": "Housekeeper",
	"security": "Security Guard",
	"medical": "Doctor",
	"visitor": "Visitor",
	"vip": "VIP",
}

const MOVIES_NEW := [
	"The North Wind", "Last Call", "Eighteen Floors", "Cobalt Red",
	"The Long Way Down", "Vertigo Hour", "Nine Lives", "The Elevator Thief",
]

const MOVIES_CLASSIC := [
	"The Bicycle Man", "The Sweet Life", "The Leopard", "Eight and a Half",
	"Open City", "The Overtaking", "Miracle in Milan", "Persons Unknown",
]

const WEATHER := ["clear", "cloudy", "rain", "snow"]

static func random_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]]
