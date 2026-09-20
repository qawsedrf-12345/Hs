--=============================================================
-- 🛡️ ANTI-VOID v4 — Sistema de TP temporário pós-respawn
-- Ao respawnar: cria um "LocalSeguro" que dura 5s
-- Nesses 5s: se detectar queda → TP imediato pro LocalSeguro
-- Após 5s: deleta o LocalSeguro e volta ao normal
--=============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting   = game:GetService("Lighting")

local player = Players.LocalPlayer

--=============================================================
-- CONFIG
--=============================================================
local CONFIG = {
    -- 🎯 LocalSeguro temporário (pós-respawn)
    LocalSeguroDuracao = 5,          -- ⏱️ quanto tempo dura o local (5s)
    TempoCaindoLimite  = 0.2,        -- ⏱️ durante o LocalSeguro, TP com 0.2s caindo
    OffsetY            = 3,

    -- 🎯 Modo normal (fora do LocalSeguro)
    TempoCaindoNormal  = 0.4,        -- ⏱️ sem LocalSeguro, TP com 0.4s caindo
    VelocidadeMinimaCaindo = -30,
    AlturaSegura = 50,

    -- 🔍 Busca em espiral (só usada no modo normal)
    RaioInicial    = 5,
    RaioIncremento = 5,
    RaioMaximo     = 2000,
    PassosPorAnel  = 16,
    AlturaAcima    = 60,
    AlturaAbaixo   = 300,

    -- 🎨 Cores
    CorFade    = Color3.fromRGB(0, 220, 255),
    CorEfeito  = Color3.fromRGB(50, 255, 130),
    CorRGB     = Color3.fromRGB(0, 255, 255),

    TransparenciaFade = 0.55,
    DuracaoFade       = 0.6,

    EfeitoFlash      = true,
    FlashDuracao     = 0.18,
    EfeitoRGBSplit   = true,
    RGBDuracao       = 0.4,
    RGBDeslocamento  = 12,
    RGBPulsos        = 3,
    EfeitoScanlines  = true,
    ScanlinesDuracao = 0.5,
    ScanlinesVelocidade = 3,
    EfeitoOndas      = true,
    OndasQuantidade  = 4,
    OndasDuracao     = 0.6,
    EfeitoEco        = true,
    EcoDuracao       = 0.5,
    EfeitoParticulas = true,
    ParticulasQuantidade = 80,
    EfeitoGlitch     = true,
    GlitchDuracao    = 0.4,
    GlitchQuantidade = 30,
    EfeitoBlur       = true,
    BlurTamanho      = 12,
    BlurDuracao      = 0.5,
    EfeitoShake      = true,
    ShakeIntensidade = 1.5,
    ShakeDuracao     = 0.3,
    EfeitoFeixe      = true,
    FeixeDuracao     = 0.6,

    Debug = true,
}

--=============================================================
-- ESTADO
--=============================================================
local ultimaPosicaoSegura = nil
local tpCooldown = false
local tempoCaindo = 0
local ultimoTempo = os.clock()
local ultimaPos = nil

-- 🛡️ LocalSeguro temporário
local localSeguroCFrame = nil
local localSeguroAtivo = false
local localSeguroExpira = 0

local function log(...)
    if CONFIG.Debug then print("[AntiVoid]", ...) end
end

--=============================================================
-- 🌟 GUI DE EFEITOS
--=============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiVoidEffects"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.Parent = player:WaitForChild("PlayerGui")

local fadeFrame = Instance.new("Frame")
fadeFrame.Size = UDim2.new(1, 0, 1, 0)
fadeFrame.BackgroundColor3 = CONFIG.CorFade
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel = 0
fadeFrame.ZIndex = 1000
fadeFrame.Parent = screenGui

local flashFrame = Instance.new("Frame")
flashFrame.Size = UDim2.new(1, 0, 1, 0)
flashFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel = 0
flashFrame.ZIndex = 1001
flashFrame.Parent = screenGui

local rgbContainer = Instance.new("Frame")
rgbContainer.Size = UDim2.new(1, 0, 1, 0)
rgbContainer.BackgroundTransparency = 1
rgbContainer.ZIndex = 998
rgbContainer.Parent = screenGui

local rgbR = Instance.new("Frame")
rgbR.Size = UDim2.new(1, 0, 1, 0)
rgbR.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
rgbR.BackgroundTransparency = 1
rgbR.BorderSizePixel = 0
rgbR.ZIndex = 998
rgbR.Parent = rgbContainer

local rgbB = Instance.new("Frame")
rgbB.Size = UDim2.new(1, 0, 1, 0)
rgbB.BackgroundColor3 = Color3.fromRGB(0, 0, 255)
rgbB.BackgroundTransparency = 1
rgbB.BorderSizePixel = 0
rgbB.ZIndex = 998
rgbB.Parent = rgbContainer

local scanlinesFrame = Instance.new("Frame")
scanlinesFrame.Size = UDim2.new(1, 0, 1, 0)
scanlinesFrame.BackgroundTransparency = 1
scanlinesFrame.ZIndex = 999
scanlinesFrame.Parent = screenGui

local scanlineCount = 80
local scanlines = {}
for i = 1, scanlineCount do
    local linha = Instance.new("Frame")
    linha.Size = UDim2.new(1, 0, 0, 2)
    linha.Position = UDim2.new(0, 0, (i - 1) / scanlineCount, 0)
    linha.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    linha.BackgroundTransparency = 1
    linha.BorderSizePixel = 0
    linha.ZIndex = 999
    linha.Parent = scanlinesFrame
    table.insert(scanlines, linha)
end

local ondasContainer = Instance.new("Frame")
ondasContainer.Size = UDim2.new(1, 0, 1, 0)
ondasContainer.BackgroundTransparency = 1
ondasContainer.ZIndex = 1003
ondasContainer.Parent = screenGui

local ecoContainer = Instance.new("Frame")
ecoContainer.Size = UDim2.new(1, 0, 1, 0)
ecoContainer.BackgroundTransparency = 1
ecoContainer.ZIndex = 997
ecoContainer.Parent = screenGui

local particulasContainer = Instance.new("Frame")
particulasContainer.Size = UDim2.new(1, 0, 1, 0)
particulasContainer.BackgroundTransparency = 1
particulasContainer.ZIndex = 1005
particulasContainer.Parent = screenGui

local glitchContainer = Instance.new("Frame")
glitchContainer.Size = UDim2.new(1, 0, 1, 0)
glitchContainer.BackgroundTransparency = 1
glitchContainer.ZIndex = 1006
glitchContainer.Parent = screenGui

local feixeFrame = Instance.new("Frame")
feixeFrame.Size = UDim2.new(0, 4, 0, 0)
feixeFrame.Position = UDim2.new(0.5, -2, 0.5, 0)
feixeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
feixeFrame.BackgroundColor3 = Color3.fromRGB(200, 255, 255)
feixeFrame.BackgroundTransparency = 1
feixeFrame.BorderSizePixel = 0
feixeFrame.ZIndex = 1002
feixeFrame.Parent = screenGui

local feixeGradient = Instance.new("UIGradient")
feixeGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1, 1),
})
feixeGradient.Parent = feixeFrame

local blurEffect = nil

--=============================================================
-- FUNÇÕES DE EFEITO
--=============================================================
local function criarBlur(tamanho)
    if blurEffect and blurEffect.Parent then blurEffect:Destroy() end
    blurEffect = Instance.new("BlurEffect")
    blurEffect.Size = 0
    blurEffect.Parent = Lighting
    TweenService:Create(blurEffect, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Size = tamanho }):Play()
end

local function removerBlur(duracao)
    if not blurEffect then return end
    local b = blurEffect
    local tween = TweenService:Create(b, TweenInfo.new(duracao or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 0 })
    tween:Play()
    tween.Completed:Connect(function()
        if b and b.Parent then b:Destroy() end
        if blurEffect == b then blurEffect = nil end
    end)
end

local function flashTela(cor, duracao)
    flashFrame.BackgroundColor3 = cor
    flashFrame.BackgroundTransparency = 0
    TweenService:Create(
        flashFrame,
        TweenInfo.new(duracao or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    ):Play()
end

local function cameraShake(intensidade, duracao)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local inicio = tick()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if tick() - inicio >= duracao then
            conn:Disconnect()
            return
        end
        local p = 1 - ((tick() - inicio) / duracao)
        local sx = (math.random() - 0.5) * 2 * intensidade * p / 100
        local sy = (math.random() - 0.5) * 2 * intensidade * p / 100
        camera.CFrame = camera.CFrame * CFrame.new(sx, sy, 0)
    end)
end

local function efeitoRGBSplit(duracao, deslocamento, pulsos)
    pulsos = pulsos or 1
    task.spawn(function()
        for _ = 1, pulsos do
            task.spawn(function()
                rgbR.BackgroundTransparency = 0.6
                rgbB.BackgroundTransparency = 0.6

                local inicio = tick()
                local dur = duracao / pulsos
                local conn
                conn = RunService.RenderStepped:Connect(function()
                    local p = (tick() - inicio) / dur
                    if p >= 1 then
                        conn:Disconnect()
                        rgbR.BackgroundTransparency = 1
                        rgbB.BackgroundTransparency = 1
                        return
                    end
                    local forca = (1 + p) * (1 - p * 0.5)
                    rgbR.Position = UDim2.new(0, -deslocamento * forca, 0, 0)
                    rgbB.Position = UDim2.new(0, deslocamento * forca, 0, 0)
                    rgbR.BackgroundTransparency = 0.6 + (0.4 * p)
                    rgbB.BackgroundTransparency = 0.6 + (0.4 * p)
                end)
            end)
            task.wait(0.08)
        end
    end)
end

local function efeitoScanlines(duracao, velocidade)
    velocidade = velocidade or 2
    task.spawn(function()
        for _, linha in ipairs(scanlines) do
            linha.BackgroundTransparency = 0.7
        end

        local inicio = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local p = (tick() - inicio) / duracao
            if p >= 1 then
                conn:Disconnect()
                for _, linha in ipairs(scanlines) do
                    linha.BackgroundTransparency = 1
                end
                return
            end
            local offset = p * velocidade
            for i, linha in ipairs(scanlines) do
                local posBase = (i - 1) / scanlineCount
                linha.Position = UDim2.new(0, 0, (posBase + offset) % 1, 0)
                linha.BackgroundTransparency = 0.7 + (0.3 * p)
            end
        end)
    end)
end

local function efeitoOndas(quantidade, duracao, cor)
    task.spawn(function()
        for _ = 1, quantidade do
            task.spawn(function()
                local ondaFrame = Instance.new("Frame")
                ondaFrame.Size = UDim2.new(0, 0, 0, 0)
                ondaFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
                ondaFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                ondaFrame.BackgroundTransparency = 1
                ondaFrame.BorderSizePixel = 0
                ondaFrame.ZIndex = 1003
                ondaFrame.Parent = ondasContainer

                local ondaCorner = Instance.new("UICorner")
                ondaCorner.CornerRadius = UDim.new(1, 0)
                ondaCorner.Parent = ondaFrame

                local ondaStroke = Instance.new("UIStroke")
                ondaStroke.Color = cor
                ondaStroke.Thickness = 5
                ondaStroke.Transparency = 0.3
                ondaStroke.Parent = ondaFrame

                TweenService:Create(ondaFrame, TweenInfo.new(duracao, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(3, 0, 3, 0)
                }):Play()
                TweenService:Create(ondaStroke, TweenInfo.new(duracao, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Transparency = 1, Thickness = 1
                }):Play()

                task.wait(duracao)
                if ondaFrame and ondaFrame.Parent then ondaFrame:Destroy() end
            end)
            task.wait(0.08)
        end
    end)
end

local function efeitoEco(cor, duracao)
    task.spawn(function()
        local eco = Instance.new("Frame")
        eco.Size = UDim2.new(1, 0, 1, 0)
        eco.BackgroundColor3 = cor
        eco.BackgroundTransparency = 0.75
        eco.BorderSizePixel = 0
        eco.ZIndex = 997
        eco.Parent = ecoContainer

        local tween = TweenService:Create(eco, TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 1
        })
        tween:Play()
        tween.Completed:Wait()
        if eco and eco.Parent then eco:Destroy() end
    end)
end

local function efeitoParticulas(quantidade, cor)
    task.spawn(function()
        for _ = 1, quantidade do
            task.spawn(function()
                local part = Instance.new("Frame")
                part.Size = UDim2.new(0, math.random(3, 8), 0, math.random(3, 8))
                part.Position = UDim2.new(0.5, 0, 0.5, 0)
                part.AnchorPoint = Vector2.new(0.5, 0.5)
                part.BackgroundColor3 = cor
                part.BackgroundTransparency = math.random(0.1, 0.4)
                part.BorderSizePixel = 0
                part.ZIndex = 1005
                part.Parent = particulasContainer

                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(1, 0)
                corner.Parent = part

                local angulo = math.random() * math.pi * 2
                local distancia = math.random(80, 150) / 100
                local tween = TweenService:Create(part, TweenInfo.new(math.random(40, 70) / 100, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0.5 + math.cos(angulo) * distancia, 0, 0.5 + math.sin(angulo) * distancia, 0),
                    BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0)
                })
                tween:Play()
                tween.Completed:Wait()
                if part and part.Parent then part:Destroy() end
            end)
        end
    end)
end

local function efeitoGlitchBlocks(duracao, quantidade, cor)
    task.spawn(function()
        local inicio = tick()
        while tick() - inicio < duracao do
            for _ = 1, quantidade do
                local bloco = Instance.new("Frame")
                bloco.Size = UDim2.new(math.random(3, 15) / 100, 0, math.random(1, 3) / 100, 0)
                bloco.Position = UDim2.new(math.random() * 0.9, 0, math.random() * 0.95, 0)
                bloco.BackgroundColor3 = cor
                bloco.BackgroundTransparency = math.random(0.3, 0.6)
                bloco.BorderSizePixel = 0
                bloco.ZIndex = 1006
                bloco.Parent = glitchContainer
                task.spawn(function()
                    task.wait(math.random(2, 8) / 100)
                    if bloco and bloco.Parent then bloco:Destroy() end
                end)
            end
            task.wait(0.03)
        end
    end)
end

local function efeitoFeixeLuz(cor, duracao)
    task.spawn(function()
        feixeFrame.BackgroundColor3 = cor or Color3.fromRGB(200, 255, 255)
        feixeFrame.Size = UDim2.new(0, 4, 0, 0)
        feixeFrame.BackgroundTransparency = 0.3
        TweenService:Create(feixeFrame, TweenInfo.new(duracao * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 120, 0, 0),
            BackgroundTransparency = 0.5
        }):Play()
        task.wait(duracao * 0.6)
        TweenService:Create(feixeFrame, TweenInfo.new(duracao * 0.4, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 500, 0, 0)
        }):Play()
    end)
end

--=============================================================
-- 🎬 EFEITO COMPLETO
--=============================================================
local function efeitoTeleporte()
    task.spawn(function()
        fadeFrame.BackgroundColor3 = CONFIG.CorFade
        fadeFrame.BackgroundTransparency = CONFIG.TransparenciaFade

        if CONFIG.EfeitoFlash then
            task.wait(0.05)
            flashTela(Color3.fromRGB(255, 255, 255), CONFIG.FlashDuracao)
        end

        TweenService:Create(fadeFrame, TweenInfo.new(CONFIG.DuracaoFade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()

        if CONFIG.EfeitoRGBSplit then efeitoRGBSplit(CONFIG.RGBDuracao, CONFIG.RGBDeslocamento, CONFIG.RGBPulsos) end
        if CONFIG.EfeitoScanlines then efeitoScanlines(CONFIG.ScanlinesDuracao, CONFIG.ScanlinesVelocidade) end
        if CONFIG.EfeitoOndas then efeitoOndas(CONFIG.OndasQuantidade, CONFIG.OndasDuracao, CONFIG.CorEfeito) end
        if CONFIG.EfeitoEco then efeitoEco(CONFIG.CorRGB, CONFIG.EcoDuracao) end
        if CONFIG.EfeitoParticulas then efeitoParticulas(CONFIG.ParticulasQuantidade, CONFIG.CorEfeito) end
        if CONFIG.EfeitoGlitch then efeitoGlitchBlocks(CONFIG.GlitchDuracao, CONFIG.GlitchQuantidade, CONFIG.CorRGB) end
        if CONFIG.EfeitoShake then cameraShake(CONFIG.ShakeIntensidade, CONFIG.ShakeDuracao) end
        if CONFIG.EfeitoBlur then
            criarBlur(CONFIG.BlurTamanho)
            removerBlur(CONFIG.BlurDuracao)
        end
        if CONFIG.EfeitoFeixe then efeitoFeixeLuz(CONFIG.CorRGB, CONFIG.FeixeDuracao) end
    end)
end

--=============================================================
-- 🔍 BUSCAR SUPERFÍCIE MAIS PRÓXIMA
--=============================================================
local function buscarSuperficieMaisProxima(posicao, character)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    params.IgnoreWater = false

    local alturaAcima = CONFIG.AlturaAcima
    local alturaAbaixo = CONFIG.AlturaAbaixo

    do
        local origem = Vector3.new(posicao.X, posicao.Y + alturaAcima, posicao.Z)
        local direcao = Vector3.new(0, -(alturaAcima + alturaAbaixo), 0)
        local resultado = workspace:Raycast(origem, direcao, params)
        if resultado then
            local dot = resultado.Normal:Dot(Vector3.new(0, 1, 0))
            if dot > 0.5 then
                return resultado.Position
            end
        end
    end

    local raio = CONFIG.RaioInicial
    while raio <= CONFIG.RaioMaximo do
        local passos = CONFIG.PassosPorAnel

        for i = 0, passos - 1 do
            local angulo = (i / passos) * math.pi * 2
            local x = posicao.X + math.cos(angulo) * raio
            local z = posicao.Z + math.sin(angulo) * raio

            local origem = Vector3.new(x, posicao.Y + alturaAcima, z)
            local direcao = Vector3.new(0, -(alturaAcima + alturaAbaixo), 0)

            local resultado = workspace:Raycast(origem, direcao, params)

            if resultado then
                local dot = resultado.Normal:Dot(Vector3.new(0, 1, 0))
                if dot > 0.5 then
                    return resultado.Position
                end
            end
        end

        raio = raio + CONFIG.RaioIncremento
    end

    return nil
end

--=============================================================
-- 🎯 TELEPORTAR
--=============================================================
local function teleportarPara(posicao, character, manterRotacao)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local rotacaoAtual
    if manterRotacao then
        rotacaoAtual = hrp.CFrame - hrp.CFrame.Position
    else
        rotacaoAtual = CFrame.new()  -- rotação padrão
    end

    hrp.CFrame = CFrame.new(posicao) * rotacaoAtual
    hrp.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

--=============================================================
-- 🚀 TELEPORTAR PRA LOCAL SEGURO (durante janela pós-respawn)
--=============================================================
local function teleportarParaLocalSeguro(character)
    if tpCooldown then return end
    tpCooldown = true

    log("🛡️ TP pro LOCAL SEGURO (modo pós-respawn)")

    tempoCaindo = 0
    ultimoTempo = os.clock()

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not localSeguroCFrame then
        tpCooldown = false
        return
    end

    efeitoTeleporte()

    -- Mantém rotação atual
    teleportarPara(localSeguroCFrame.Position + Vector3.new(0, CONFIG.OffsetY, 0), character, true)

    tempoCaindo = 0
    ultimoTempo = os.clock()
    ultimaPos = nil

    task.wait(0.3)   -- cooldown curto durante a janela
    tpCooldown = false
end

--=============================================================
-- 🚀 TELEPORTAR PRA SUPERFÍCIE (modo normal)
--=============================================================
local function teleportarParaSeguro(character)
    if tpCooldown then return end
    tpCooldown = true

    log("🚀 TP pra superfície (modo normal)")

    tempoCaindo = 0
    ultimoTempo = os.clock()

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        tpCooldown = false
        return
    end

    efeitoTeleporte()

    local superficie = buscarSuperficieMaisProxima(hrp.Position, character)

    if superficie then
        teleportarPara(superficie + Vector3.new(0, CONFIG.OffsetY, 0), character, true)
    elseif ultimaPosicaoSegura then
        teleportarPara(ultimaPosicaoSegura + Vector3.new(0, CONFIG.OffsetY, 0), character, true)
    else
        local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
        if spawn then
            teleportarPara(spawn.Position + Vector3.new(0, 5, 0), character, true)
        end
    end

    tempoCaindo = 0
    ultimoTempo = os.clock()
    ultimaPos = nil

    task.wait(1.5)
    tpCooldown = false
end

--=============================================================
-- 🛡️ SISTEMA DO LOCAL SEGURO PÓS-RESPAWN
--=============================================================
local function ativarLocalSeguro(posicao)
    localSeguroCFrame = CFrame.new(posicao)
    localSeguroAtivo = true
    localSeguroExpira = os.clock() + CONFIG.LocalSeguroDuracao

    log(string.format("🛡️ LocalSeguro ATIVADO por %.1fs em %s", CONFIG.LocalSeguroDuracao, tostring(posicao)))

    -- ⏱️ Desativa depois do tempo
    task.spawn(function()
        local tempoRestante = CONFIG.LocalSeguroDuracao
        while tempoRestante > 0 do
            task.wait(0.5)
            tempoRestante = tempoRestante - 0.5

            if not localSeguroAtivo then return end
            if os.clock() >= localSeguroExpira then
                localSeguroAtivo = false
                localSeguroCFrame = nil
                log("🛡️ LocalSeguro EXPIRADO — voltando ao modo normal")
                return
            end
        end
    end)
end

local function desativarLocalSeguro()
    if localSeguroAtivo then
        localSeguroAtivo = false
        localSeguroCFrame = nil
        log("🛡️ LocalSeguro desativado manualmente")
    end
end

--=============================================================
-- 🎯 DETECÇÃO DE QUEDA
--=============================================================
RunService.Heartbeat:Connect(function()
    local character = player.Character
    if not character then
        tempoCaindo = 0
        ultimaPos = nil
        return
    end

    local hrp      = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not hrp or not humanoid then
        tempoCaindo = 0
        ultimaPos = nil
        return
    end
    if humanoid.Health <= 0 then
        tempoCaindo = 0
        ultimaPos = nil
        return
    end

    if hrp.Position.Y > CONFIG.AlturaSegura then
        ultimaPosicaoSegura = hrp.Position
    end

    local agora = os.clock()
    local dt = agora - ultimoTempo
    ultimoTempo = agora

    local velocidadeY = hrp.AssemblyLinearVelocity.Y

    -- Fonte 1: velocidade Y
    local caindoPorVelocidade = velocidadeY < CONFIG.VelocidadeMinimaCaindo

    -- Fonte 2: estado Freefall
    local state = humanoid:GetState()
    local caindoPorEstado = (state == Enum.HumanoidStateType.Freefall)
        or (state == Enum.HumanoidStateType.FallingDown)

    -- Fonte 3: descida real
    local caindoPorPosicao = false
    if ultimaPos then
        local deltaY = hrp.Position.Y - ultimaPos.Y
        caindoPorPosicao = (deltaY < -0.5) and (velocidadeY < -5)
    end
    ultimaPos = hrp.Position

    -- 🔥 Se está subindo → reseta
    if velocidadeY > 5 then
        tempoCaindo = 0
        return
    end

    local estaCaindo = caindoPorVelocidade or caindoPorEstado or caindoPorPosicao

    -- 🎯 Define o limite de tempo baseado no modo
    local limiteAtual
    if localSeguroAtivo and os.clock() < localSeguroExpira then
        limiteAtual = CONFIG.TempoCaindoLimite   -- 0.2s durante a janela
    else
        limiteAtual = CONFIG.TempoCaindoNormal   -- 0.4s no normal
    end

    if estaCaindo then
        tempoCaindo = tempoCaindo + dt

        if CONFIG.Debug and tempoCaindo >= 0.1 then
            log(string.format("⏱️ Caindo %.2fs | limite=%.2fs | localSeguro=%s | estado=%s",
                tempoCaindo, limiteAtual, tostring(localSeguroAtivo), tostring(state)))
        end

        if tempoCaindo >= limiteAtual and not tpCooldown then
            if localSeguroAtivo and os.clock() < localSeguroExpira then
                -- 🛡️ Durante a janela → vai pro LocalSeguro
                teleportarParaLocalSeguro(character)
            else
                -- 🌐 Fora da janela → busca superfície normal
                teleportarParaSeguro(character)
            end
        end
    else
        tempoCaindo = 0
    end
end)

--=============================================================
-- 🔄 AO RESPAWNAR → ativa LocalSeguro temporário
--=============================================================
player.CharacterAdded:Connect(function(character)
    log("🔄 CharacterAdded — aguardando HRP...")

    -- Espera o HRP existir
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if not hrp then
        log("❌ HRP não apareceu — abortando LocalSeguro")
        return
    end

    -- Espera o personagem parar (fica em pé)
    task.wait(0.15)

    -- 🛡️ Ativa o LocalSeguro na posição atual de spawn
    ativarLocalSeguro(hrp.Position)

    -- Reseta estados
    tempoCaindo = 0
    ultimoTempo = os.clock()
    ultimaPos = nil
end)

-- Ativa pra character já existente (se o script for executado com player vivo)
if player.Character then
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        ativarLocalSeguro(hrp.Position)
    end
end

print("🛡️ Anti-Void v4 (LocalSeguro pós-respawn 5s) carregado!")