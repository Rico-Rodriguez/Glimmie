import SwiftUI

// MARK: - Ready-made sets (Halloween, winter, birthday...)
//
// One tap puts on a whole themed outfit, the scene that goes with it, and a matching outfit on her
// pet if one is with her. Her face and hair stay. Every piece is also in the normal tray, always
// unlocked: sets are only a shortcut.

struct OutfitSet: Identifiable {
    let id: String
    /// The item shown on the set's button.
    let icon: String
    /// category -> item. Clothing and extras not listed come off.
    let picks: [String: String]
    /// category -> cloth color index (otherwise each item's own color).
    var colors: [String: Int] = [:]
    let bg: String
    /// slot -> pet wear item, for her pet.
    var pet: [String: String] = [:]

    static let all: [OutfitSet] = [
        OutfitSet(id: "hanbok", icon: "t_jeogori",
                  picks: ["top": "t_jeogori", "bottom": "b_chima", "neck": "n_norigae", "hat": "h_jokduri", "shoes": "sh_ballet"],
                  colors: ["top": 11, "bottom": 3, "neck": 18, "hat": 19, "shoes": 2], bg: "bg_garden", pet: ["hat": "ph_flowers", "neck": "pn_bowtie"]),
        OutfitSet(id: "jewelFairy", icon: "d_jewelfairy",
                  picks: ["dress": "d_jewelfairy", "hat": "h_hearttiara", "back": "w_jewelwings", "hold": "p_starwand", "socks": "s_frilly", "shoes": "sh_glitter", "earrings": "er_heart"],
                  colors: ["dress": 3, "hat": 4, "back": 18, "hold": 4, "socks": 0, "shoes": 3, "earrings": 4], bg: "bg_rainbow", pet: ["hat": "ph_tiara", "back": "pk_fairy"]),
        OutfitSet(id: "halloween", icon: "d_pumpkin",
                  picks: ["dress": "d_pumpkin", "hat": "h_pointy", "hold": "p_candy", "socks": "s_stripes", "shoes": "sh_maryjane", "back": "w_bat"],
                  colors: ["socks": 8, "shoes": 23, "back": 20], bg: "bg_night", pet: ["hat": "ph_witch", "back": "pk_bat"]),
        OutfitSet(id: "witch", icon: "d_witchy",
                  picks: ["dress": "d_witchy", "hat": "h_witch", "hold": "p_wand", "socks": "s_tights", "shoes": "sh_boots", "neck": "n_star"],
                  colors: ["hat": 19, "socks": 23, "shoes": 20], bg: "bg_space", pet: ["hat": "ph_witch", "neck": "pn_bell"]),
        OutfitSet(id: "winter", icon: "t_snowflake",
                  picks: ["top": "t_snowflake", "bottom": "b_leggings", "hat": "h_earmuffs", "neck": "n_scarf", "shoes": "sh_boots", "hold": "p_cocoa"],
                  colors: ["bottom": 17, "neck": 5, "shoes": 21], bg: "bg_snow", pet: ["body": "pb_sweater", "neck": "pn_scarf"]),
        OutfitSet(id: "birthday", icon: "d_cake",
                  picks: ["dress": "d_cake", "hat": "h_partyhat", "hold": "p_present", "shoes": "sh_glitter", "socks": "s_frilly"],
                  bg: "bg_stage", pet: ["hat": "ph_party", "neck": "pn_bowtie"]),
        OutfitSet(id: "valentine", icon: "n_heart",
                  picks: ["dress": "d_hearts", "hat": "h_bigbow", "hold": "p_balloon", "glasses": "g_heart", "neck": "n_heart", "shoes": "sh_maryjane", "socks": "s_hearts"],
                  colors: ["shoes": 5], bg: "bg_candy", pet: ["glasses": "pg_heart", "neck": "pn_locket"]),
        OutfitSet(id: "beach", icon: "h_sunhat",
                  picks: ["dress": "d_sun", "hat": "h_sunhat", "glasses": "g_sun", "shoes": "sh_sandals", "hold": "p_icecream"],
                  bg: "bg_beach", pet: ["body": "pb_floatie", "glasses": "pg_sun"]),
        OutfitSet(id: "princess", icon: "h_crown",
                  picks: ["dress": "d_gown", "hat": "h_crown", "hold": "p_wand", "neck": "n_pearls", "shoes": "sh_glitter", "back": "w_fairy"],
                  bg: "bg_castle", pet: ["hat": "ph_tiara", "back": "pk_fairy"]),
        OutfitSet(id: "spring", icon: "h_flowers",
                  picks: ["dress": "d_tulip", "hat": "h_flowers", "hold": "p_bouquet", "back": "w_butterfly", "shoes": "sh_sandals"],
                  bg: "bg_garden", pet: ["hat": "ph_flowers", "back": "pk_butterfly"]),
    ]

    /// Categories a set replaces.
    static let dressing = ["dress", "top", "bottom", "outer", "socks", "shoes", "hat", "glasses", "neck", "back", "hold", "earrings"]

    /// `look` wearing this set.
    func apply(to look: Look) -> Look {
        var l = look
        for c in Self.dressing { l.picks[c] = nil; l.colors[c] = nil; l.patterns[c] = nil; l.mixed[c] = nil }
        for (c, id) in picks { l.picks[c] = id }
        for (c, i) in colors { l.colors[c] = i }
        l.bg = bg
        if var p = l.pet {
            for (s, id) in pet {
                p.wear[s] = id
                p.colors[s] = nil
                p.patterns[s] = nil
            }
            l.pet = p.sanitized()
        }
        return l
    }
}
