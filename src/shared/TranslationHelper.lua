local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

local TranslationHelper = {}
local translator = nil

-- Lazy loader function that retries if needed, preventing hangs
local function getTranslator()
    if translator then return translator end
    
    local player = Players.LocalPlayer
    if not player then
        -- Safe wait for player on client, fallback to PlayerAdded if nil (e.g. server execution, though helper is mostly client)
        player = Players.LocalPlayer or Players.PlayerAdded:Wait()
    end
    
    if player then
        local success, result = pcall(function()
            return LocalizationService:GetTranslatorForPlayerAsync(player)
        end)
        if success then
            translator = result
            return translator
        end
    end
    return nil
end

-- Try loading translator on startup in background, but do NOT block or wait forever
task.spawn(function()
    pcall(getTranslator)
end)

-- Local dictionary for Portuguese fallback translation
local portugueseTranslations = {
    ["YOU WON!"] = "VOCÊ VENCEU!",
    ["You rescued all the kittens safely!"] = "Você resgatou todos os gatinhos em segurança!",
    ["Time:"] = "Tempo:",
    ["OK"] = "OK",
    ["KITTEN RESCUE SHOP"] = "LOJA DE RESGATE DE GATINHOS",
    ["Join our Roblox Group for 20% off all items!"] = "Junte-se ao nosso Grupo do Roblox para 20% de desconto em todos os itens!",
    ["PERMANENT Minimap"] = "Minimapa PERMANENTE",
    ["PERMANENT Flashlight Upgrade"] = "Melhoria de Lanterna PERMANENTE",
    ["Invisibility Potion"] = "Poção de Invisibilidade",
    ["Energy Drink"] = "Energético",
    ["Shield"] = "Escudo",
    ["Bone"] = "Osso",
    ["Flashlight Upgrade"] = "Melhoria de Lanterna",
    ["Minimap"] = "Minimapa",
    ["Bandage"] = "Atadura",
    ["Double Jump Boots"] = "Botas de Pulo Duplo",
    ["Allows you to jump a second time in mid-air."] = "Permite pular uma segunda vez no ar.",
    ["Triple Jump Boots"] = "Botas de Pulo Triplo",
    ["Allows you to jump a third time in mid-air."] = "Permite pular uma terceira vez no ar.",
    ["Become invisible to dogs for 10 seconds."] = "Fique invisível para os cachorros por 10 segundos.",
    ["Run faster for 10 seconds."] = "Corra mais rápido por 10 segundos.",
    ["Survive one dog attack."] = "Sobreviva a um ataque de cachorro.",
    ["Throw to distract the closest dog."] = "Jogue para distrair o cachorro mais próximo.",
    ["A miner's helmet with an infinite light. Replaces your handheld flashlight."] = "Um capacete de minerador com luz infinita. Substitui sua lanterna de mão.",
    ["A miner's helmet with an infinite light FOREVER! (Robux)"] = "Um capacete de minerador com luz infinita PARA SEMPRE! (Robux)",
    ["See the maze and remaining cats."] = "Veja o labirinto e os gatinhos restantes.",
    ["See the maze and remaining cats FOREVER! (Robux)"] = "Veja o labirinto e os gatinhos restantes PARA SEMPRE! (Robux)",
    ["Heal yourself from hazard damage."] = "Cure-se de danos de perigos.",
    ["(20% OFF)"] = "(20% DESCONTO)",
    ["BUY"] = "COMPRAR",
    ["Buy"] = "Comprar",
    ["Owned!"] = "Adquirido!",
    ["Processing..."] = "Processando...",
    ["Success!"] = "Sucesso!",
    ["Failed"] = "Falhou",
    ["Use"] = "Usar",
    ["Graphics Mode"] = "Modo Gráfico",
    ["Quality"] = "Qualidade",
    ["Fast"] = "Rápido",
    ["Vibration"] = "Vibração",
    ["On"] = "Ligado",
    ["Off"] = "Desligado",
    ["This game was created by beabadoobeelson"] = "Este jogo foi criado por beabadoobeelson",
    ["Controls:"] = "Controles:",
    ["Move"] = "Mover",
    ["L-STICK"] = "L-STICK",
    ["Look"] = "Olhar",
    ["R-STICK"] = "R-STICK",
    ["Sprint"] = "Correr",
    ["Right Trigger"] = "Gatilho Direito",
    ["Use Item"] = "Usar Item",
    ["Cycle Items"] = "Alternar Itens",
    ["Interact"] = "Interagir",
    ["Settings"] = "Configurações",
    ["Map Zoom In"] = "Aproximar Mapa",
    ["Map Zoom Out"] = "Afastar Mapa",
    ["L-JOYSTICK"] = "L-JOYSTICK",
    ["Drag Screen"] = "Arrastar Tela",
    ["Sprint Button"] = "Botão de Correr",
    ["Tap Item"] = "Tocar no Item",
    ["Tap Prompt"] = "Tocar na Ação",
    ["Map Zoom"] = "Zoom do Mapa",
    ["Tap +/-"] = "Tocar em +/-",
    ["W A S D"] = "W A S D",
    ["Mouse"] = "Mouse",
    ["SHIFT"] = "SHIFT",
    ["or"] = "ou",
    ["Click"] = "Clique",
    ["E"] = "E",
    ["START"] = "START",
    ["DPad UP"] = "D-Pad CIMA",
    ["DPad DOWN"] = "D-Pad BAIXO",
    ["Play"] = "Jogar",
    ["Shop"] = "Loja",
    ["Credits"] = "Créditos",
    ["Controls"] = "Controles",
    ["Back"] = "Voltar",
    ["Close"] = "Fechar",
    ["Resume"] = "Retomar",
    ["Reset"] = "Reiniciar",
    ["Open Shop"] = "Abrir Loja",
    ["Shop Stand"] = "Balcão da Loja",
    ["Revive"] = "Reviver",
    ["Try Again"] = "Tentar Novamente",
    ["Game Over"] = "Fim de Jogo",
    ["You were caught by the dogs!"] = "Você foi pego pelos cachorros!",
    
    -- Objectives and instructions
    ["<b><font size=\"20\">Objective:</font></b>\nRescue all 13 cats from the maze, find keys to open doors, and then the final door will open!"] = "<b><font size=\"20\">Objetivo:</font></b>\nResgate todos os 13 gatos do labirinto, encontre chaves para abrir as portas, e a porta final se abrirá!",
    ["\n<b><font size=\"20\">Hazards & HP:</font></b>\nSpikes, Lava, and Evil Dogs deal damage. Keep an eye on your HP bar (❤️)! If you drop to 0 HP, you will die."] = "\n<b><font size=\"20\">Perigos e Vida (HP):</font></b>\nEspinhos, Lava e Cães Malvados causam dano. Fique de olho na sua barra de vida (❤️)! Se ela chegar a 0, você morrerá.",
    ["\n<b><font size=\"20\">Items & Coins:</font></b>\nCollect coins to buy useful items in the shop. Buy Bandages to restore your HP, or upgrades to gain advantages like seeing through walls and escaping dogs!"] = "\n<b><font size=\"20\">Itens e Moedas:</font></b>\nColete moedas para comprar itens úteis na loja. Compre Ataduras para restaurar sua vida, ou melhorias para obter vantagens como ver através das paredes e escapar dos cães!",
    ["\n<b><font size=\"20\">Stars:</font></b>\nThe faster you collect all cats and return to the Safe Zone, the more stars you earn."] = "\n<b><font size=\"20\">Estrelas:</font></b>\nQuanto mais rápido você coletar todos os gatos e retornar à Zona Segura, mais estrelas você ganhará."
}

-- Translate function with fallback to source text if translator isn't loaded or fails
function TranslationHelper.translate(sourceText, contextInstance)
    if typeof(sourceText) ~= "string" or sourceText == "" then
        return sourceText
    end
    
    -- 1. Try to use Roblox's official translator first (auto translations enabled by user)
    local t = getTranslator()
    if t then
        local success, translated = pcall(function()
            return t:Translate(contextInstance or game, sourceText)
        end)
        -- If Roblox returned a translated text that is different from sourceText, use it!
        if success and translated and translated ~= sourceText then
            return translated
        end
    end
    
    -- 2. Fallback to our local dictionary for Portuguese if player locale is Portuguese
    local localeId = LocalizationService.RobloxLocaleId
    if localeId and string.sub(string.lower(localeId), 1, 2) == "pt" then
        local localTranslation = portugueseTranslations[sourceText]
        if localTranslation then
            return localTranslation
        end
    end
    
    return sourceText
end

return TranslationHelper
