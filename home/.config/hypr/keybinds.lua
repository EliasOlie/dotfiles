-- ============================================================
--  Atalhos (base: JaKooLit/Hyprland-Dots, filtrados e portados
--  para o config em Lua do Hyprland 0.57)
--  Carregado por hyprland.lua com: require("keybinds")
-- ============================================================

local mainMod    = "SUPER"
local terminal   = "kitty"
local files      = "dolphin"
local scripts    = os.getenv("HOME") .. "/.config/hypr/scripts"

local function bind(keys, dispatcher, desc, opts)
    opts = opts or {}
    opts.description = desc
    return hl.bind(keys, dispatcher, opts)
end

local function sh(cmd) return hl.dsp.exec_cmd(cmd) end

-- ------------------------------------------------------------
-- Básico
-- ------------------------------------------------------------
bind(mainMod .. " + SPACE",  sh("pkill rofi || rofi -show drun -modi drun,filebrowser,run,window"), "lançador de aplicativos")
bind(mainMod .. " + Return", sh(terminal),               "terminal")
bind(mainMod .. " + W",      hl.dsp.window.close(),      "fechar janela")
bind(mainMod .. " + Q",      hl.dsp.window.close(),      "fechar janela (atalho do JaKooLit)")
bind(mainMod .. " + E",      sh(files),                  "gerenciador de arquivos")
bind(mainMod .. " + B",      sh('xdg-open "https://"'),  "navegador padrão")

bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "tela cheia")
bind(mainMod .. " + CTRL + F",  hl.dsp.window.fullscreen({ mode = "maximized" }),  "maximizar")
bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }),         "flutuar janela")

-- Flutuar todas as janelas do workspace atual
bind(mainMod .. " + ALT + SPACE", function()
    local ws = hl.get_active_workspace()
    if not ws then return end
    for _, w in ipairs(hl.get_workspace_windows(ws.id)) do
        hl.dispatch(hl.dsp.window.float({ window = w, action = "toggle" }))
    end
end, "flutuar todas as janelas")

-- Dwindle
bind(mainMod .. " + SHIFT + I", hl.dsp.layout("togglesplit"), "alternar divisão (dwindle)")
bind(mainMod .. " + P",         hl.dsp.window.pseudo(),       "pseudo (dwindle)")

-- Alt+Tab: próxima janela e traz pra frente
bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end, "próxima janela")

-- ------------------------------------------------------------
-- Foco, mover, trocar e redimensionar (setas)
-- ------------------------------------------------------------
for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
    bind(mainMod .. " + " .. key,              hl.dsp.focus({ direction = dir }),          "foco " .. dir)
    bind(mainMod .. " + CTRL + " .. key,       hl.dsp.window.move({ direction = dir }),    "mover janela " .. dir)
    bind(mainMod .. " + ALT + " .. key,        hl.dsp.window.swap({ direction = dir }),    "trocar janela " .. dir)
end

local resize = { left = { -50, 0 }, right = { 50, 0 }, up = { 0, -50 }, down = { 0, 50 } }
for key, d in pairs(resize) do
    bind(mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }),
        "redimensionar " .. key, { repeating = true })
end

-- Mouse: Super + arrastar (esq.) move, (dir.) redimensiona
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "mover janela" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "redimensionar janela" })

-- ------------------------------------------------------------
-- Workspaces POR MONITOR (keycodes 10..19 = teclas 1..0)
--   Cada monitor tem seus próprios workspaces 1..10:
--   eDP-1 usa os IDs 1..10, HDMI-A-1 usa 11..20.
--   Super+N        -> só o monitor atual vai para o workspace N
--   Super+Ctrl+N   -> TODOS os monitores vão para o workspace N
--   Super+Shift+N  -> move a janela para o workspace N do monitor atual (e vai junto)
--   Super+Alt+N    -> idem, sem ir junto
-- ------------------------------------------------------------
local MONITORS = { "eDP-1", "HDMI-A-1" } -- ordem = bloco de IDs (0 -> 1..10, 1 -> 11..20)

local function monitor_index(name)
    for idx, n in ipairs(MONITORS) do
        if n == name then return idx - 1 end
    end
    MONITORS[#MONITORS + 1] = name -- monitor novo: ganha o próximo bloco
    return #MONITORS - 1
end

local function ws_id(n, monitor_name)
    return monitor_index(monitor_name) * 10 + n
end

-- Prende cada bloco de IDs ao seu monitor (workspace 1 de cada monitor é o padrão)
for idx, name in ipairs(MONITORS) do
    for n = 1, 10 do
        hl.workspace_rule({ workspace = tostring((idx - 1) * 10 + n), monitor = name, default = (n == 1) })
    end
end

local function current_monitor()
    local m = hl.get_active_monitor()
    return m and m.name or MONITORS[1]
end

for n = 1, 10 do
    local code = "code:" .. (9 + n)

    bind(mainMod .. " + " .. code, function()
        hl.dispatch(hl.dsp.focus({ workspace = ws_id(n, current_monitor()), on_current_monitor = true }))
    end, "workspace " .. n .. " (monitor atual)")

    bind(mainMod .. " + CTRL + " .. code, function()
        local origin = current_monitor()
        for _, m in ipairs(hl.get_monitors()) do
            hl.dispatch(hl.dsp.focus({ monitor = m.name }))
            hl.dispatch(hl.dsp.focus({ workspace = ws_id(n, m.name), on_current_monitor = true }))
        end
        hl.dispatch(hl.dsp.focus({ monitor = origin }))
    end, "workspace " .. n .. " (todos os monitores)")

    bind(mainMod .. " + SHIFT + " .. code, function()
        hl.dispatch(hl.dsp.window.move({ workspace = ws_id(n, current_monitor()) }))
    end, "mover janela para workspace " .. n)

    bind(mainMod .. " + ALT + " .. code, function()
        hl.dispatch(hl.dsp.window.move({ workspace = ws_id(n, current_monitor()), follow = false }))
    end, "mover janela (sem seguir) para workspace " .. n)
end

bind(mainMod .. " + SHIFT + bracketleft",  hl.dsp.window.move({ workspace = "-1" }),                 "mover para workspace anterior")
bind(mainMod .. " + SHIFT + bracketright", hl.dsp.window.move({ workspace = "+1" }),                 "mover para próximo workspace")
bind(mainMod .. " + CTRL + bracketleft",   hl.dsp.window.move({ workspace = "-1", follow = false }), "mover (sem seguir) para workspace anterior")
bind(mainMod .. " + CTRL + bracketright",  hl.dsp.window.move({ workspace = "+1", follow = false }), "mover (sem seguir) para próximo workspace")

bind(mainMod .. " + Tab",          hl.dsp.focus({ workspace = "m+1" }), "próximo workspace")
bind(mainMod .. " + SHIFT + Tab",  hl.dsp.focus({ workspace = "m-1" }), "workspace anterior")
bind(mainMod .. " + period",       hl.dsp.focus({ workspace = "e+1" }), "próximo workspace")
bind(mainMod .. " + comma",        hl.dsp.focus({ workspace = "e-1" }), "workspace anterior")
bind(mainMod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }), "próximo workspace")
bind(mainMod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }), "workspace anterior")

-- Workspace especial (rascunho)
bind(mainMod .. " + U",         hl.dsp.workspace.toggle_special("magic"),           "mostrar/esconder workspace especial")
bind(mainMod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "special:magic" }), "mover para workspace especial")

-- Mover workspace atual entre monitores (notebook + HDMI)
bind(mainMod .. " + CTRL + F9",  hl.dsp.workspace.move({ monitor = "l" }), "workspace para monitor da esquerda")
bind(mainMod .. " + CTRL + F10", hl.dsp.workspace.move({ monitor = "r" }), "workspace para monitor da direita")
bind(mainMod .. " + CTRL + F11", hl.dsp.workspace.move({ monitor = "u" }), "workspace para monitor de cima")
bind(mainMod .. " + CTRL + F12", hl.dsp.workspace.move({ monitor = "d" }), "workspace para monitor de baixo")

-- ------------------------------------------------------------
-- Terminal dropdown (Super+Shift+Enter)
-- ------------------------------------------------------------
hl.window_rule({
    name      = "dropterm",
    match     = { class = "^dropterm$" },
    float     = true,
    size      = "monitor_w*0.7 monitor_h*0.55",
    move      = "monitor_w*0.15 40",
    workspace = "special:dropterm",
})

bind(mainMod .. " + SHIFT + Return", function()
    if #hl.get_windows({ class = "^dropterm$" }) == 0 then
        hl.exec_cmd(terminal .. " --class dropterm")
    else
        hl.dispatch(hl.dsp.workspace.toggle_special("dropterm"))
    end
end, "terminal dropdown")

-- ------------------------------------------------------------
-- Produtividade (rofi)
-- ------------------------------------------------------------
bind(mainMod .. " + ALT + V",  sh("pkill rofi || cliphist list | rofi -dmenu -p 'Clipboard' | cliphist decode | wl-copy"), "histórico do clipboard")
bind(mainMod .. " + ALT + E",  sh("pkill rofi || rofi -modi emoji -show emoji"),            "emoji")
bind(mainMod .. " + ALT + C",  sh("pkill rofi || rofi -show calc -modi calc -no-show-match -no-sort"), "calculadora")
bind(mainMod .. " + S",        sh(scripts .. "/websearch.sh"),                             "busca na web")
bind(mainMod .. " + CTRL + S", sh("pkill rofi || rofi -show window"),                     "alternar janelas")

bind(mainMod .. " + SHIFT + O", sh(scripts .. "/projects.sh"), "abrir projeto (~/work)")

-- Bitwarden (Vaultwarden auto-hospedado) via rbw + rofi-rbw
bind(mainMod .. " + SHIFT + P", sh(scripts .. "/bitwarden.sh"),      "bitwarden: digitar login/senha")
bind(mainMod .. " + ALT + P",   sh(scripts .. "/bitwarden.sh totp"), "bitwarden: copiar código TOTP")

-- ------------------------------------------------------------
-- Game mode (Super+Shift+G): sem animações, blur, sombras e gaps
-- Desligar = recarregar a config (volta tudo ao normal)
-- ------------------------------------------------------------
-- Função global: também chamada pelos widgets do desktop via
--   hyprctl repl 'GameModeToggle()'   (estado: hyprctl repl 'return tostring(GAMEMODE)')
GAMEMODE = GAMEMODE or false
function GameModeToggle()
    if not GAMEMODE then
        hl.config({
            animations = { enabled = false },
            decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } },
            general    = { gaps_in = 0, gaps_out = 0, border_size = 1 },
        })
        GAMEMODE = true
        hl.notification.create({ text = "Game mode LIGADO", timeout = 2000 })
    else
        GAMEMODE = false
        hl.dispatch(hl.dsp.reload_config())
        hl.notification.create({ text = "Game mode desligado", timeout = 2000 })
    end
end
bind(mainMod .. " + SHIFT + G", GameModeToggle, "game mode")

-- Luz noturna (hyprsunset)
bind(mainMod .. " + N", sh("pkill -x hyprsunset || hyprsunset -t 4500"), "luz noturna")

-- ------------------------------------------------------------
-- Sistema
-- ------------------------------------------------------------
bind("CTRL + ALT + Delete", hl.dsp.exit(),                    "sair do Hyprland")
bind("CTRL + ALT + L",      sh("pidof hyprlock || hyprlock"), "bloquear tela")
bind("CTRL + ALT + P",      sh(scripts .. "/powermenu.sh"),   "menu de energia")
bind(mainMod .. " + SHIFT + N", sh("swaync-client -t -sw"),   "painel de notificações")

-- Matar o processo da janela ativa (kill -9)
bind(mainMod .. " + SHIFT + Q", function()
    local w = hl.get_active_window()
    if w and w.pid and w.pid > 0 then
        hl.exec_cmd("kill -9 " .. w.pid)
    end
end, "matar processo da janela")

-- Screenshots (no notebook pode precisar do Fn junto com Print)
bind(mainMod .. " + Print",                sh(scripts .. "/screenshot.sh now"),    "screenshot da tela")
bind(mainMod .. " + SHIFT + Print",        sh(scripts .. "/screenshot.sh area"),   "screenshot de área")
bind(mainMod .. " + CTRL + Print",         sh(scripts .. "/screenshot.sh in5"),    "screenshot em 5s")
bind(mainMod .. " + CTRL + SHIFT + Print", sh(scripts .. "/screenshot.sh in10"),   "screenshot em 10s")
bind("ALT + Print",                        sh(scripts .. "/screenshot.sh active"), "screenshot da janela ativa")
bind(mainMod .. " + SHIFT + S",            sh(scripts .. "/screenshot.sh swappy"), "screenshot de área + editor")

-- ------------------------------------------------------------
-- Teclas de mídia, volume e brilho (com aviso na tela)
-- ------------------------------------------------------------
local hot = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume",       sh(scripts .. "/osd.sh vol-up 5"),   "volume +", hot)
bind("XF86AudioLowerVolume",       sh(scripts .. "/osd.sh vol-down 5"), "volume -", hot)
bind("ALT + XF86AudioRaiseVolume", sh(scripts .. "/osd.sh vol-up 1"),   "volume + (fino)", hot)
bind("ALT + XF86AudioLowerVolume", sh(scripts .. "/osd.sh vol-down 1"), "volume - (fino)", hot)
bind("XF86AudioMute",              sh(scripts .. "/osd.sh mute"),       "mudo",          { locked = true })
bind("XF86AudioMicMute",           sh(scripts .. "/osd.sh mic"),        "microfone mudo", { locked = true })
bind("XF86MonBrightnessUp",        sh(scripts .. "/osd.sh br-up"),      "brilho +", hot)
bind("XF86MonBrightnessDown",      sh(scripts .. "/osd.sh br-down"),    "brilho -", hot)
bind("XF86Sleep",                  sh("systemctl suspend"),             "suspender",     { locked = true })

local media = { locked = true }
bind("XF86AudioPlay",  sh("playerctl play-pause"), "play/pause",  media)
bind("XF86AudioPause", sh("playerctl play-pause"), "play/pause",  media)
bind("XF86AudioNext",  sh("playerctl next"),       "próxima",     media)
bind("XF86AudioPrev",  sh("playerctl previous"),   "anterior",    media)
bind("XF86AudioStop",  sh("playerctl stop"),       "parar",       media)
