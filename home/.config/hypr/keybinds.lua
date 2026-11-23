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
-- Maximizar: janela lado a lado usa o "maximizado" do Hyprland; janela FLUTUANTE
-- (ex.: uma janela solta) cresce até preencher o monitor atual (respeitando a waybar) e
-- volta ao tamanho anterior no segundo toque. Não manda "tela cheia" pro app
-- (o Chromium tratava o maximizado de flutuante como F11) e não troca de monitor.
FLOAT_MAX = FLOAT_MAX or {}
function MaximizeToggle()
    local w = hl.get_active_window()
    if not w then return end
    if not w.floating then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized" }))
        return
    end
    local m = hl.get_active_monitor()
    local key = tostring(w.address)
    if FLOAT_MAX[key] then
        local s = FLOAT_MAX[key]; FLOAT_MAX[key] = nil
        hl.dispatch(hl.dsp.window.resize({ x = s.x, y = s.y, relative = false }))
    else
        FLOAT_MAX[key] = { x = w.size.x, y = w.size.y }
        local r, gap = m.reserved, 7
        hl.dispatch(hl.dsp.window.resize({ x = m.width - r.left - r.right - 2 * gap,
                                           y = m.height - r.top - r.bottom - 2 * gap, relative = false }))
    end
    hl.dispatch(hl.dsp.window.center())
end
bind(mainMod .. " + CTRL + F", MaximizeToggle, "maximizar (flutuante: preenche o monitor; de novo volta)")
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

-- Vai-e-volta: apertar o número do workspace em que você já está volta para o
-- anterior daquele monitor (1 -> 2, Super+2 de novo -> 1). O "anterior" é
-- registrado em toda troca de workspace (atalho, clique na waybar, Super+D...).
WS_CUR, WS_PREV = WS_CUR or {}, WS_PREV or {}   -- globais: dá para inspecionar com hyprctl repl
hl.on("workspace.active", function()
    local m = hl.get_active_monitor()
    if not m or not m.active_workspace then return end
    local id = m.active_workspace.id
    if WS_CUR[m.name] ~= id then
        WS_PREV[m.name] = WS_CUR[m.name]
        WS_CUR[m.name] = id
    end
end)

for n = 1, 10 do
    local code = "code:" .. (9 + n)

    bind(mainMod .. " + " .. code, function()
        local m = hl.get_active_monitor()
        local name = m and m.name or MONITORS[1]
        local target = ws_id(n, name)
        local cur = m and m.active_workspace and m.active_workspace.id
        if cur == target and WS_PREV[name] then target = WS_PREV[name] end
        hl.dispatch(hl.dsp.focus({ workspace = target, on_current_monitor = true }))
    end, "workspace " .. n .. " (monitor atual; de novo = volta ao anterior)")

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

-- ------------------------------------------------------------
-- Super+D: mostrar o desktop (alterna)
--   1ª vez: o monitor atual vai para um workspace vazio do seu bloco
--           (procura do 0 para o 1), mostrando wallpaper e widgets
--   2ª vez: volta para o workspace onde você estava
-- ------------------------------------------------------------
local DESK_PREV = {}   -- nome do monitor -> workspace de onde saiu

local function ws_is_empty(id)
    local ok, wins = pcall(hl.get_workspace_windows, id)
    return (not ok) or wins == nil or #wins == 0
end

function ShowDesktop()
    local m = hl.get_active_monitor()
    if not m or not m.active_workspace then return end
    local cur = m.active_workspace.id

    -- Já está no desktop vindo do Super+D: volta
    if DESK_PREV[m.name] and ws_is_empty(cur) then
        local prev = DESK_PREV[m.name]
        DESK_PREV[m.name] = nil
        hl.dispatch(hl.dsp.focus({ workspace = prev, on_current_monitor = true }))
        return
    end
    if ws_is_empty(cur) then return end  -- já está vazio, nada a fazer

    local base = monitor_index(m.name) * 10
    for n = 10, 1, -1 do
        local id = base + n
        if id ~= cur and ws_is_empty(id) then
            DESK_PREV[m.name] = cur
            hl.dispatch(hl.dsp.focus({ workspace = id, on_current_monitor = true }))
            return
        end
    end
    hl.notification.create({ text = "Nenhum workspace vazio neste monitor", timeout = 2000 })
end
bind(mainMod .. " + D", ShowDesktop, "mostrar o desktop (alterna)")

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
bind(mainMod .. " + ALT + V",  sh(scripts .. "/rofi-tools.sh clip"), "histórico do clipboard")
bind(mainMod .. " + ALT + E",  sh(scripts .. "/rofi-tools.sh emoji"), "emoji")
bind(mainMod .. " + ALT + C",  sh(scripts .. "/rofi-tools.sh calc"),  "calculadora")
bind(mainMod .. " + S",        sh(scripts .. "/websearch.sh"),                             "busca na web")
bind(mainMod .. " + CTRL + S", sh("pkill rofi || rofi -show window"),                     "alternar janelas")

bind(mainMod .. " + SHIFT + O", sh(scripts .. "/projects.sh"), "abrir projeto (~/work)")
bind(mainMod .. " + ALT + D",   sh("qs ipc call desktop toggleCompact"), "desktop compacto (monitor atual)")
bind(mainMod .. " + SHIFT + A", sh("qs ipc call desktop newEvent"), "agenda: novo evento (EliasOlie, ConectaMe ou Pessoal)")
bind(mainMod .. " + A",         sh("qs ipc call desktop toggleAgenda"), "agenda grande no centro (monitor atual)")
bind(mainMod .. " + O",        sh("qs ipc call overview toggle"),    "visão geral das janelas (monitor em foco)")
bind(mainMod .. " + CTRL + O", sh("qs ipc call overview toggleAll"), "visão geral das janelas (todos os monitores)")
-- Ferramentas rápidas
bind(mainMod .. " + SHIFT + J", sh(scripts .. "/janus.py registrar"), "Janus: registrar decisão/nota")
bind(mainMod .. " + SHIFT + C", sh(scripts .. "/colorpick.sh"),       "conta-gotas (copia a cor #hex)")
bind(mainMod .. " + SHIFT + T", sh(scripts .. "/ocr.sh"),             "copiar texto de uma área da tela")
bind(mainMod .. " + SHIFT + R", sh(scripts .. "/rec.sh"),             "gravar tela (liga/desliga)")

-- Fixar janela por cima de tudo (aparece em todos os workspaces); flutua se precisar
function PinToggle()
    local w = hl.get_active_window()
    if not w then return end
    if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "toggle" })) end
    hl.dispatch(hl.dsp.window.pin())
end
bind(mainMod .. " + CTRL + P", PinToggle, "fixar janela por cima de tudo (liga/desliga)")

bind(mainMod .. " + H",         sh(scripts .. "/keybinds.py"),    "mostrar todos os atalhos")
bind(mainMod .. " + Y",         sh(scripts .. "/agyh-menu.py"),   "agyh: buscar sessões (Claude, agy…)")
bind(mainMod .. " + J",         sh(scripts .. "/janus.py"),       "buscar no Janus")
bind(mainMod .. " + ALT + F",   sh(scripts .. "/focus.sh toggle"), "modo foco (25 min, não perturbe)")

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
bind(mainMod .. " + N", sh(scripts .. "/nightlight.sh toggle"), "luz noturna (liga/desliga; automática por horário)")

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

-- Monitor saiu/voltou: resgata as janelas do bloco dele e devolve depois
-- (sem isso, tirar o monitor externo deixava janelas nos workspaces 11..20 inalcançáveis)
hl.on("monitor.removed", function() hl.exec_cmd(scripts .. "/monitors.sh removed") end)
hl.on("monitor.added",   function() hl.exec_cmd(scripts .. "/monitors.sh added") end)
