--=============================================================
-- SANDEVISTAN v4.10 — EDGERUNNERS EDITION
-- Velocidade: 28 | Duração: 3.5s | Tecla: F | Char: toggle
-- Áudio 1 (swoosh): 97013920026153 | speed 1 | vol 0.15 | end 0.7
-- Áudio 2 (main):   130840290979991 | speed 0.5 | vol 1 | start 1.9
-- Clones: opacos, cor fixa por clone (gradiente contínuo, sem tween)
-- FOV kick: 70 -> 100 na ativação
-- Menu: SANDEVISTAN | CHAR PERM | SHIFTLOCK
--=============================================================

--=============================================================
-- ⚡ SERVICES
--=============================================================
local Players           = game:GetService("Players")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local SoundService      = game:GetService("SoundService")
local ContentProvider   = game:GetService("ContentProvider")
local WS                = game:GetService("Workspace")

local player = Players.LocalPlayer

--=============================================================
-- ⚡ ENV
--=============================================================
local function safeGetGenv()
    local ok, env = pcall(function()
        if getgenv then return getgenv() end
        return nil
    end)
    if ok and type(env) == "table" then return env end
    return nil
end

local GENV = safeGetGenv()
if GENV and GENV.SandevistanCleanup then
    pcall(GENV.SandevistanCleanup)
end

--=============================================================
-- ⚡ GUI PARENT
--=============================================================
local GUI_PARENT
do
    local ok1, hui = pcall(function()
        if gethui then return gethui() end
    end)
    if ok1 and hui then
        local okType = pcall(function()
            local t = typeof and typeof(hui) or type(hui)
            return (t == "Instance" or t == "userdata")
        end)
        if okType then GUI_PARENT = hui end
    end

    if not GUI_PARENT then
        local ok2, cg = pcall(function() return CoreGui end)
        if ok2 and cg then
            local ok3 = pcall(function()
                local test = Instance.new("Folder")
                test.Name = "SD_Test_" .. tostring(os.clock()):gsub("%.", "")
                test.Parent = cg
                task.wait()
                test:Destroy()
            end)
            if ok3 then GUI_PARENT = cg end
        end
    end

    if not GUI_PARENT then
        local ok4, pg = pcall(function() return player:WaitForChild("PlayerGui", 15) end)
        if ok4 and pg then GUI_PARENT = pg end
    end

    if not GUI_PARENT then
        warn("[Sandevistan] GUI_PARENT não encontrado — abortando.")
        return
    end
end

--=============================================================
-- ⚡ ÓRFÃOS
--=============================================================
do
    local function killChildren(parent, names)
        if not parent then return end
        for _, obj in ipairs(parent:GetChildren()) do
            if table.find(names, obj.Name) then
                pcall(function() obj:Destroy() end)
            end
        end
    end

    killChildren(GUI_PARENT,  { "SandevistanGUI", "SandevistanFlashGui", "SandevistanBlackFlash", "SandevistanToast", "FakeShiftlockUI" })
    killChildren(WS,          { "SandevistanSound", "invischair" })
    killChildren(SoundService,{ "SandevistanSound", "SandevistanSwoosh" })
    killChildren(Lighting,    { "SandevistanEffect", "SandevistanBloom", "SandevistanBlur" })

    for _, obj in ipairs(WS:GetChildren()) do
        if obj.Name == "SandevistanClone" then
            pcall(function() obj:Destroy() end)
        end
    end
end

--=============================================================
-- ⚡ SETTINGS
--=============================================================
-- Tecla para ligar/desligar o Sandevistan
local TOGGLE_KEY            = Enum.KeyCode.F

-- Velocidade do jogador (studs/s)
local NORMAL_SPEED          = 16
local BOOSTED_SPEED         = 22

-- Duração do efeito (segundos)
local SANDEVISTAN_DURATION  = 7.0

-- Configurações dos clones
local CLONE_INTERVAL        = 0.05
local MAX_CLONES            = 240
local CLONE_TRANSPARENCY    = 0
local CLONE_HIGHLIGHT_FILL  = 0.0
local CLONE_HIGHLIGHT_LINE  = 0.2
local CLONE_MATERIAL        = Enum.Material.Neon

-- Cooldown anti-spam
local TOGGLE_COOLDOWN       = 0.3

-- Morph (CHAR PERM)
local MORPH_USERNAME        = "ZiemekaTheSequel"

-- Velocidade mínima para o clone spawnar
local MOVE_THRESHOLD        = 2

-- Áudios
local AUDIO_SWOOSH_ID       = "rbxassetid://97013920026153"
local AUDIO_SWOOSH_SPEED    = 1
local AUDIO_SWOOSH_VOLUME   = 0.15
local AUDIO_SWOOSH_END      = 0.7

local AUDIO_MAIN_ID         = "rbxassetid://130840290979991"
local AUDIO_MAIN_SPEED      = 0.2
local AUDIO_MAIN_VOLUME     = 2
local AUDIO_MAIN_START      = 1.9

-- FOV kick
local FOV_BOOST             = 100
local FOV_NORMAL            = 70

-- Cor do mundo durante o Sandevistan
local COR_MUNDO_ATIVO       = Color3.fromRGB(80, 240, 120)
local MUNDO_CONTRAST        = 0.55
local MUNDO_SATURATION      = 0.4
local MUNDO_BRIGHTNESS      = 0.03

-- Bloom
local BLOOM_INTENSITY       = 1.2
local BLOOM_THRESHOLD       = 1.2
local BLOOM_SIZE            = 24

--=============================================================
-- ⚡ STATE
--=============================================================
local isActive              = false
local isDeactivating        = false
local isMorphing            = false
local glitchPulseRunning    = false
local normalSpeedCaptured   = false
local soundReady            = false
local soundLoaded           = false
local morphEnabled          = false
local shiftlockEnabled      = false
local shiftlockConnection   = nil
local lagSwitchWatchdog     = nil
local flashGui              = nil
local toastGui              = nil
local toastTask             = nil
local durationTask          = nil
local currentShakeConnection= nil
local deactivateToken       = 0
local character, humanoid
local cloneSpawning         = false
local cloneTask             = nil
local activeSeat            = nil
local activeWeld            = nil
local activeClones          = {}
local cloneColorIndex       = 0
local connections           = {}
local morphUserId           = nil
local running               = true
local lastToggleTime        = -math.huge
local originalArchivable    = nil
local archivableCaptured    = false
local archivableChar        = nil
local pendingActivation     = false
local originalFov           = nil

--=============================================================
-- 🎨 PALETA
--=============================================================
local COR_CIANO    = Color3.fromRGB(0, 240, 255)
local COR_VERDE    = Color3.fromRGB(75, 255, 33)
local COR_LAVANDA  = Color3.fromRGB(244, 213, 253)
local COR_AMARELO  = Color3.fromRGB(255, 215, 0)
local COR_VERMELHO = Color3.fromRGB(255, 80, 80)

--=============================================================
-- 🎨 POST-PROCESSING
--=============================================================
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "SandevistanEffect"
colorCorrection.Parent = Lighting

local bloomEffect = Instance.new("BloomEffect")
bloomEffect.Name = "SandevistanBloom"
bloomEffect.Intensity = 0
bloomEffect.Size = BLOOM_SIZE
bloomEffect.Threshold = 1.5
bloomEffect.Parent = Lighting

--=============================================================
-- 🔊 SONS
--=============================================================
local swoosh = Instance.new("Sound")
swoosh.Name = "SandevistanSwoosh"
swoosh.SoundId = AUDIO_SWOOSH_ID
swoosh.Volume = AUDIO_SWOOSH_VOLUME
swoosh.PlaybackSpeed = AUDIO_SWOOSH_SPEED
swoosh.Looped = false
swoosh.Parent = SoundService

local sound = Instance.new("Sound")
sound.Name = "SandevistanSound"
sound.SoundId = AUDIO_MAIN_ID
sound.Volume = AUDIO_MAIN_VOLUME
sound.PlaybackSpeed = AUDIO_MAIN_SPEED
sound.Looped = false
sound.Parent = SoundService

task.spawn(function()
    local ok = pcall(function()
        ContentProvider:PreloadAsync({ swoosh, sound })
    end)
    soundReady = ok

    if not sound.IsLoaded then
        local loaded = false
        local conn
        conn = sound.Loaded:Connect(function() loaded = true end)
        local start = os.clock()
        while not loaded and (os.clock() - start) < 2 do
            task.wait(0.05)
            if sound.IsLoaded then loaded = true end
        end
        if conn then pcall(function() conn:Disconnect() end) end
    end
    soundLoaded = sound.IsLoaded

    if not ok or not soundLoaded then
        warn("[Sandevistan] Som não carregado — primeira ativação pode ser silenciosa.")
    end
end)

--=============================================================
-- 🎨 PALETA EDGERUNNERS
--=============================================================
local PALETA_EDGERUNNERS = {
    Color3.fromRGB(160, 230, 240),
    Color3.fromRGB(100, 180, 235),
    Color3.fromRGB(110, 140, 220),
    Color3.fromRGB(160, 120, 210),
    Color3.fromRGB(200, 110, 170),
    Color3.fromRGB(220, 100, 110),
    Color3.fromRGB(230, 160, 90),
    Color3.fromRGB(230, 210, 120),
}

local function getGradientColor(t)
    t = math.clamp(t, 0, 1)
    local n = #PALETA_EDGERUNNERS
    if n == 1 then return PALETA_EDGERUNNERS[1] end

    local scaled = t * (n - 1)
    local i = math.floor(scaled) + 1
    local frac = scaled - (i - 1)

    if i >= n then return PALETA_EDGERUNNERS[n] end
    return PALETA_EDGERUNNERS[i]:Lerp(PALETA_EDGERUNNERS[i + 1], frac)
end

--=============================================================
-- ✨ HELPERS
--=============================================================
local function waitTween(tween, timeout)
    if not tween then return end
    timeout = timeout or 2

    local state = tween.PlaybackState
    if state == Enum.PlaybackState.Completed or state == Enum.PlaybackState.Cancelled then
        return
    end

    local done = false
    local conn
    conn = tween.Completed:Connect(function()
        done = true
    end)

    local start = os.clock()
    while not done and (os.clock() - start) < timeout do
        task.wait(0.03)
    end

    if conn then pcall(function() conn:Disconnect() end) end
end

local function isCharacterMoving()
    if not character or not character.Parent then return false end

    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then
        local md = hum.MoveDirection
        if md.Magnitude > 0.01 then
            return true
        end
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local vel = hrp.AssemblyLinearVelocity
    local speed3D = math.sqrt(vel.X * vel.X + vel.Y * vel.Y + vel.Z * vel.Z)
    return speed3D >= MOVE_THRESHOLD
end

-- FOV Kick
local function applyFovKick(boost)
    local cam = WS.CurrentCamera
    if not cam then return end
    if originalFov == nil then originalFov = cam.FieldOfView end
    local target = boost and FOV_BOOST or (originalFov or FOV_NORMAL)
    pcall(function()
        TweenService:Create(cam, TweenInfo.new(boost and 0.35 or 0.6, Enum.EasingStyle.Quad), {
            FieldOfView = target
        }):Play()
    end)
end

--=============================================================
-- 🔊 SEQUÊNCIA DE ÁUDIOS
--=============================================================
local function playIntroAudioSequence()
    if swoosh and swoosh.Parent then
        pcall(function()
            swoosh.TimePosition = 0
            swoosh:Play()
        end)

        local startT = os.clock()
        while (os.clock() - startT) < AUDIO_SWOOSH_END do
            if not running then break end
            task.wait(0.02)
        end

        pcall(function() swoosh:Stop() end)
    else
        task.wait(AUDIO_SWOOSH_END)
    end

    if sound and sound.Parent then
        pcall(function()
            sound.TimePosition = AUDIO_MAIN_START
            sound:Play()
        end)
    end

    return true
end

--=============================================================
-- ✨ MORPH
--=============================================================
local function morphIntoUser(targetUserId)
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not char.Parent or not hum or not hum.Parent or not targetUserId then
        return false
    end

    local modelSuccess, generatedModel = pcall(function()
        local desc = Players:GetHumanoidDescriptionFromUserId(targetUserId)
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
    end)
    if not (modelSuccess and generatedModel) then return false end

    local okFinal = pcall(function()
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("ShirtGraphic")
               or item:IsA("BodyColors") or item:IsA("CharacterMesh") then
                pcall(function() item:Destroy() end)
            end
        end

        for _, targetItem in ipairs(generatedModel:GetChildren()) do
            if targetItem:IsA("BasePart") then
                local existingPart = char:FindFirstChild(targetItem.Name)
                if existingPart and existingPart:IsA("BasePart")
                   and existingPart.Name ~= "HumanoidRootPart" then
                    pcall(function() existingPart.Color = targetItem.Color end)
                end
            end
        end

        local targetHead  = generatedModel:FindFirstChild("Head")
        local currentHead = char:FindFirstChild("Head")
        if targetHead and currentHead then
            local oldFace = currentHead:FindFirstChildOfClass("Decal")
            if oldFace then pcall(function() oldFace:Destroy() end) end

            local newFace = targetHead:FindFirstChildOfClass("Decal")
            if newFace then
                pcall(function() newFace:Clone().Parent = currentHead end)
            else
                local defaultFace = Instance.new("Decal")
                defaultFace.Name = "face"
                defaultFace.Texture = "rbxasset://textures/face.png"
                defaultFace.Parent = currentHead
            end

            local oldMesh = currentHead:FindFirstChildOfClass("SpecialMesh")
            if oldMesh then pcall(function() oldMesh:Destroy() end) end

            local newMesh = targetHead:FindFirstChildOfClass("SpecialMesh")
            if newMesh then
                pcall(function() newMesh:Clone().Parent = currentHead end)
            end
        end

        for _, item in ipairs(generatedModel:GetChildren()) do
            if item:IsA("Clothing") or item:IsA("ShirtGraphic")
               or item:IsA("BodyColors") or item:IsA("CharacterMesh") then
                pcall(function() item:Clone().Parent = char end)
            elseif item:IsA("Accessory") then
                local clonedAccessory = item:Clone()
                local handle = clonedAccessory:FindFirstChild("Handle")
                if handle then
                    local attachment = handle:FindFirstChildOfClass("Attachment")
                    if attachment then
                        local targetAttachment = char:FindFirstChild(attachment.Name, true)
                        if targetAttachment and targetAttachment.Parent then
                            pcall(function()
                                handle.CFrame = targetAttachment.WorldCFrame
                                local weld = Instance.new("Weld")
                                weld.Name = "AccessoryWeld"
                                weld.Part0 = handle
                                weld.Part1 = targetAttachment.Parent
                                weld.C0 = attachment.CFrame
                                weld.C1 = targetAttachment.CFrame
                                weld.Parent = handle
                            end)
                        end
                    end
                end
                pcall(function() clonedAccessory.Parent = char end)
            end
        end
    end)

    pcall(function() generatedModel:Destroy() end)
    return okFinal
end

local function tryMorph()
    if isMorphing then return false end
    isMorphing = true

    local ok, result = pcall(function()
        if not morphUserId then
            local okId, id = pcall(function()
                return Players:GetUserIdFromNameAsync(MORPH_USERNAME)
            end)
            if okId and id then
                morphUserId = id
            else
                return false
            end
        end
        return morphIntoUser(morphUserId)
    end)

    isMorphing = false
    if not ok then
        warn("[Sandevistan] tryMorph erro: " .. tostring(result))
        return false
    end
    return result and true or false
end

local function revertMorph()
    if isMorphing then
        local start = os.clock()
        while isMorphing and (os.clock() - start) < 1 do
            task.wait(0.05)
        end
    end

    isMorphing = true

    local ok, result = pcall(function()
        local myName = player.Name
        if not myName or myName == "" then
            warn("[Sandevistan] Não foi possível obter o nick do jogador.")
            return false
        end

        local okId, myId = pcall(function()
            return Players:GetUserIdFromNameAsync(myName)
        end)
        if not okId or not myId then
            warn("[Sandevistan] Falha ao resolver ID do nick: " .. myName)
            return false
        end

        return morphIntoUser(myId)
    end)

    isMorphing = false
    if not ok then
        warn("[Sandevistan] revertMorph erro: " .. tostring(result))
        return false
    end
    return result and true or false
end

--=============================================================
-- 🔔 TOAST
--=============================================================
local function showToast(message, color)
    if toastGui and toastGui.Parent then
        pcall(function() toastGui:Destroy() end)
    end
    if toastTask then
        pcall(function() task.cancel(toastTask) end)
        toastTask = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "SandevistanToast"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000002
    local okParent = pcall(function() gui.Parent = GUI_PARENT end)
    if not okParent or not gui.Parent then
        pcall(function() gui:Destroy() end)
        return
    end
    toastGui = gui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 32)
    frame.Position = UDim2.new(0, 20, 0, -40)
    frame.BackgroundColor3 = color or COR_CIANO
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COR_CIANO
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = frame

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COR_CIANO),
        ColorSequenceKeypoint.new(0.5, COR_VERDE),
        ColorSequenceKeypoint.new(1, COR_CIANO)
    })
    grad.Rotation = 90
    grad.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = message
    lbl.TextColor3 = COR_LAVANDA
    lbl.Font = Enum.Font.Code
    lbl.TextScaled = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local sizeConstraint = Instance.new("UITextSizeConstraint")
    sizeConstraint.MaxTextSize = 12
    sizeConstraint.MinTextSize = 8
    sizeConstraint.Parent = lbl

    local tweenIn = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 20, 0, 20)
    })
    tweenIn:Play()
    waitTween(tweenIn, 0.5)

    task.wait(2)

    local tweenOut = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0, 20, 0, -40)
    })
    tweenOut:Play()
    waitTween(tweenOut, 0.5)

    if toastGui and toastGui.Parent then
        pcall(function() toastGui:Destroy() end)
    end
    toastGui = nil
end

--=============================================================
-- 🖥️ UI COMPACTA
--=============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SandevistanGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
screenGui.Parent = GUI_PARENT

local glitchOverlay = Instance.new("Frame")
glitchOverlay.Name = "EdgerunnerOverlay"
glitchOverlay.Size = UDim2.new(1, 0, 1, 0)
glitchOverlay.Position = UDim2.new(0, 0, 0, 0)
glitchOverlay.BackgroundColor3 = COR_AMARELO
glitchOverlay.BackgroundTransparency = 1
glitchOverlay.BorderSizePixel = 0
glitchOverlay.ZIndex = 998
glitchOverlay.Visible = false
glitchOverlay.Parent = screenGui

local overlayStroke = Instance.new("UIStroke")
overlayStroke.Color = COR_AMARELO
overlayStroke.Thickness = 4
overlayStroke.Transparency = 1
overlayStroke.Parent = glitchOverlay

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 120, 0, 120)
mainFrame.Position = UDim2.new(0, 20, 0.35, -60)
mainFrame.BackgroundColor3 = COR_CIANO
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 4)
mainCorner.Parent = mainFrame

local mainGrad = Instance.new("UIGradient")
mainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COR_CIANO),
    ColorSequenceKeypoint.new(0.5, COR_VERDE),
    ColorSequenceKeypoint.new(1, COR_CIANO)
})
mainGrad.Rotation = 135
mainGrad.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COR_CIANO
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.1
mainStroke.Parent = mainFrame

--=============================================================
-- 🎯 DRAG
--=============================================================
do
    local dragArea = Instance.new("TextButton")
    dragArea.Name = "DragArea"
    dragArea.Size = UDim2.new(1, 0, 1, 0)
    dragArea.Position = UDim2.new(0, 0, 0, 0)
    dragArea.BackgroundTransparency = 1
    dragArea.Text = ""
    dragArea.AutoButtonColor = false
    dragArea.ZIndex = 1
    dragArea.Parent = mainFrame

    local dragging = false
    local dragStart, startPos

    local beganConn = dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)

    local changedConn = dragArea.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    local endedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    table.insert(connections, beganConn)
    table.insert(connections, changedConn)
    table.insert(connections, endedConn)
end

--=============================================================
-- 🎨 CANTOS
--=============================================================
local function fazerCanto(posX, posY, offX, offY)
    local cH_offY = offY
    if posY.Scale == 1 then cH_offY = offY + 8 end

    local cH = Instance.new("Frame")
    cH.Size = UDim2.new(0, 10, 0, 2)
    cH.Position = UDim2.new(posX.Scale, posX.Offset + offX, posY.Scale, posY.Offset + cH_offY)
    cH.BackgroundColor3 = COR_CIANO
    cH.BorderSizePixel = 0
    cH.ZIndex = 5
    cH.Parent = mainFrame
    local cHc = Instance.new("UICorner")
    cHc.CornerRadius = UDim.new(1, 0)
    cHc.Parent = cH

    local cV_offX = offX
    if posX.Scale == 1 then cV_offX = offX + 8 end

    local cV = Instance.new("Frame")
    cV.Size = UDim2.new(0, 2, 0, 10)
    cV.Position = UDim2.new(posX.Scale, posX.Offset + cV_offX, posY.Scale, posY.Offset + offY)
    cV.BackgroundColor3 = COR_CIANO
    cV.BorderSizePixel = 0
    cV.ZIndex = 5
    cV.Parent = mainFrame
    local cVc = Instance.new("UICorner")
    cVc.CornerRadius = UDim.new(1, 0)
    cVc.Parent = cV
end

fazerCanto(UDim.new(0, 0), UDim.new(0, 0), 0, 0)
fazerCanto(UDim.new(1, 0), UDim.new(0, 0), -10, 0)
fazerCanto(UDim.new(0, 0), UDim.new(1, 0), 0, -10)
fazerCanto(UDim.new(1, 0), UDim.new(1, 0), -10, -10)

--=============================================================
-- ✨ HELPER: linha de botão
--=============================================================
local function makeLine(yPos, accentColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 24)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = COR_CIANO
    btn.BackgroundTransparency = 0.2
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    btn.Parent = mainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COR_CIANO),
        ColorSequenceKeypoint.new(0.5, COR_VERDE),
        ColorSequenceKeypoint.new(1, COR_CIANO)
    })
    grad.Rotation = 90
    grad.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = COR_CIANO
    stroke.Thickness = 1
    stroke.Transparency = 0.2
    stroke.Parent = btn

    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Size = UDim2.new(0, 3, 1, -6)
    accent.Position = UDim2.new(0, 0, 0, 3)
    accent.BackgroundColor3 = accentColor or COR_CIANO
    accent.BorderSizePixel = 0
    accent.ZIndex = 5
    accent.Parent = btn

    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(1, 0)
    accentCorner.Parent = accent

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = ""
    lbl.TextColor3 = COR_CIANO
    lbl.Font = Enum.Font.Code
    lbl.TextScaled = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 5
    lbl.Parent = btn

    local sizeConstraint = Instance.new("UITextSizeConstraint")
    sizeConstraint.MaxTextSize = 12
    sizeConstraint.MinTextSize = 8
    sizeConstraint.Parent = lbl

    local hoverScale = Instance.new("UIScale")
    hoverScale.Scale = 1
    hoverScale.Parent = btn

    return { btn = btn, lbl = lbl, stroke = stroke, accent = accent, hoverScale = hoverScale }
end

--=============================================================
-- ✨ LINHA 1: SANDEVISTAN
--=============================================================
local sdLine = makeLine(6, COR_CIANO)
local toggleBtn   = sdLine.btn
local toggleLbl   = sdLine.lbl
local toggleStroke= sdLine.stroke
local toggleAccent= sdLine.accent
local hoverScale  = sdLine.hoverScale

local liveDot = Instance.new("Frame")
liveDot.Size = UDim2.new(0, 5, 0, 5)
liveDot.Position = UDim2.new(1, -8, 0.5, 0)
liveDot.AnchorPoint = Vector2.new(1, 0.5)
liveDot.BackgroundColor3 = COR_CIANO
liveDot.BorderSizePixel = 0
liveDot.ZIndex = 6
liveDot.Parent = toggleBtn

local liveDotCorner = Instance.new("UICorner")
liveDotCorner.CornerRadius = UDim.new(1, 0)
liveDotCorner.Parent = liveDot

local liveDotStroke = Instance.new("UIStroke")
liveDotStroke.Color = COR_VERDE
liveDotStroke.Thickness = 1
liveDotStroke.Transparency = 0.3
liveDotStroke.Parent = liveDot

--=============================================================
-- ✨ LINHA 2: CHAR PERM
--=============================================================
local chLine = makeLine(34, COR_LAVANDA)
local charBtn    = chLine.btn
local charLbl    = chLine.lbl
local charStroke = chLine.stroke
local charAccent = chLine.accent
local charHoverScale = chLine.hoverScale

local charDot = Instance.new("Frame")
charDot.Size = UDim2.new(0, 5, 0, 5)
charDot.Position = UDim2.new(1, -8, 0.5, 0)
charDot.AnchorPoint = Vector2.new(1, 0.5)
charDot.BackgroundColor3 = COR_LAVANDA
charDot.BorderSizePixel = 0
charDot.ZIndex = 6
charDot.Parent = charBtn

local charDotCorner = Instance.new("UICorner")
charDotCorner.CornerRadius = UDim.new(1, 0)
charDotCorner.Parent = charDot

local charDotStroke = Instance.new("UIStroke")
charDotStroke.Color = COR_VERDE
charDotStroke.Thickness = 1
charDotStroke.Transparency = 0.3
charDotStroke.Parent = charDot

--=============================================================
-- ✨ LINHA 3: SHIFTLOCK
--=============================================================
local slLine = makeLine(62, COR_CIANO)
local shiftBtn    = slLine.btn
local shiftLbl    = slLine.lbl
local shiftStroke = slLine.stroke
local shiftAccent = slLine.accent
local shiftHoverScale = slLine.hoverScale

local shiftDot = Instance.new("Frame")
shiftDot.Size = UDim2.new(0, 5, 0, 5)
shiftDot.Position = UDim2.new(1, -8, 0.5, 0)
shiftDot.AnchorPoint = Vector2.new(1, 0.5)
shiftDot.BackgroundColor3 = COR_CIANO
shiftDot.BorderSizePixel = 0
shiftDot.ZIndex = 6
shiftDot.Parent = shiftBtn

local shiftDotCorner = Instance.new("UICorner")
shiftDotCorner.CornerRadius = UDim.new(1, 0)
shiftDotCorner.Parent = shiftDot

local shiftDotStroke = Instance.new("UIStroke")
shiftDotStroke.Color = COR_VERDE
shiftDotStroke.Thickness = 1
shiftDotStroke.Transparency = 0.3
shiftDotStroke.Parent = shiftDot

--=============================================================
-- ✨ BARRA DE DURAÇÃO
--=============================================================
local durationBg = Instance.new("Frame")
durationBg.Name = "DurationBg"
durationBg.Size = UDim2.new(0.9, 0, 0, 4)
durationBg.Position = UDim2.new(0.05, 0, 0, 92)
durationBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
durationBg.BackgroundTransparency = 0.3
durationBg.BorderSizePixel = 0
durationBg.ZIndex = 3
durationBg.Visible = false
durationBg.Parent = mainFrame

local durationBgCorner = Instance.new("UICorner")
durationBgCorner.CornerRadius = UDim.new(1, 0)
durationBgCorner.Parent = durationBg

local durationFill = Instance.new("Frame")
durationFill.Name = "DurationFill"
durationFill.Size = UDim2.new(1, 0, 1, 0)
durationFill.Position = UDim2.new(0, 0, 0, 0)
durationFill.BackgroundColor3 = COR_VERDE
durationFill.BorderSizePixel = 0
durationFill.ZIndex = 4
durationFill.Parent = durationBg

local durationFillCorner = Instance.new("UICorner")
durationFillCorner.CornerRadius = UDim.new(1, 0)
durationFillCorner.Parent = durationFill

local durationGrad = Instance.new("UIGradient")
durationGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COR_CIANO),
    ColorSequenceKeypoint.new(0.5, COR_VERDE),
    ColorSequenceKeypoint.new(1, COR_AMARELO)
})
durationGrad.Parent = durationFill

--=============================================================
-- ✨ UI UPDATE
--=============================================================
local function atualizarBotaoUI()
    if not (screenGui and screenGui.Parent) then return end

    if toggleLbl and toggleLbl.Parent then
        if isActive then
            toggleLbl.Text = "⚡ SANDEVISTAN [ON]"
            toggleLbl.TextColor3 = COR_LAVANDA
            toggleBtn.BackgroundColor3 = COR_VERDE
            toggleBtn.BackgroundTransparency = 0
            toggleStroke.Color = COR_CIANO
            toggleStroke.Transparency = 0.1
            toggleAccent.BackgroundColor3 = COR_CIANO
            liveDot.BackgroundColor3 = COR_VERDE
            liveDotStroke.Color = COR_CIANO
        elseif pendingActivation then
            toggleLbl.Text = "🔊 CARREGANDO..."
            toggleLbl.TextColor3 = COR_AMARELO
            toggleBtn.BackgroundColor3 = COR_AMARELO
            toggleBtn.BackgroundTransparency = 0.2
            toggleStroke.Color = COR_AMARELO
            toggleStroke.Transparency = 0.2
            toggleAccent.BackgroundColor3 = COR_AMARELO
            liveDot.BackgroundColor3 = COR_AMARELO
            liveDotStroke.Color = COR_CIANO
        else
            toggleLbl.Text = "⚡ SANDEVISTAN [OFF]"
            toggleLbl.TextColor3 = COR_CIANO
            toggleBtn.BackgroundColor3 = COR_CIANO
            toggleBtn.BackgroundTransparency = 0.2
            toggleStroke.Color = COR_CIANO
            toggleStroke.Transparency = 0.2
            toggleAccent.BackgroundColor3 = COR_CIANO
            liveDot.BackgroundColor3 = COR_CIANO
            liveDotStroke.Color = COR_VERDE
        end
    end

    if charLbl and charLbl.Parent then
        if morphEnabled then
            charLbl.Text = "👤 CHAR PERM [ON]"
            charLbl.TextColor3 = COR_LAVANDA
            charBtn.BackgroundColor3 = COR_LAVANDA
            charBtn.BackgroundTransparency = 0
            charStroke.Color = COR_CIANO
            charStroke.Transparency = 0.1
            charAccent.BackgroundColor3 = COR_VERDE
            charDot.BackgroundColor3 = COR_VERDE
            charDotStroke.Color = COR_CIANO
        else
            charLbl.Text = "👤 CHAR PERM [OFF]"
            charLbl.TextColor3 = COR_LAVANDA
            charBtn.BackgroundColor3 = COR_CIANO
            charBtn.BackgroundTransparency = 0.2
            charStroke.Color = COR_CIANO
            charStroke.Transparency = 0.2
            charAccent.BackgroundColor3 = COR_LAVANDA
            charDot.BackgroundColor3 = COR_LAVANDA
            charDotStroke.Color = COR_VERDE
        end
    end

    if shiftLbl and shiftLbl.Parent then
        if shiftlockEnabled then
            shiftLbl.Text = "🔒 SHIFTLOCK [ON]"
            shiftLbl.TextColor3 = COR_LAVANDA
            shiftBtn.BackgroundColor3 = COR_VERDE
            shiftBtn.BackgroundTransparency = 0
            shiftStroke.Color = COR_CIANO
            shiftStroke.Transparency = 0.1
            shiftAccent.BackgroundColor3 = COR_CIANO
            shiftDot.BackgroundColor3 = COR_VERDE
            shiftDotStroke.Color = COR_CIANO
        else
            shiftLbl.Text = "🔒 SHIFTLOCK [OFF]"
            shiftLbl.TextColor3 = COR_CIANO
            shiftBtn.BackgroundColor3 = COR_CIANO
            shiftBtn.BackgroundTransparency = 0.2
            shiftStroke.Color = COR_CIANO
            shiftStroke.Transparency = 0.2
            shiftAccent.BackgroundColor3 = COR_CIANO
            shiftDot.BackgroundColor3 = COR_CIANO
            shiftDotStroke.Color = COR_VERDE
        end
    end
end

--=============================================================
-- ✨ BARRA DE DURAÇÃO — controle
--=============================================================
local function startDurationBar()
    if not (durationBg and durationBg.Parent) then return end
    durationBg.Visible = true
    durationFill.Size = UDim2.new(1, 0, 1, 0)

    if durationTask then
        pcall(function() task.cancel(durationTask) end)
    end
    durationTask = task.spawn(function()
        local start = os.clock()
        while running and isActive do
            local elapsed = os.clock() - start
            local remaining = 1 - (elapsed / SANDEVISTAN_DURATION)
            if remaining <= 0 then break end
            if durationFill and durationFill.Parent then
                durationFill.Size = UDim2.new(remaining, 0, 1, 0)
            end
            task.wait(0.03)
        end
        if durationFill and durationFill.Parent then
            durationFill.Size = UDim2.new(0, 0, 1, 0)
        end
        if durationBg and durationBg.Parent then
            durationBg.Visible = false
        end
        durationTask = nil
    end)
end

local function stopDurationBar()
    if durationTask then
        pcall(function() task.cancel(durationTask) end)
        durationTask = nil
    end
    if durationBg and durationBg.Parent then
        durationBg.Visible = false
        durationFill.Size = UDim2.new(1, 0, 1, 0)
    end
end

--=============================================================
-- ✨ TOGGLE CHAR
--=============================================================
local function toggleCharPerm()
    morphEnabled = not morphEnabled
    if morphEnabled then
        task.spawn(function()
            local ok = tryMorph()
            if ok then
                showToast("👤 CHAR PERM ATIVADO", COR_LAVANDA)
            else
                showToast("⚠ FALHA AO APLICAR CHAR", COR_VERMELHO)
            end
        end)
    else
        task.spawn(function()
            local ok = revertMorph()
            if ok then
                showToast("👤 CHAR RESTAURADO (" .. player.Name .. ")", COR_CIANO)
            else
                showToast("⚠ FALHA AO RESTAURAR CHAR", COR_VERMELHO)
            end
        end)
    end
    atualizarBotaoUI()
end

--=============================================================
-- ✨ SHIFTLOCK
--=============================================================
local function applyShiftlock()
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end)

    if shiftlockConnection then
        pcall(function() shiftlockConnection:Disconnect() end)
        shiftlockConnection = nil
    end

    shiftlockConnection = RunService.RenderStepped:Connect(function()
        if not shiftlockEnabled then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local cam = WS.CurrentCamera
        if not cam then return end

        local camCF = cam.CFrame
        root.CFrame = CFrame.new(root.Position, Vector3.new(
            camCF.LookVector.X + root.Position.X,
            root.Position.Y,
            camCF.LookVector.Z + root.Position.Z
        ))
    end)
end

local function clearShiftlock()
    if shiftlockConnection then
        pcall(function() shiftlockConnection:Disconnect() end)
        shiftlockConnection = nil
    end
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end)
end

local function toggleShiftlock()
    shiftlockEnabled = not shiftlockEnabled

    if shiftlockEnabled then
        applyShiftlock()
        showToast("🔒 SHIFTLOCK ATIVADO", COR_CIANO)
    else
        clearShiftlock()
        showToast("🔓 SHIFTLOCK DESATIVADO", COR_LAVANDA)
    end

    atualizarBotaoUI()
end

--=============================================================
-- ✨ HOVER
--=============================================================
table.insert(connections, toggleBtn.MouseEnter:Connect(function()
    if not isActive and not pendingActivation then
        pcall(function()
            TweenService:Create(hoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
        end)
        toggleBtn.BackgroundColor3 = COR_VERDE
        toggleStroke.Color = COR_CIANO
        toggleStroke.Transparency = 0.1
    end
end))

table.insert(connections, toggleBtn.MouseLeave:Connect(function()
    if not isActive and not pendingActivation then
        pcall(function()
            TweenService:Create(hoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Scale = 1}):Play()
        end)
        toggleBtn.BackgroundColor3 = COR_CIANO
        toggleBtn.BackgroundTransparency = 0.2
        toggleStroke.Color = COR_CIANO
        toggleStroke.Transparency = 0.2
    end
end))

table.insert(connections, charBtn.MouseEnter:Connect(function()
    pcall(function()
        TweenService:Create(charHoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
    end)
    charBtn.BackgroundColor3 = COR_VERDE
    charStroke.Color = COR_CIANO
    charStroke.Transparency = 0.1
end))

table.insert(connections, charBtn.MouseLeave:Connect(function()
    pcall(function()
        TweenService:Create(charHoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Scale = 1}):Play()
    end)
    if morphEnabled then
        charBtn.BackgroundColor3 = COR_LAVANDA
        charBtn.BackgroundTransparency = 0
    else
        charBtn.BackgroundColor3 = COR_CIANO
        charBtn.BackgroundTransparency = 0.2
    end
    charStroke.Color = COR_CIANO
    charStroke.Transparency = 0.2
end))

table.insert(connections, shiftBtn.MouseEnter:Connect(function()
    pcall(function()
        TweenService:Create(shiftHoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
    end)
    shiftBtn.BackgroundColor3 = COR_VERDE
    shiftStroke.Color = COR_CIANO
    shiftStroke.Transparency = 0.1
end))

table.insert(connections, shiftBtn.MouseLeave:Connect(function()
    pcall(function()
        TweenService:Create(shiftHoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Scale = 1}):Play()
    end)
    if shiftlockEnabled then
        shiftBtn.BackgroundColor3 = COR_VERDE
        shiftBtn.BackgroundTransparency = 0
    else
        shiftBtn.BackgroundColor3 = COR_CIANO
        shiftBtn.BackgroundTransparency = 0.2
    end
    shiftStroke.Color = COR_CIANO
    shiftStroke.Transparency = 0.2
end))

--=============================================================
-- ✨ PARTÍCULAS
--=============================================================
local mainParticlesFolder = nil

local function attachMainParticles()
    if not character or not character.Parent then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if mainParticlesFolder and mainParticlesFolder.Parent then
        pcall(function() mainParticlesFolder:Destroy() end)
    end

    for _, name in ipairs({ "YellowSparks", "CyanGlitch" }) do
        local orphan = hrp:FindFirstChild(name)
        if orphan then pcall(function() orphan:Destroy() end) end
    end

    mainParticlesFolder = Instance.new("Folder")
    mainParticlesFolder.Name = "SandevistanMainParticles"
    mainParticlesFolder.Parent = hrp

    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "YellowSparks"
    sparks.Color = ColorSequence.new(COR_AMARELO)
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
    sparks.Lifetime = NumberRange.new(0.2, 0.4)
    sparks.Rate = 60
    sparks.Speed = NumberRange.new(8, 15)
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.Rotation = NumberRange.new(0, 360)
    sparks.RotSpeed = NumberRange.new(-100, 100)
    sparks.Parent = mainParticlesFolder

    local glitch = Instance.new("ParticleEmitter")
    glitch.Name = "CyanGlitch"
    glitch.Color = ColorSequence.new(COR_CIANO)
    glitch.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    glitch.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
    glitch.Lifetime = NumberRange.new(0.3, 0.6)
    glitch.Rate = 30
    glitch.Speed = NumberRange.new(2, 5)
    glitch.SpreadAngle = Vector2.new(360, 360)
    glitch.Parent = mainParticlesFolder
end

local function removeMainParticles()
    if mainParticlesFolder and mainParticlesFolder.Parent then
        pcall(function() mainParticlesFolder:Destroy() end)
        mainParticlesFolder = nil
    end
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, n in ipairs({ "YellowSparks", "CyanGlitch" }) do
                local obj = hrp:FindFirstChild(n)
                if obj then pcall(function() obj:Destroy() end) end
            end
        end
    end
end

--=============================================================
-- ✨ FLASHES
--=============================================================
local function flashScreen()
    if flashGui and flashGui.Parent then
        pcall(function() flashGui:Destroy() end)
    end

    local newGui = Instance.new("ScreenGui")
    newGui.Name = "SandevistanFlashGui"
    newGui.IgnoreGuiInset = true
    newGui.ResetOnSpawn = false
    newGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    newGui.DisplayOrder = 1000001
    local okParent = pcall(function() newGui.Parent = GUI_PARENT end)
    if not okParent or not newGui.Parent then
        pcall(function() newGui:Destroy() end)
        return
    end
    flashGui = newGui

    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.Position = UDim2.new(0, 0, 0, 0)
    flash.BackgroundColor3 = COR_CIANO
    flash.BorderSizePixel = 0
    flash.BackgroundTransparency = 1
    flash.ZIndex = 999
    flash.Parent = newGui

    local tweenIn = TweenService:Create(flash, TweenInfo.new(0.05), { BackgroundTransparency = 0 })
    tweenIn:Play()
    waitTween(tweenIn, 0.5)

    if not newGui.Parent then
        if flashGui == newGui then flashGui = nil end
        return
    end

    local tweenOut = TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
    tweenOut:Play()
    waitTween(tweenOut, 0.8)

    if newGui.Parent then
        pcall(function() newGui:Destroy() end)
    end
    if flashGui == newGui then flashGui = nil end
end

local function blackFlash()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SandevistanBlackFlash"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 1000001
    local okParent = pcall(function() gui.Parent = GUI_PARENT end)
    if not okParent or not gui.Parent then
        pcall(function() gui:Destroy() end)
        return
    end

    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.Position = UDim2.new(0, 0, 0, 0)
    flash.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    flash.BorderSizePixel = 0
    flash.BackgroundTransparency = 1
    flash.ZIndex = 9999
    flash.Parent = gui

    local tweenIn = TweenService:Create(flash, TweenInfo.new(0.05), { BackgroundTransparency = 0 })
    tweenIn:Play()
    waitTween(tweenIn, 0.5)

    task.wait(0.1)

    local tweenOut = TweenService:Create(flash, TweenInfo.new(0.15), { BackgroundTransparency = 1 })
    tweenOut:Play()
    waitTween(tweenOut, 0.5)

    pcall(function() gui:Destroy() end)
end

--=============================================================
-- ✨ CAMERA SHAKE
--=============================================================
local function cameraShake(duration, magnitude)
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.Parent then return end

    if currentShakeConnection then
        pcall(function() currentShakeConnection:Disconnect() end)
        currentShakeConnection = nil
    end

    local myConn
    local startTime = os.clock()
    myConn = RunService.RenderStepped:Connect(function()
        local elapsed = os.clock() - startTime
        if elapsed > duration or not hum.Parent or not running then
            if myConn then pcall(function() myConn:Disconnect() end) end
            if currentShakeConnection == myConn then
                currentShakeConnection = nil
                pcall(function() hum.CameraOffset = Vector3.zero end)
            end
            return
        end
        hum.CameraOffset = Vector3.new(
            (math.random() - 0.5) * 2 * magnitude,
            (math.random() - 0.5) * 2 * magnitude,
            0
        )
    end)
    currentShakeConnection = myConn
end

--=============================================================
-- ✨ CLONES (cor fixa por clone — original)
--=============================================================
local function createClone()
    if not isActive then return end
    if not character or not character.Parent then return end
    if not character:FindFirstChild("HumanoidRootPart") then return end
    if #activeClones >= MAX_CLONES then return end
    if not isCharacterMoving() then return end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if not character.Archivable then
        pcall(function() character.Archivable = true end)
    end

    local okClone, clone = pcall(function() return character:Clone() end)
    if not okClone or not clone then return end

    clone.Name = "SandevistanClone"
    clone.Parent = WS

    local cloneRoot = clone:FindFirstChild("HumanoidRootPart")
    if cloneRoot then
        pcall(function() clone:PivotTo(root.CFrame * CFrame.new(0, 1.5, 0)) end)
    end

    local humanoidClone = clone:FindFirstChildOfClass("Humanoid")
    if humanoidClone then humanoidClone:Destroy() end

    -- Cor FIXA por clone (gradiente contínuo, sem tween)
    cloneColorIndex = cloneColorIndex + 1
    local step = (cloneColorIndex - 1) % MAX_CLONES
    local t = step / (MAX_CLONES - 1)
    local corDoClone = getGradientColor(t)

    for _, obj in ipairs(clone:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Anchored = true
            obj.CanCollide = false
            obj.Material = CLONE_MATERIAL
            obj.Transparency = CLONE_TRANSPARENCY
            obj.Color = corDoClone
            obj.Reflectance = 0
        elseif obj:IsA("Decal") then
            obj.Transparency = 1
        elseif obj:IsA("Clothing") then
            pcall(function() obj:Destroy() end)
        elseif obj:IsA("Accessory") then
            for _, part in ipairs(obj:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Color = corDoClone
                    part.Transparency = CLONE_TRANSPARENCY
                    part.Material = CLONE_MATERIAL
                elseif part:IsA("Decal") then
                    part.Transparency = 1
                end
            end
        end
    end

    local highlight = Instance.new("Highlight")
    highlight.FillColor = corDoClone
    highlight.OutlineColor = corDoClone
    highlight.FillTransparency = CLONE_HIGHLIGHT_FILL
    highlight.OutlineTransparency = CLONE_HIGHLIGHT_LINE
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = clone

    if cloneRoot then
        local trailParticle = Instance.new("ParticleEmitter")
        trailParticle.Name = "CloneTrail"
        trailParticle.Color = ColorSequence.new(corDoClone)
        trailParticle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        trailParticle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)})
        trailParticle.Lifetime = NumberRange.new(0.5, 1)
        trailParticle.Rate = 40
        trailParticle.Speed = NumberRange.new(0, 2)
        trailParticle.SpreadAngle = Vector2.new(360, 360)
        trailParticle.Parent = cloneRoot
    end

    -- Sem tween: cor fixa até o clone ser destruído

    table.insert(activeClones, { clone = clone, highlight = highlight })
end

local function cleanupClones()
    local copia = activeClones
    activeClones = {}

    for _, data in ipairs(copia) do
        local clone = data.clone
        if clone and clone.Parent then
            pcall(function() clone:Destroy() end)
        end
    end

    for _, obj in ipairs(WS:GetChildren()) do
        if obj.Name == "SandevistanClone" then
            pcall(function() obj:Destroy() end)
        end
    end
end

local function startCloneSpawning()
    if cloneTask then
        pcall(function() task.cancel(cloneTask) end)
        cloneTask = nil
    end
    cloneSpawning = true
    cloneTask = task.spawn(function()
        while cloneSpawning and isActive do
            createClone()
            task.wait(CLONE_INTERVAL)
        end
        cloneTask = nil
    end)
end

local function stopCloneSpawning()
    cloneSpawning = false
    if cloneTask then
        pcall(function() task.cancel(cloneTask) end)
        cloneTask = nil
    end
end

--=============================================================
-- ✨ VISUAIS
--=============================================================
local function setVisuals(active)
    pcall(function()
        local target = active and {
            Contrast = MUNDO_CONTRAST,
            Saturation = MUNDO_SATURATION,
            Brightness = MUNDO_BRIGHTNESS,
            TintColor = COR_MUNDO_ATIVO
        } or {
            Contrast = 0,
            Saturation = 0,
            Brightness = 0,
            TintColor = Color3.new(1, 1, 1)
        }
        TweenService:Create(colorCorrection, TweenInfo.new(0.4), target):Play()
    end)

    if active then
        pcall(function()
            TweenService:Create(bloomEffect, TweenInfo.new(0.5), {
                Intensity = BLOOM_INTENSITY,
                Threshold = BLOOM_THRESHOLD
            }):Play()
        end)
        if glitchOverlay then glitchOverlay.Visible = true end

        if not glitchPulseRunning then
            glitchPulseRunning = true
            task.spawn(function()
                while isActive and glitchOverlay and glitchOverlay.Parent do
                    pcall(function()
                        TweenService:Create(overlayStroke, TweenInfo.new(0.5), {Transparency = 0.6}):Play()
                    end)
                    task.wait(0.5)
                    if not (isActive and glitchOverlay and glitchOverlay.Parent) then break end
                    pcall(function()
                        TweenService:Create(overlayStroke, TweenInfo.new(0.5), {Transparency = 0.9}):Play()
                    end)
                    task.wait(0.5)
                end
                glitchPulseRunning = false
            end)
        end
    else
        pcall(function()
            TweenService:Create(bloomEffect, TweenInfo.new(0.5), {Intensity = 0, Threshold = 1.5}):Play()
        end)
        if glitchOverlay then glitchOverlay.Visible = false end
        if overlayStroke then overlayStroke.Transparency = 1 end
    end
end

--=============================================================
-- ✨ LAG SWITCH
--=============================================================
local function activateLagSwitch()
    if not character or not character.Parent then return end
    local hrp   = character:FindFirstChild("HumanoidRootPart")
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if not hrp or not torso then return end

    if activeSeat then pcall(function() activeSeat:Destroy() end) end
    if activeWeld then pcall(function() activeWeld:Destroy() end) end

    local seat = Instance.new("Seat")
    seat.Name = "invischair"
    seat.Transparency = 1
    seat.Anchored = false
    seat.CanCollide = false
    seat.Size = Vector3.new(2, 1, 2)
    seat.CFrame = hrp.CFrame
    seat.Parent = WS
    activeSeat = seat

    local weld = Instance.new("Weld")
    weld.Part0 = seat
    weld.Part1 = torso
    weld.C0 = CFrame.new()
    weld.C1 = CFrame.new()
    weld.Parent = seat
    activeWeld = weld

    pcall(function()
        seat.AssemblyAngularVelocity = Vector3.zero
        seat.AssemblyLinearVelocity = Vector3.zero
    end)

    if lagSwitchWatchdog then
        pcall(function() task.cancel(lagSwitchWatchdog) end)
    end
    lagSwitchWatchdog = task.delay(SANDEVISTAN_DURATION + 1.5, function()
        if activeSeat or activeWeld then
            warn("[Sandevistan] Watchdog: lag switch travado, limpando.")
            pcall(function() deactivateLagSwitch() end)
        end
    end)
end

local function deactivateLagSwitch()
    if lagSwitchWatchdog then
        pcall(function() task.cancel(lagSwitchWatchdog) end)
        lagSwitchWatchdog = nil
    end
    if activeWeld then
        pcall(function() activeWeld:Destroy() end)
        activeWeld = nil
    end
    if activeSeat then
        pcall(function() activeSeat:Destroy() end)
        activeSeat = nil
    end
end

--=============================================================
-- ✨ ARCHIVABLE
--=============================================================
local function captureOriginalArchivable()
    if not character then return end
    if archivableCaptured and archivableChar == character then return end
    originalArchivable = character.Archivable
    archivableCaptured = true
    archivableChar = character
end

local function restoreArchivable()
    if not archivableCaptured then return end
    if character and archivableChar == character then
        pcall(function() character.Archivable = originalArchivable end)
    end
end

--=============================================================
-- ✨ ACTIVATE / DEACTIVATE
--=============================================================
local activate, deactivate

activate = function()
    if not running then return false end
    if isActive or isDeactivating or pendingActivation then return false end
    if not character or not character.Parent then
        warn("[Sandevistan] Personagem não disponível.")
        return false
    end
    if not humanoid or not humanoid.Parent then
        warn("[Sandevistan] Humanoid não disponível.")
        return false
    end

    pendingActivation = true
    atualizarBotaoUI()

    local myToken = deactivateToken
    playIntroAudioSequence()

    if not running or myToken ~= deactivateToken then
        pendingActivation = false
        atualizarBotaoUI()
        return false
    end

    pendingActivation = false
    isActive = true
    cloneColorIndex = 0
    captureOriginalArchivable()

    local ok, err = xpcall(function()
        pcall(function() character.Archivable = true end)
        pcall(function() humanoid.WalkSpeed = BOOSTED_SPEED end)

        setVisuals(true)
        applyFovKick(true)

        activateLagSwitch()
        attachMainParticles()

        task.spawn(function()
            flashScreen()
            cameraShake(0.25, 0.2)
        end)

        startCloneSpawning()
        startDurationBar()
        atualizarBotaoUI()

        deactivateToken = deactivateToken + 1
        local myDelayToken = deactivateToken
        task.delay(SANDEVISTAN_DURATION, function()
            if myDelayToken ~= deactivateToken then return end
            if not isActive then return end
            local ok2, err2 = pcall(deactivate)
            if not ok2 then
                warn("[Sandevistan] deactivate error: " .. tostring(err2))
                isDeactivating = false
                isActive = false
            end
        end)
    end, function(e) return e end)

    if not ok then
        warn("[Sandevistan] activate falhou: " .. tostring(err))
        isActive = false
        deactivateToken = deactivateToken + 1
        pcall(function() stopCloneSpawning() end)
        pcall(function() cleanupClones() end)
        pcall(function() removeMainParticles() end)
        pcall(function() deactivateLagSwitch() end)
        pcall(stopDurationBar)
        setVisuals(false)
        applyFovKick(false)
        if humanoid and humanoid.Parent then
            pcall(function() humanoid.WalkSpeed = NORMAL_SPEED end)
        end
        restoreArchivable()
        pcall(function() atualizarBotaoUI() end)
        return false
    end

    return true
end

deactivate = function()
    if not isActive or isDeactivating then return false end
    isDeactivating = true
    isActive = false
    deactivateToken = deactivateToken + 1

    local ok, err = xpcall(function()
        task.spawn(function()
            local ok1, err1 = pcall(blackFlash)
            if not ok1 then warn("[Sandevistan] blackFlash: " .. tostring(err1)) end
        end)

        stopCloneSpawning()
        stopDurationBar()
        task.wait(CLONE_INTERVAL * 1.5)

        pcall(cleanupClones)
        removeMainParticles()

        if humanoid and humanoid.Parent then
            pcall(function() humanoid.WalkSpeed = NORMAL_SPEED end)
        end

        setVisuals(false)
        applyFovKick(false)
        deactivateLagSwitch()

        restoreArchivable()

        if sound then
            pcall(function() sound:Stop() end)
        end
        if swoosh then
            pcall(function() swoosh:Stop() end)
        end

        task.spawn(function() cameraShake(0.2, 0.15) end)
        atualizarBotaoUI()
    end, function(e) return e end)

    if not ok then
        warn("[Sandevistan] deactivate falhou: " .. tostring(err))
        pcall(function() stopCloneSpawning() end)
        pcall(stopDurationBar)
        pcall(function() cleanupClones() end)
        pcall(function() removeMainParticles() end)
        pcall(function() deactivateLagSwitch() end)
        setVisuals(false)
        applyFovKick(false)
        if humanoid and humanoid.Parent then
            pcall(function() humanoid.WalkSpeed = NORMAL_SPEED end)
        end
        restoreArchivable()
    end

    isDeactivating = false
    return true
end

--=============================================================
-- ✨ TOGGLE
--=============================================================
local function toggleSandevistan()
    if not running then return end
    if isDeactivating or pendingActivation then return end
    local now = os.clock()
    if now - lastToggleTime < TOGGLE_COOLDOWN then return end

    local ok
    if isActive then
        ok = deactivate()
    else
        ok = activate()
    end

    if ok then
        lastToggleTime = now
    end
end

--=============================================================
-- ✨ HANDLERS
--=============================================================
table.insert(connections, toggleBtn.MouseButton1Click:Connect(function()
    toggleSandevistan()
end))

table.insert(connections, charBtn.MouseButton1Click:Connect(function()
    toggleCharPerm()
end))

table.insert(connections, shiftBtn.MouseButton1Click:Connect(function()
    toggleShiftlock()
end))

local function bindCharacter(char)
    local newHum = char:WaitForChild("Humanoid", 10)

    if player.Character ~= char or not char.Parent then return end

    if character ~= char then
        archivableCaptured = false
        originalArchivable = nil
        archivableChar = nil
    end

    character = char
    humanoid = newHum

    if not humanoid then
        warn("[Sandevistan] Humanoid não encontrado.")
    end

    if not normalSpeedCaptured and humanoid then
        normalSpeedCaptured = true
        NORMAL_SPEED = math.max(humanoid.WalkSpeed, 16)
    end

    if isActive then
        task.spawn(function()
            char:WaitForChild("HumanoidRootPart", 5)
            if not isActive then return end
            if character ~= char or not char.Parent then return end
            if player.Character ~= char then return end

            local hum2 = humanoid
            if not hum2 or not hum2.Parent then
                hum2 = char:WaitForChild("Humanoid", 5)
            end
            if not isActive then return end
            if character ~= char or not char.Parent then return end

            if hum2 and hum2.Parent then
                pcall(function() hum2.WalkSpeed = BOOSTED_SPEED end)
            end
            removeMainParticles()
            captureOriginalArchivable()
            pcall(function() char.Archivable = true end)
            attachMainParticles()
            activateLagSwitch()
        end)
    end

    if morphEnabled then
        task.spawn(function()
            task.wait(0.5)
            if not character or not character.Parent then return end
            if player.Character ~= character then return end
            local ok = tryMorph()
            if ok then
                print("[Sandevistan] Morph aplicado: " .. MORPH_USERNAME)
            else
                warn("[Sandevistan] Falha ao aplicar morph")
            end
        end)
    end

    if shiftlockEnabled then
        task.spawn(function()
            task.wait(0.5)
            if character == char and char.Parent then
                applyShiftlock()
            end
        end)
    end
end

table.insert(connections, player.CharacterAdded:Connect(bindCharacter))
if player.Character then
    bindCharacter(player.Character)
end

table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == TOGGLE_KEY then
        toggleSandevistan()
    end
end))

atualizarBotaoUI()

--=============================================================
-- ✨ ÓRFÃOS LOOP
--=============================================================
task.spawn(function()
    while running do
        for _ = 1, 50 do
            if not running then break end
            task.wait(0.1)
        end
        if not running then break end
        if not isActive then
            for _, obj in ipairs(WS:GetChildren()) do
                if obj.Name == "SandevistanClone" then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end
end)

--=============================================================
-- ✨ CLEANUP
--=============================================================
local function fullCleanup()
    running = false
    deactivateToken = deactivateToken + 1
    pendingActivation = false

    pcall(clearShiftlock)

    local cam = WS.CurrentCamera
    if cam and originalFov then
        pcall(function() cam.FieldOfView = originalFov end)
    end

    if humanoid and humanoid.Parent then
        pcall(function() humanoid.WalkSpeed = NORMAL_SPEED end)
        pcall(function() humanoid.CameraOffset = Vector3.zero end)
        pcall(function() humanoid.AutoRotate = true end)
    end

    isActive = false
    isDeactivating = false
    cloneSpawning = false

    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)

    stopCloneSpawning()
    pcall(cleanupClones)
    pcall(deactivateLagSwitch)
    removeMainParticles()

    if durationTask then
        pcall(function() task.cancel(durationTask) end)
        durationTask = nil
    end

    if toastTask then
        pcall(function() task.cancel(toastTask) end)
        toastTask = nil
    end

    if currentShakeConnection then
        pcall(function() currentShakeConnection:Disconnect() end)
        currentShakeConnection = nil
    end

    if flashGui and flashGui.Parent then pcall(function() flashGui:Destroy() end) end
    flashGui = nil

    if toastGui and toastGui.Parent then pcall(function() toastGui:Destroy() end) end
    toastGui = nil

    if screenGui and screenGui.Parent then pcall(function() screenGui:Destroy() end) end
    if colorCorrection and colorCorrection.Parent then pcall(function() colorCorrection:Destroy() end) end
    if bloomEffect and bloomEffect.Parent then pcall(function() bloomEffect:Destroy() end) end
    if sound and sound.Parent then pcall(function() sound:Destroy() end) end
    if swoosh and swoosh.Parent then pcall(function() swoosh:Destroy() end) end

    restoreArchivable()

    character = nil
    humanoid = nil
    mainParticlesFolder = nil

    if GENV then
        GENV.SandevistanCleanup = nil
    end
end

if GENV then
    GENV.SandevistanCleanup = fullCleanup
end

--=============================================================
-- ✨ BOOT
--=============================================================
print("✨ SANDEVISTAN v4.10 — EDGERUNNERS EDITION")
print("[Sandevistan] F ou clique: liga/desliga")
print("[Sandevistan] Duração: 3.5s | Velocidade: 28")
print("[Sandevistan] Clones: opacos, cor fixa por clone (gradiente)")
print("[Sandevistan] FOV kick: 70 -> 100 na ativação")
print("[Sandevistan] Menu: SANDEVISTAN | CHAR PERM | SHIFTLOCK")