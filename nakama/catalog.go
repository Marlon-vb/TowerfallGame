// catalog.go
// Static cosmetic catalog and the XP/level curve. Cosmetics are gated by level;
// "owned" means the player's level has reached the cosmetic's required level.
// This is the server's source of truth; the client mirrors it for display.

package main

const roundsToWin = 3 // mirrors GameConfig.roundsToWin (best of 5)
const mapCount = 10   // mirrors the client's Maps catalog count

type Cosmetic struct {
	ID            string
	Kind          string // "skin" or "trail"
	RequiredLevel int
}

// Order here is the display order; ids must be unique across kinds.
var catalog = []Cosmetic{
	// 9 characters (cosmetic skins) gated by level.
	{ID: "skin_blue", Kind: "skin", RequiredLevel: 1},
	{ID: "skin_red", Kind: "skin", RequiredLevel: 1},
	{ID: "skin_green", Kind: "skin", RequiredLevel: 2},
	{ID: "skin_purple", Kind: "skin", RequiredLevel: 3},
	{ID: "skin_orange", Kind: "skin", RequiredLevel: 4},
	{ID: "skin_gold", Kind: "skin", RequiredLevel: 5},
	{ID: "skin_cyan", Kind: "skin", RequiredLevel: 6},
	{ID: "skin_pink", Kind: "skin", RequiredLevel: 8},
	{ID: "skin_shadow", Kind: "skin", RequiredLevel: 10},
	{ID: "trail_white", Kind: "trail", RequiredLevel: 1},
	{ID: "trail_fire", Kind: "trail", RequiredLevel: 3},
	{ID: "trail_ice", Kind: "trail", RequiredLevel: 4},
}

func requiredLevel(id string) int {
	for _, c := range catalog {
		if c.ID == id {
			return c.RequiredLevel
		}
	}
	return -1 // unknown id
}

func cosmeticKind(id string) string {
	for _, c := range catalog {
		if c.ID == id {
			return c.Kind
		}
	}
	return ""
}

// A cosmetic is owned when the player's level meets its required level.
func isOwned(id string, level int) bool {
	rl := requiredLevel(id)
	return rl >= 1 && level >= rl
}

type Loadout struct {
	Skin  string `json:"skin"`
	Trail string `json:"trail"`
}

func defaultLoadout() Loadout {
	return Loadout{Skin: "skin_blue", Trail: "trail_white"}
}

type Profile struct {
	XP      int     `json:"xp"`
	Level   int     `json:"level"`
	Loadout Loadout `json:"loadout"`
}

func defaultProfile() Profile {
	return Profile{XP: 0, Level: 1, Loadout: defaultLoadout()}
}

// Cumulative XP required to reach a level: 50*(L-1)*L.
// L2=100, L3=300, L4=600, L5=1000, ...
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

// XP earned for a match result. Server-computed; client-reported result is only
// used for these clamped inputs, never trusted for the XP value itself.
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
