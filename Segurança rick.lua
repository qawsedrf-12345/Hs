--=============================================================
-- 🛡️ ANTI-VOID v9 + ANTI-FLING — Completo
-- ✓ Sistema de morte consecutiva (2x em 30s → TP pro local seguro)
-- ✓ Flag compartilhada entre os dois sistemas
-- ✓ Som Lento Global integrado (não cria sons)
--=============================================================

--=============================================================
-- 🥊 ANTI-FLING (integrado)
--=============================================================
local Services = setmetatable({}, {__index = function(Self, Index)
    local NewService = game:GetService(Index)
    if NewService then
        Self[Index] = NewService
    end
    return NewService
end})

local LocalPlayerAF = Services.Players.LocalPlayer

getgenv().AntiFlingEmAcao = false
getgenv().AntiFlingUltimoAviso = 0

local function PlayerAdded(Player)
    local Detected = false
    local Character
    local PrimaryPart

    local function CharacterAdded(NewCharacter)
        Character = NewCharacter
        repeat
            task.wait()
            PrimaryPart = NewCharacter:FindFirstChild("HumanoidRootPart")
        until PrimaryPart
        Detected = false
    end

    CharacterAdded(Player.Character or Player.CharacterAdded:Wait())
    Player.CharacterAdded:Connect(CharacterAdded)

    Services.RunService.Heartbeat:Connect(function()
        if (Character and Character:IsDescendantOf(workspace)) and (PrimaryPart and PrimaryPart:IsDescendantOf(Character)) then
            if PrimaryPart.AssemblyAngularVelocity.Magnitude > 50 or PrimaryPart.AssemblyLinearVelocity.Magnitude > 100 then
                if Detected == false then
                    pcall(function()
                        game.StarterGui:SetCore("ChatMakeSystemMessage", {
                            Text = "Fling Exploit detected, Player: " .. tostring(Player)
                        })
                    end)
                end
                Detected = true
                for _, v in ipairs(Character:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                        v.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        v.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        v.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0)
                    end
                end
                PrimaryPart.CanCollide = false
                PrimaryPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                PrimaryPart.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0)
            end
        end
    end)
end

for _, v in ipairs(Services.Players:GetPlayers()) do
    if v ~= LocalPlayerAF then
        PlayerAdded(v)
    end
end
Services.Players.PlayerAdded:Connect(PlayerAdded)

local LastPosition = nil

Services.RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = LocalPlayerAF.Character
        if not char then return end
        local PrimaryPart = char.PrimaryPart
        if not PrimaryPart then return end

        local velLin = PrimaryPart.AssemblyLinearVelocity.Magnitude
        local velAng = PrimaryPart.AssemblyAngularVelocity.Magnitude

        if velLin > 250 or velAng > 250 then
            getgenv().AntiFlingEmAcao = true

            PrimaryPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            if LastPosition then
                PrimaryPart.CFrame = LastPosition
            end

            local agora = os.clock()
            if agora - getgenv().AntiFlingUltimoAviso > 1 then
                getgenv().AntiFlingUltimoAviso = agora
                pcall(function()
                    game.StarterGui:SetCore("ChatMakeSystemMessage", {
                        Text = "You were flung. Neutralizing velocity."
                    })
                end)
            end

            task.delay(0.1, function()
                getgenv().AntiFlingEmAcao = false
            end)
        elseif velLin < 50 and velAng < 50 then
            LastPosition = PrimaryPart.CFrame
        end
    end)
end)


--=============================================================
-- 🛡️ ANTI-VOID v9
--=============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting   = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

--=============================================================
-- CONFIG
--=============================================================
local CONFIG = {
    -- 🎯 Janela pós-respawn
    LocalSeguroDuracao = 5,
    TempoCaindoLimite  = 0.2,
    TempoCaindoNormal  = 0.4,
    OffsetY            = 3,

    VelocidadeMinimaCaindo = -25,

    -- 🔍 Busca
    RaioInicial    = 5,
    RaioIncremento = 5,
    RaioMaximo     = 3000,
    PassosPorAnel  = 20,
    AlturaAcima    = 150,
    AlturaAbaixo   = 500,
    DotMinimoPisavel = 0.6,

    ToleranciaY = 3,

    -- ☠️ Sistema de mortes consecutivas
    MortesLimite    = 2,
    JanelaMortes    = 30,

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

    -- 🔊 SOM LENTO GLOBAL
    SomLentoAtivo       = true,
    SomLentoVelocidade  = 0.6,   -- 0.6 = 60% da velocidade
    SomLentoVolumeMult  = 1.0,

    Debug = true,
}

--=============================================================
-- ESTADO
--=============================================================
local tpCooldown = false
local tempoCaindo = 0
local ultimoTempo = os.clock()
local ultimaPos = nil

local localSeguroAtivo = false
local localSeguroExpira = 0

local historicoMortes = {}
local ultimaPosicaoSegura = nil

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

local function buscarSuperficiePisavel(posicao, character)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    params.IgnoreWater = false

    local alturaAcima  = CONFIG.AlturaAcima
    local alturaAbaixo = CONFIG.AlturaAbaixo
    local dotMinimo    = CONFIG.DotMinimoPisavel
    local toleranciaY  = CONFIG.ToleranciaY

    local candidatos = {}

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
                if dot >= dotMinimo then
                    table.insert(candidatos, {
                        posicao = resultado.Position,
                        raio = raio,
                    })
                end
            end
        end

        if #candidatos > 0 and raio >= CONFIG.RaioInicial * 4 then
            break
        end

        raio = raio + CONFIG.RaioIncremento
    end

    if #candidatos == 0 then
        log("❌ Nenhuma superfície pisável encontrada")
        return nil
    end

    local melhor = candidatos[1]
    for _, c in ipairs(candidatos) do
        local dY = c.posicao.Y - melhor.posicao.Y

        if dY > toleranciaY then
            melhor = c
        elseif math.abs(dY) <= toleranciaY then
            if c.raio < melhor.raio then
                melhor = c
            end
        end
    end

    log(string.format("🎯 Escolhido: Y=%.1f | raio=%d | %d candidatos",
        melhor.posicao.Y, melhor.raio, #candidatos))

    return melhor.posicao
end

local function teleportarPara(posicao, character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local rotacaoAtual = hrp.CFrame - hrp.CFrame.Position

    hrp.CFrame = CFrame.new(posicao) * rotacaoAtual
    hrp.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

local function teleportarParaSuperficie(character, motivo)
    if tpCooldown then return end
    tpCooldown = true

    log("🚀 TP disparado (" .. motivo .. ")")

    tempoCaindo = 0
    ultimoTempo = os.clock()

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        tpCooldown = false
        return
    end

    efeitoTeleporte()

    local superficie = buscarSuperficiePisavel(hrp.Position, character)

    if superficie then
        teleportarPara(superficie + Vector3.new(0, CONFIG.OffsetY, 0), character)
    elseif ultimaPosicaoSegura then
        log("🚀 Fallback: última posição segura")
        teleportarPara(ultimaPosicaoSegura + Vector3.new(0, CONFIG.OffsetY, 0), character)
    else
        local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
        if spawn then
            log("🚀 Fallback: SpawnLocation")
            teleportarPara(spawn.Position + Vector3.new(0, 5, 0), character)
        end
    end

    tempoCaindo = 0
    ultimoTempo = os.clock()
    ultimaPos = nil

    local cooldown = localSeguroAtivo and 0.3 or 1.5
    task.wait(cooldown)
    tpCooldown = false
end

local function registrarMorte()
    local agora = os.clock()
    table.insert(historicoMortes, agora)

    for i = #historicoMortes, 1, -1 do
        if agora - historicoMortes[i] > CONFIG.JanelaMortes then
            table.remove(historicoMortes, i)
        end
    end

    local total = #historicoMortes
    log(string.format("💀 Morte registrada! Total na janela de %ds: %d/%d",
        CONFIG.JanelaMortes, total, CONFIG.MortesLimite))

    if total >= CONFIG.MortesLimite then
        log("☠️ LOOP DE MORTE DETECTADO! TP pro local seguro mais próximo...")

        historicoMortes = {}

        task.spawn(function()
            task.wait(0.5)
            local char = player.Character
            if not char then return end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            efeitoTeleporte()

            local superficie = buscarSuperficiePisavel(hrp.Position, char)

            if superficie then
                log("☠️ TP pra superfície segura:", superficie)
                teleportarPara(superficie + Vector3.new(0, CONFIG.OffsetY, 0), char)
            elseif ultimaPosicaoSegura then
                log("☠️ TP pra última posição segura")
                teleportarPara(ultimaPosicaoSegura + Vector3.new(0, CONFIG.OffsetY, 0), char)
            else
                local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
                if spawn then
                    log("☠️ Fallback: SpawnLocation")
                    teleportarPara(spawn.Position + Vector3.new(0, 5, 0), char)
                end
            end

            localSeguroAtivo = true
            localSeguroExpira = os.clock() + CONFIG.LocalSeguroDuracao
        end)
    end
end

local function ativarJanelaPosRespawn()
    localSeguroAtivo = true
    localSeguroExpira = os.clock() + CONFIG.LocalSeguroDuracao

    log(string.format("🛡️ Janela pós-respawn ATIVADA por %.1fs", CONFIG.LocalSeguroDuracao))

    task.spawn(function()
        while os.clock() < localSeguroExpira do
            task.wait(0.5)
            if not localSeguroAtivo then return end
        end
        localSeguroAtivo = false
        log("🛡️ Janela pós-respawn EXPIRADA")
    end)
end

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

    if getgenv().AntiFlingEmAcao then
        tempoCaindo = 0
        ultimaPos = nil
        return
    end

    if hrp.Position.Y > 50 then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { character }
        local origem = hrp.Position + Vector3.new(0, 2, 0)
        local direcao = Vector3.new(0, -15, 0)
        if workspace:Raycast(origem, direcao, params) then
            ultimaPosicaoSegura = hrp.Position
        end
    end

    local agora = os.clock()
    local dt = agora - ultimoTempo
    ultimoTempo = agora

    local velocidadeY = hrp.AssemblyLinearVelocity.Y

    local caindoPorVelocidade = velocidadeY < CONFIG.VelocidadeMinimaCaindo
    local state = humanoid:GetState()
    local caindoPorEstado = (state == Enum.HumanoidStateType.Freefall)
        or (state == Enum.HumanoidStateType.FallingDown)

    local caindoPorPosicao = false
    if ultimaPos then
        local deltaY = hrp.Position.Y - ultimaPos.Y
        caindoPorPosicao = (deltaY < -0.5) and (velocidadeY < -5)
    end
    ultimaPos = hrp.Position

    if velocidadeY > 5 then
        tempoCaindo = 0
        return
    end

    local estaCaindo = caindoPorVelocidade or caindoPorEstado or caindoPorPosicao

    local limiteAtual
    if localSeguroAtivo and os.clock() < localSeguroExpira then
        limiteAtual = CONFIG.TempoCaindoLimite
    else
        limiteAtual = CONFIG.TempoCaindoNormal
    end

    if estaCaindo then
        tempoCaindo = tempoCaindo + dt

        if CONFIG.Debug and tempoCaindo >= 0.1 then
            log(string.format("⏱️ %.2fs | limite %.2fs | velY=%.0f",
                tempoCaindo, limiteAtual, velocidadeY))
        end

        if tempoCaindo >= limiteAtual and not tpCooldown then
            local motivo = localSeguroAtivo and "janela pós-respawn" or "modo normal"
            teleportarParaSuperficie(character, motivo)
        end
    else
        tempoCaindo = 0
    end
end)

player.CharacterAdded:Connect(function(character)
    log("🔄 CharacterAdded")

    registrarMorte()

    task.wait(0.2)
    ativarJanelaPosRespawn()
    tempoCaindo = 0
    ultimoTempo = os.clock()
    ultimaPos = nil
end)

if player.Character then
    task.spawn(function()
        task.wait(0.2)
        ativarJanelaPosRespawn()
    end)
end

--=============================================================
-- 🔊 SOM LENTO GLOBAL (integrado)
-- Deixa TODOS os sons do jogo (que já existem e que forem criados)
-- em câmera lenta. NÃO cria sons próprios.
--=============================================================
local sonsModificados = {}

local function aplicarSomLento(som)
    if not som or not som:IsA("Sound") then return end
    if not CONFIG.SomLentoAtivo then return end
    if sonsModificados[som] then return end

    pcall(function()
        -- Salva valor original (caso precise restaurar)
        if not som:GetAttribute("_PitchOriginal") then
            som:SetAttribute("_PitchOriginal", som.PlaybackSpeed)
        end
        if not som:GetAttribute("_VolumeOriginal") then
            som:SetAttribute("_VolumeOriginal", som.Volume)
        end

        -- Aplica velocidade lenta
        som.PlaybackSpeed = CONFIG.SomLentoVelocidade

        -- Aplica volume (opcional)
        if CONFIG.SomLentoVolumeMult ~= 1 then
            local volOrig = som:GetAttribute("_VolumeOriginal") or som.Volume
            som.Volume = volOrig * CONFIG.SomLentoVolumeMult
        end

        sonsModificados[som] = true
    end)
end

local function aplicarSomLentoEmTudo()
    if not CONFIG.SomLentoAtivo then return end

    -- 1) SoundService
    for _, som in ipairs(SoundService:GetDescendants()) do
        if som:IsA("Sound") then aplicarSomLento(som) end
    end

    -- 2) Workspace
    for _, som in ipairs(workspace:GetDescendants()) do
        if som:IsA("Sound") then aplicarSomLento(som) end
    end

    -- 3) Players (sons dos outros jogadores)
    for _, plr in ipairs(Players:GetPlayers()) do
        for _, som in ipairs(plr:GetDescendants()) do
            if som:IsA("Sound") then aplicarSomLento(som) end
        end
    end
end

local function monitorarNovosSons()
    SoundService.DescendantAdded:Connect(function(obj)
        if obj:IsA("Sound") then
            task.wait(0.05)
            aplicarSomLento(obj)
        end
    end)

    workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Sound") then
            task.wait(0.05)
            aplicarSomLento(obj)
        end
    end)

    for _, plr in ipairs(Players:GetPlayers()) do
        plr.DescendantAdded:Connect(function(obj)
            if obj:IsA("Sound") then
                task.wait(0.05)
                aplicarSomLento(obj)
            end
        end)
    end

    Players.PlayerAdded:Connect(function(plr)
        plr.DescendantAdded:Connect(function(obj)
            if obj:IsA("Sound") then
                task.wait(0.05)
                aplicarSomLento(obj)
            end
        end)
    end)
end

local function loopReaplicarSomLento()
    task.spawn(function()
        while true do
            task.wait(3)
            aplicarSomLentoEmTudo()
        end
    end)
end

-- Init do som lento
aplicarSomLentoEmTudo()
monitorarNovosSons()
loopReaplicarSomLento()

-- API pública do som lento
getgenv().SomLento = {
    restaurar = function()
        for som in pairs(sonsModificados) do
            pcall(function()
                if som and som.Parent then
                    local pitch = som:GetAttribute("_PitchOriginal")
                    local vol   = som:GetAttribute("_VolumeOriginal")
                    if pitch then som.PlaybackSpeed = pitch end
                    if vol then som.Volume = vol end
                end
            end)
        end
        sonsModificados = {}
        print("🔊 Sons restaurados")
    end,
    mudarVelocidade = function(novaVelocidade)
        CONFIG.SomLentoVelocidade = novaVelocidade
        for som in pairs(sonsModificados) do
            pcall(function()
                if som and som.Parent then
                    som.PlaybackSpeed = novaVelocidade
                end
            end)
        end
        print("🔊 Velocidade alterada para", novaVelocidade)
    end,
}

print("🛡️ Anti-Void v9 + Anti-Fling + 🔊 Som Lento — carregado!")