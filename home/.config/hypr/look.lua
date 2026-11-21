-- ============================================================
--  Visual "sólido minimalista" — paleta eliasolie-site
--    void    #050505  fundo
--    graphite#161614  superfícies
--    line    #2A2A27  bordas inativas
--    static  #8A8A84  texto secundário
--    bone    #EDEDE8  texto
--    signal  #C8F031  destaque / ativo
--    alert   #FF5A4E  alertas
--  Carregado no fim de hyprland.lua (sobrescreve o visual padrão)
-- ============================================================

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 7,
        border_size = 3,
        col = {
            active_border   = "rgba(c8f031ff)",
            inactive_border = "rgba(2a2a27ff)",
        },
        resize_on_border = true,
        layout = "dwindle",
    },

    decoration = {
        rounding         = 0,     -- cantos retos, igual ao site (rounded-none)
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        dim_inactive     = true,   -- janelas sem foco levemente apagadas: a ativa salta
        dim_strength     = 0.18,
        shadow = { enabled = false },
        blur   = { enabled = false },
    },

    animations = { enabled = true },

    group = {
        col = {
            border_active   = "rgba(c8f031ff)",
            border_inactive = "rgba(2a2a27ff)",
        },
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        background_color        = 0xff050505,
    },

    cursor = { inactive_timeout = 5 },
})

-- Animações curtas e secas (nada elástico)
hl.curve("snap", { type = "bezier", points = { {0.2, 0.9}, {0.1, 1} } })
hl.animation({ leaf = "global",     enabled = true, speed = 3,   bezier = "snap" })
hl.animation({ leaf = "windows",    enabled = true, speed = 2.5, bezier = "snap", style = "slide" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 2.5, bezier = "snap", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2,   bezier = "snap", style = "popin 95%" })
hl.animation({ leaf = "border",     enabled = true, speed = 2,   bezier = "snap" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2,   bezier = "snap" })
hl.animation({ leaf = "layers",     enabled = true, speed = 2,   bezier = "snap", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "snap", style = "slide" })

-- Tema / cursor / Qt
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XCURSOR_THEME", "Eliasolie-Cursor")
hl.env("HYPRCURSOR_THEME", "Eliasolie-Cursor")

-- Pinentry do Bitwarden (rbw) e janelas pequenas flutuando centralizadas
for _, cls in ipairs({ "^pinentry-qt$", "^org.pulseaudio.pavucontrol$", "^blueman-manager$", "^nm-connection-editor$" }) do
    hl.window_rule({ name = "float-" .. cls, match = { class = cls }, float = true, center = true })
end

-- Autostart do visual
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("qs")                 -- wallpaper vivo + widgets do desktop (Quickshell)
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprsunset")         -- luz noturna automática (hyprsunset.conf)
    hl.exec_cmd("nm-applet --indicator")
end)
