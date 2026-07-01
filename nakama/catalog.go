// catalog.go
// Avatar item catalog and the XP/coin curves. An avatar is a set of equipped
// item ids, one per slot. Items with Cost == 0 are free base options (always
// owned); items with Cost > 0 are store items the player buys with coins.
// This is the server's source of truth; the client mirrors ids + costs.

package main

const roundsToWin = 3 // mirrors GameConfig.roundsToWin (best of 5)
const mapCount = 10   // mirrors the client's Maps catalog count

type Item struct {
	ID   string
	Slot string // "skin", "hair", "shirt", "pants", "head", "trail"
	Cost int    // 0 == free base option
}

// Free base options + paid store items. Ids must be unique across slots.
var items = []Item{
	// Skin tones (free).
	{ID: "skin_1", Slot: "skin", Cost: 0},
	{ID: "skin_2", Slot: "skin", Cost: 0},
	{ID: "skin_3", Slot: "skin", Cost: 0},
	{ID: "skin_4", Slot: "skin", Cost: 0},
	{ID: "skin_5", Slot: "skin", Cost: 0},
	// Hair colors (free base) + premium.
	{ID: "hair_black", Slot: "hair", Cost: 0},
	{ID: "hair_brown", Slot: "hair", Cost: 0},
	{ID: "hair_blonde", Slot: "hair", Cost: 0},
	{ID: "hair_red", Slot: "hair", Cost: 0},
	{ID: "hair_gray", Slot: "hair", Cost: 0},
	{ID: "hair_white", Slot: "hair", Cost: 0},
	{ID: "hair_blue", Slot: "hair", Cost: 120},
	{ID: "hair_pink", Slot: "hair", Cost: 120},
	// Shirts (free base) + premium.
	{ID: "shirt_gray", Slot: "shirt", Cost: 0},
	{ID: "shirt_green", Slot: "shirt", Cost: 0},
	{ID: "shirt_blue", Slot: "shirt", Cost: 0},
	{ID: "shirt_red", Slot: "shirt", Cost: 0},
	{ID: "shirt_gold", Slot: "shirt", Cost: 150},
	// Pants (free base) + premium.
	{ID: "pants_navy", Slot: "pants", Cost: 0},
	{ID: "pants_brown", Slot: "pants", Cost: 0},
	{ID: "pants_black", Slot: "pants", Cost: 0},
	{ID: "pants_teal", Slot: "pants", Cost: 0},
	// Head accessories: none is free, the rest are store items.
	{ID: "head_none", Slot: "head", Cost: 0},
	{ID: "head_cap", Slot: "head", Cost: 100},
	{ID: "head_helmet", Slot: "head", Cost: 200},
	{ID: "head_horns", Slot: "head", Cost: 250},
	{ID: "head_halo", Slot: "head", Cost: 350},
	{ID: "head_crown", Slot: "head", Cost: 500},
	// Limited fun heads.
	{ID: "head_fish", Slot: "head", Cost: 600},
	{ID: "head_crow", Slot: "head", Cost: 550},
	{ID: "head_tv", Slot: "head", Cost: 500},
	{ID: "head_frog", Slot: "head", Cost: 450},
	{ID: "head_cat", Slot: "head", Cost: 350},
	{ID: "head_wizard", Slot: "head", Cost: 400},
	{ID: "head_pirate", Slot: "head", Cost: 400},
	{ID: "head_viking", Slot: "head", Cost: 400},
	{ID: "head_ninja", Slot: "head", Cost: 300},
	// Bows: wood free, others store items.
	{ID: "bow_wood", Slot: "bow", Cost: 0},
	{ID: "bow_silver", Slot: "bow", Cost: 300},
	{ID: "bow_gold", Slot: "bow", Cost: 500},
	{ID: "bow_crystal", Slot: "bow", Cost: 800},
	// Arrow trails: white free, others store items.
	{ID: "trail_white", Slot: "trail", Cost: 0},
	{ID: "trail_fire", Slot: "trail", Cost: 200},
	{ID: "trail_ice", Slot: "trail", Cost: 200},
}

func itemByID(id string) (Item, bool) {
	for _, it := range items {
		if it.ID == id {
			return it, true
		}
	}
	return Item{}, false
}

type Avatar struct {
	Skin  string `json:"skin"`
	Hair  string `json:"hair"`
	Shirt string `json:"shirt"`
	Pants string `json:"pants"`
	Head  string `json:"head"`
	Trail string `json:"trail"`
	Bow   string `json:"bow"`
}

func defaultAvatar() Avatar {
	return Avatar{
		Skin:  "skin_2",
		Hair:  "hair_brown",
		Shirt: "shirt_gray",
		Pants: "pants_navy",
		Head:  "head_none",
		Trail: "trail_white",
		Bow:   "bow_wood",
	}
}

type Profile struct {
	XP     int      `json:"xp"`
	Level  int      `json:"level"`
	Coins  int      `json:"coins"`
	Owned  []string `json:"owned"` // purchased item ids (free items are implicitly owned)
	Avatar Avatar   `json:"avatar"`
	Rating int      `json:"rating"` // ranked ELO; starts at baseRating
}

const baseRating = 1000
const minRating = 100

func defaultProfile() Profile {
	return Profile{XP: 0, Level: 1, Coins: 0, Owned: []string{}, Avatar: defaultAvatar(), Rating: baseRating}
}

func ownsItem(profile Profile, id string) bool {
	it, ok := itemByID(id)
	if !ok {
		return false
	}
	if it.Cost == 0 {
		return true // free base option
	}
	for _, owned := range profile.Owned {
		if owned == id {
			return true
		}
	}
	return false
}

// Validates that an equipped item exists and matches the slot.
func itemInSlot(id, slot string) bool {
	it, ok := itemByID(id)
	return ok && it.Slot == slot
}

// Cumulative XP required to reach a level: 50*(L-1)*L.
func xpToReach(level int) int {
	if level <= 1 {
		return 0
	}
	return 50 * (level - 1) * level
}

func levelForXP(xp int) int {
	level := 1
	for xpToReach(level+1) <= xp {
		level++
	}
	return level
}

func xpForMatch(won bool, kills int) int {
	if kills < 0 {
		kills = 0
	}
	if kills > roundsToWin {
		kills = roundsToWin
	}
	gain := 50 + kills*25
	if won {
		gain += 75
	}
	return gain
}

func coinsForMatch(won bool, kills int) int {
	if kills < 0 {
		kills = 0
	}
	if kills > roundsToWin {
		kills = roundsToWin
	}
	gain := 10 + kills*5
	if won {
		gain += 20
	}
	return gain
}
