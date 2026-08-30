extends RefCounted
class_name FacilityDB

## The complete catalogue of everything that can be placed in a Grattacielo.
##
## Every number here comes from the SimTower manual in extras/ or from measured
## reference data on the original game. Nothing else in the project is allowed
## to hard-code a price, a size or a capacity -- ask this table instead.
##
## Sizes are in SEGMENTS (the 8-pixel-wide unit the original calls a segment)
## and FLOORS. Money is in whole units; the original's finance window divided
## everything by 100, we do not.

# --- The lot -------------------------------------------------------------
const MAP_SEGMENTS := 375       # width of the world, in segments
const FLOORS_ABOVE := 100       # storeys 1..100
const FLOORS_BELOW := 10        # basements B1..B10
const ROW_MIN := -FLOORS_BELOW  # internal row index of the deepest basement
const ROW_MAX := FLOORS_ABOVE - 1

const STARTING_FUNDS := 2000000

# Kinds -- what a placed thing fundamentally IS, which decides how it is
# simulated. Several facilities share a kind (all five fast food brands are
# one FOOD facility with a brand).
enum Kind {
	STRUCTURE,   # lobby, empty floor
	OFFICE,
	CONDO,
	HOTEL,
	FOOD,        # fast food + restaurants: automatic, patron-driven
	SHOP,        # rentable, patron-driven
	VENUE,       # party hall, cinema
	SERVICE,     # housekeeping, security, medical, recycling
	PARKING,
	TRANSPORT,   # stairs, escalators, elevators
	CIVIC,       # metro station, cathedral
}

# How a facility earns.
enum Income {
	NONE,
	QUARTERLY_RENT,   # office, shop -- rent tier, paid each quarter
	DAILY_RENT,       # hotel rooms -- rent tier, paid per occupied night
	ONE_TIME_SALE,    # condo -- paid on purchase, refunded if they leave
	PATRONAGE,        # fast food, restaurant -- by customer count per day
	VENUE_TAKE,       # party hall, cinema -- per event
}

# ---------------------------------------------------------------------------
# The catalogue.
#
#   stars      : star rating at which the tool unlocks
#   cost       : construction cost
#   w / h      : size in segments / floors
#   capacity   : people the facility holds (occupants, or daily patrons)
#   upkeep     : maintenance charged each quarter
#   rents      : the four price tiers (Very Low, Low, Average, High)
#   underground: -1 above ground only, 0 either, 1 underground only
# ---------------------------------------------------------------------------

const DEFS := {
	# --- structure ---------------------------------------------------------
	"lobby": {
		"name": "Atrio", "kind": Kind.STRUCTURE, "stars": 1,
		"cost": 5000, "w": 1, "h": 1, "capacity": 0, "upkeep": 0,
		"income": Income.NONE, "underground": -1, "drag": "h",
		"desc": "Ogni grattacielo comincia da qui. Un atrio ogni 15 piani diventa uno sky lobby.",
	},
	"floor": {
		"name": "Piano vuoto", "kind": Kind.STRUCTURE, "stars": 1,
		"cost": 500, "w": 1, "h": 1, "capacity": 0, "upkeep": 0,
		"income": Income.NONE, "underground": 0, "drag": "h",
		"desc": "Struttura nuda. Serve sotto a tutto quello che costruisci.",
	},

	# --- transport ---------------------------------------------------------
	"stairs": {
		"name": "Scale", "kind": Kind.TRANSPORT, "stars": 1,
		"cost": 5000, "w": 8, "h": 2, "capacity": 21, "upkeep": 0,
		"income": Income.NONE, "underground": 0,
		"desc": "Collega due piani. Nessuno ne prende piu di quattro rampe in un viaggio.",
	},
	"escalator": {
		"name": "Scala mobile", "kind": Kind.TRANSPORT, "stars": 1,
		"cost": 20000, "w": 8, "h": 2, "capacity": 21, "upkeep": 5000,
		"income": Income.NONE, "underground": 0,
		"desc": "Nessuna attesa, quindi nessuno stress. Solo su aree commerciali o atri.",
	},
	"elevator": {
		"name": "Ascensore", "kind": Kind.TRANSPORT, "stars": 1,
		"cost": 200000, "car_cost": 80000, "w": 4, "h": 1,
		"capacity": 21, "upkeep": 10000, "car_upkeep": 10000,
		"income": Income.NONE, "underground": 0,
		"max_span": 30, "desc": "Massimo 30 piani di corsa, 8 cabine per vano.",
	},
	"service_elevator": {
		"name": "Montacarichi", "kind": Kind.TRANSPORT, "stars": 2,
		"cost": 100000, "car_cost": 50000, "w": 4, "h": 1,
		"capacity": 21, "upkeep": 10000, "car_upkeep": 10000,
		"income": Income.NONE, "underground": 0,
		"max_span": 30, "desc": "Solo per il personale. Deve servire i centri di riciclaggio.",
	},
	"express_elevator": {
		"name": "Ascensore espresso", "kind": Kind.TRANSPORT, "stars": 3,
		"cost": 400000, "car_cost": 150000, "w": 6, "h": 1,
		"capacity": 42, "upkeep": 20000, "car_upkeep": 20000,
		"income": Income.NONE, "underground": 0,
		"max_span": 110, "desc": "Ferma solo agli sky lobby, ogni 15 piani. 42 persone per cabina.",
	},

	# --- income property ---------------------------------------------------
	"office": {
		"name": "Ufficio", "kind": Kind.OFFICE, "stars": 1,
		"cost": 40000, "w": 9, "h": 1, "capacity": 6, "upkeep": 0,
		"income": Income.QUARTERLY_RENT, "rents": [4000, 8000, 10000, 14000],
		"underground": -1,
		"desc": "Sei impiegati. Arrivano la mattina, pranzano, se ne vanno la sera.",
	},
	"condo": {
		"name": "Appartamento", "kind": Kind.CONDO, "stars": 1,
		"cost": 80000, "w": 16, "h": 1, "capacity": 3, "upkeep": 0,
		"income": Income.ONE_TIME_SALE, "rents": [50000, 80000, 120000, 200000],
		"underground": 0,
		"desc": "Venduto, non affittato. Se se ne vanno, restituisci il prezzo per intero.",
	},
	"hotel_single": {
		"name": "Camera singola", "kind": Kind.HOTEL, "stars": 2,
		"cost": 20000, "w": 4, "h": 1, "capacity": 1, "upkeep": 0,
		"income": Income.DAILY_RENT, "rents": [800, 1500, 2000, 3000],
		"underground": -1,
		"desc": "Un ospite per notte. Arriva la sera, riparte la mattina.",
	},
	"hotel_twin": {
		"name": "Camera doppia", "kind": Kind.HOTEL, "stars": 2,
		"cost": 50000, "w": 6, "h": 1, "capacity": 2, "upkeep": 0,
		"income": Income.DAILY_RENT, "rents": [1200, 2200, 3000, 4500],
		"underground": -1,
		"desc": "Due ospiti, stesse regole della singola.",
	},
	"hotel_suite": {
		"name": "Suite", "kind": Kind.HOTEL, "stars": 2,
		"cost": 100000, "w": 10, "h": 1, "capacity": 2, "upkeep": 0,
		"income": Income.DAILY_RENT, "rents": [2500, 4500, 6000, 9000],
		"underground": -1,
		"desc": "Ospiti col valletto. Servono per la visita del VIP.",
	},

	# --- food & retail -----------------------------------------------------
	"fastfood": {
		"name": "Fast food", "kind": Kind.FOOD, "stars": 1,
		"cost": 100000, "w": 16, "h": 1, "capacity": 30, "upkeep": 0,
		"income": Income.PATRONAGE, "underground": 0,
		"meal": "lunch", "takings": [-3000, 2000, 3000, 5000],
		"brands": ["Hamburger", "Ramen", "Cucina cinese", "Pizza al taglio", "Caffetteria"],
		"desc": "Pranzo e spuntini. Non rende molto, ma tiene la gente nell edificio.",
	},
	"restaurant": {
		"name": "Ristorante", "kind": Kind.FOOD, "stars": 3,
		"cost": 200000, "w": 24, "h": 1, "capacity": 40, "upkeep": 0,
		"income": Income.PATRONAGE, "underground": 0,
		"meal": "dinner", "takings": [-6000, 4000, 6000, 10000],
		"brands": ["Osteria", "Sushi", "Steakhouse", "Bistrot", "Cucina francese"],
		"desc": "Serve a cena. Rende il doppio del fast food, ma i clienti si trattengono.",
	},
	"shop": {
		"name": "Negozio", "kind": Kind.SHOP, "stars": 3,
		"cost": 100000, "w": 12, "h": 1, "capacity": 25, "upkeep": 0,
		"income": Income.QUARTERLY_RENT, "rents": [6000, 12000, 15000, 20000],
		"underground": 0,
		"brands": ["Animali", "Abbigliamento", "Regali", "Fiorista", "Libreria",
			"Gioielleria", "Dischi", "Giocattoli", "Ottica", "Scarpe", "Elettronica"],
		"desc": "Affittato a trimestre. Se gli affari vanno male, l inquilino se ne va.",
	},

	# --- venues ------------------------------------------------------------
	"party_hall": {
		"name": "Sala feste", "kind": Kind.VENUE, "stars": 3,
		"cost": 100000, "w": 24, "h": 2, "capacity": 50, "upkeep": 0,
		"income": Income.VENUE_TAKE, "take": 20000, "underground": 0,
		"desc": "Con abbastanza camere d albergo si riempie di 50 invitati nel pomeriggio.",
	},
	"cinema": {
		"name": "Cinema", "kind": Kind.VENUE, "stars": 3,
		"cost": 500000, "w": 31, "h": 2, "capacity": 120, "upkeep": 0,
		"income": Income.VENUE_TAKE, "take": 10000, "underground": 0,
		"movie_new": 300000, "movie_classic": 150000,
		"desc": "Il pubblico entra dal piano alto ed esce dal basso. Non si puo demolire.",
	},

	# --- services ----------------------------------------------------------
	"housekeeping": {
		"name": "Servizio pulizie", "kind": Kind.SERVICE, "stars": 2,
		"cost": 50000, "w": 15, "h": 1, "capacity": 6, "upkeep": 10000,
		"income": Income.NONE, "underground": 0,
		"desc": "Sei addetti che rifanno le camere. Usano il montacarichi.",
	},
	"security": {
		"name": "Sicurezza", "kind": Kind.SERVICE, "stars": 2,
		"cost": 100000, "w": 16, "h": 1, "capacity": 4, "upkeep": 20000,
		"income": Income.NONE, "underground": 0,
		"desc": "Spegne gli incendi e cerca le bombe. Usa solo le scale antincendio.",
	},
	"medical": {
		"name": "Pronto soccorso", "kind": Kind.SERVICE, "stars": 3,
		"cost": 500000, "w": 26, "h": 1, "capacity": 4, "upkeep": 0,
		"income": Income.NONE, "underground": 0,
		"desc": "Le torri grandi ne hanno bisogno. Serve soprattutto agli impiegati.",
	},
	"recycling": {
		"name": "Centro riciclaggio", "kind": Kind.SERVICE, "stars": 3,
		"cost": 500000, "w": 25, "h": 2, "capacity": 0, "upkeep": 50000,
		"income": Income.NONE, "underground": 0,
		"desc": "Smaltisce i rifiuti. Va servito da un montacarichi.",
	},

	# --- parking -----------------------------------------------------------
	"parking": {
		"name": "Posto auto", "kind": Kind.PARKING, "stars": 2,
		"cost": 3000, "w": 8, "h": 1, "capacity": 1, "upkeep": 0,
		"income": Income.NONE, "underground": 1, "drag": "repeat",
		"desc": "Solo sottoterra. Ogni fila richiede una rampa.",
	},
	"parking_ramp": {
		"name": "Rampa", "kind": Kind.PARKING, "stars": 2,
		"cost": 50000, "w": 16, "h": 1, "capacity": 0, "upkeep": 10000,
		"income": Income.NONE, "underground": 1, "drag": "v",
		"desc": "Una sola colonna di rampe per torre, collegata all atrio.",
	},

	# --- civic -------------------------------------------------------------
	"metro": {
		"name": "Metropolitana", "kind": Kind.CIVIC, "stars": 4,
		"cost": 1000000, "w": 30, "h": 3, "capacity": 0, "upkeep": 100000,
		"income": Income.NONE, "underground": 1,
		"desc": "Porta clienti e inquilini. Una sola per torre, e niente sotto di essa.",
	},
	"cathedral": {
		"name": "Cattedrale", "kind": Kind.CIVIC, "stars": 5,
		"cost": 3000000, "w": 28, "h": 4, "capacity": 0, "upkeep": 0,
		"income": Income.NONE, "underground": -1,
		"desc": "Solo in cima a una torre di 100 piani. Ti porta al livello GRATTACIELO.",
	},
}

# Order the tool bar reveals things in.
const TOOL_ORDER := [
	"lobby", "floor", "stairs", "escalator",
	"elevator", "service_elevator", "express_elevator",
	"office", "condo",
	"hotel_single", "hotel_twin", "hotel_suite",
	"fastfood", "restaurant", "shop",
	"party_hall", "cinema",
	"housekeeping", "security", "medical", "recycling",
	"parking", "parking_ramp",
	"metro", "cathedral",
]

# Placement caps, as in the original.
const LIMITS := {
	"shafts": 24,            # every elevator type together
	"cars_per_shaft": 8,
	"stairs_escalators": 64,
	"retail": 512,           # fast food + restaurants + shops
	"parking": 512,
	"medical": 10,
	"security": 10,
	"venues": 16,            # cinemas + party halls
	"metro": 1,
	"cathedral": 1,
	"named_sims": 20,
}

const RENT_TIER_NAMES := ["Molto basso", "Basso", "Medio", "Alto"]

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})

static func has_def(id: String) -> bool:
	return DEFS.has(id)

static func kind_of(id: String) -> int:
	return DEFS[id].get("kind", Kind.STRUCTURE)

static func cost_of(id: String) -> int:
	return DEFS[id].get("cost", 0)

static func size_of(id: String) -> Vector2i:
	var d: Dictionary = DEFS[id]
	return Vector2i(d.get("w", 1), d.get("h", 1))

static func stars_for(id: String) -> int:
	return DEFS[id].get("stars", 1)

static func default_rent(id: String) -> int:
	var d: Dictionary = DEFS[id]
	if not d.has("rents"):
		return 0
	return d["rents"][2]

static func is_transport(id: String) -> bool:
	return DEFS.has(id) and DEFS[id]["kind"] == Kind.TRANSPORT

static func is_elevator(id: String) -> bool:
	return id in ["elevator", "service_elevator", "express_elevator"]

## Row index for a human floor number. Floors run 1..100 upwards and
## -1..-10 downwards; there is no floor zero.
static func floor_to_row(f: int) -> int:
	return f - 1 if f > 0 else f

static func row_to_floor(r: int) -> int:
	return r + 1 if r >= 0 else r

## The label the info bar shows for a row: "12" or "B3".
static func row_label(r: int) -> String:
	var f := row_to_floor(r)
	return str(f) if f > 0 else "B" + str(-f)
