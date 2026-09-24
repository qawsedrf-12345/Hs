--=============================================================
-- SANDEVISTAN v4.1 — EDGERUNNERS EDITION
-- Fixes: archivable preservation, task.delay token pattern,
--        flash DisplayOrder, char/humanoid sync window.
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
local TeleportService   = game:GetService("TeleportService")
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

    killChildren(GUI_PARENT,  { "SandevistanGUI", "SandevistanFlashGui", "SandevistanBlackFlash" })
    killChildren(WS,          { "SandevistanSound", "invischair" })
    killChildren(SoundService,{ "SandevistanSound" })
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
local TOGGLE_KEY            = Enum.KeyCode.F
local NORMAL_SPEED          = 16
local BOOSTED_SPEED         = 140
local SANDEVISTAN_DURATION  = 3.5
local CLONE_INTERVAL        = 0.1
local MAX_CLONES            = 30
local TOGGLE_COOLDOWN       = 0.3
local MORPH_USERNAME        = "ZiemekaTheSequel"

--=============================================================
-- ⚡ STATE
--=============================================================
local isActive              = false
local isDeactivating        = false
local isMorphing            = false
local glitchPulseRunning    = false
local normalSpeedCaptured   = false
local soundReady            = false
local flashGui              = nil
local currentShakeConnection= nil
local deactivateToken       = 0
local character, humanoid
local cloneSpawning         = false
local cloneTask             = nil
local activeSeat            = nil
local activeWeld            = nil
local activeClones          = {}
local connections           = {}
local morphUserId           = nil
local running               = true
local rejoining             = false
local lastToggleTime        = -math.huge
local originalArchivable    = nil
local archivableCaptured    = false

--=============================================================
-- 🎨 PALETA
--=============================================================
local COR_CIANO    = Color3.fromRGB(0, 240, 255)
local COR_VERDE    = Color3.fromRGB(75, 255, 33)
local COR_LAVANDA  = Color3.fromRGB(244, 213, 253)
local COR_AMARELO  = Color3.fromRGB(255, 215, 0)

--=============================================================
-- 🎨 POST-PROCESSING
--=============================================================
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "SandevistanEffect"
colorCorrection.Parent = Lighting

local bloomEffect = Instance.new("BloomEffect")
bloomEffect.Name = "SandevistanBloom"
bloomEffect.Intensity = 0
bloomEffect.Size = 24
bloomEffect.Threshold = 1.5
bloomEffect.Parent = Lighting

--=============================================================
-- 🔊 SOM
--=============================================================
local sound = Instance.new("Sound")
sound.Name = "SandevistanSound"
sound.SoundId = "rbxassetid://130840290979991"
sound.Volume = 1
sound.Looped = false
sound.Parent = SoundService

task.spawn(function()
    local ok = pcall(function()
        ContentProvider:PreloadAsync({ sound })
    end)
    soundReady = ok
    if not ok then
        warn("[Sandevistan] Falha no preload do som.")
    end
end)

--=============================================================
-- 🎨 SEQUÊNCIAS
--=============================================================
local colorSequence = { COR_CIANO, COR_VERDE, COR_LAVANDA }

local effectColors = {
    Active   = { Contrast = 0.5, Saturation = 0.25, TintColor = Color3.fromRGB(85, 255, 127) },
    Inactive = { Contrast = 0,   Saturation = 0,    TintColor = Color3.new(1, 1, 1) }
}

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

--=============================================================
-- 🖥️ UI
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
mainFrame.Size = UDim2.new(0, 120, 0, 140)
mainFrame.Position = UDim2.new(0, 20, 0.35, -70)
mainFrame.BackgroundColor3 = COR_CIANO
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
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
-- 🎯 DRAG CUSTOM
--=============================================================
do
    local dragArea = Instance.new("TextButton")
    dragArea.Name = "DragArea"
    dragArea.Size = UDim2.new(1, 0, 0, 20)
    dragArea.Position = UDim2.new(0, 0, 0, 0)
    dragArea.BackgroundTransparency = 1
    dragArea.Text = ""
    dragArea.AutoButtonColor = false
    dragArea.ZIndex = 20
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

local innerScreen = Instance.new("Frame")
innerScreen.Size = UDim2.new(1, -8, 1, -8)
innerScreen.Position = UDim2.new(0, 4, 0, 4)
innerScreen.BackgroundColor3 = COR_VERDE
innerScreen.BackgroundTransparency = 0.75
innerScreen.BorderSizePixel = 0
innerScreen.ClipsDescendants = true
innerScreen.Parent = mainFrame

local innerCorner = Instance.new("UICorner")
innerCorner.CornerRadius = UDim.new(0, 3)
innerCorner.Parent = innerScreen

local innerStroke = Instance.new("UIStroke")
innerStroke.Color = COR_CIANO
innerStroke.Thickness = 1
innerStroke.Transparency = 0.2
innerStroke.Parent = innerScreen

local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, 0, 0, 2)
statusBar.BackgroundColor3 = COR_CIANO
statusBar.BorderSizePixel = 0
statusBar.ZIndex = 3
statusBar.Parent = innerScreen

local statusGrad = Instance.new("UIGradient")
statusGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COR_CIANO),
    ColorSequenceKeypoint.new(0.5, COR_VERDE),
    ColorSequenceKeypoint.new(1, COR_CIANO)
})
statusGrad.Parent = statusBar

local titleTag = Instance.new("TextLabel")
titleTag.Size = UDim2.new(1, -10, 0, 8)
titleTag.Position = UDim2.new(0, 5, 0, 5)
titleTag.BackgroundTransparency = 1
titleTag.Text = "▰ SANDEVISTAN OS"
titleTag.TextColor3 = COR_CIANO
titleTag.Font = Enum.Font.Code
titleTag.TextSize = 6
titleTag.TextXAlignment = Enum.TextXAlignment.Left
titleTag.ZIndex = 4
titleTag.Parent = innerScreen

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -10, 0, 12)
title.Position = UDim2.new(0, 5, 0, 13)
title.BackgroundTransparency = 1
title.Text = "CHROME SYSTEM"
title.TextColor3 = COR_VERDE
title.Font = Enum.Font.GothamBlack
title.TextSize = 10
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 4
title.Parent = innerScreen

local titleGrad = Instance.new("UIGradient")
titleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COR_CIANO),
    ColorSequenceKeypoint.new(0.5, COR_VERDE),
    ColorSequenceKeypoint.new(1, COR_CIANO)
})
titleGrad.Parent = title

local liveDot = Instance.new("Frame")
liveDot.Size = UDim2.new(0, 6, 0, 6)
liveDot.Position = UDim2.new(1, -14, 0, 6)
liveDot.BackgroundColor3 = COR_CIANO
liveDot.BorderSizePixel = 0
liveDot.ZIndex = 4
liveDot.Parent = innerScreen

local liveDotCorner = Instance.new("UICorner")
liveDotCorner.CornerRadius = UDim.new(1, 0)
liveDotCorner.Parent = liveDot

local liveDotStroke = Instance.new("UIStroke")
liveDotStroke.Color = COR_VERDE
liveDotStroke.Thickness = 1
liveDotStroke.Transparency = 0.3
liveDotStroke.Parent = liveDot

task.spawn(function()
    while running and liveDot and liveDot.Parent do
        liveDot.BackgroundTransparency = 0
        liveDotStroke.Transparency = 0.1
        pcall(function()
            TweenService:Create(liveDot, TweenInfo.new(0.3), {Size = UDim2.new(0, 8, 0, 8)}):Play()
        end)
        task.wait(0.8)
        if not (running and liveDot and liveDot.Parent) then break end
        liveDot.BackgroundTransparency = 0.7
        liveDotStroke.Transparency = 0.8
        pcall(function()
            TweenService:Create(liveDot, TweenInfo.new(0.3), {Size = UDim2.new(0, 4, 0, 4)}):Play()
        end)
        task.wait(0.8)
    end
end)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleButton"
toggleBtn.Size = UDim2.new(0.9, 0, 0, 24)
toggleBtn.Position = UDim2.new(0.05, 0, 0, 32)
toggleBtn.BackgroundColor3 = COR_CIANO
toggleBtn.BackgroundTransparency = 0.2
toggleBtn.Text = ""
toggleBtn.AutoButtonColor = false
toggleBtn.BorderSizePixel = 0
toggleBtn.ZIndex = 4
toggleBtn.Parent = innerScreen

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 4)
toggleCorner.Parent = toggleBtn

local toggleGrad = Instance.new("UIGradient")
toggleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COR_CIANO),
    ColorSequenceKeypoint.new(0.5, COR_VERDE),
    ColorSequenceKeypoint.new(1, COR_CIANO)
})
toggleGrad.Rotation = 90
toggleGrad.Parent = toggleBtn

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = COR_CIANO
toggleStroke.Thickness = 1
toggleStroke.Transparency = 0.2
toggleStroke.Parent = toggleBtn

local toggleAccent = Instance.new("Frame")
toggleAccent.Name = "Accent"
toggleAccent.Size = UDim2.new(0, 3, 1, -6)
toggleAccent.Position = UDim2.new(0, 0, 0, 3)
toggleAccent.BackgroundColor3 = COR_CIANO
toggleAccent.BorderSizePixel = 0
toggleAccent.ZIndex = 5
toggleAccent.Parent = toggleBtn

local toggleAccentCorner = Instance.new("UICorner")
toggleAccentCorner.CornerRadius = UDim.new(1, 0)
toggleAccentCorner.Parent = toggleAccent

local toggleLbl = Instance.new("TextLabel")
toggleLbl.Name = "Label"
toggleLbl.Size = UDim2.new(1, -14, 1, 0)
toggleLbl.Position = UDim2.new(0, 12, 0, 0)
toggleLbl.BackgroundTransparency = 1
toggleLbl.Text = "⚡ SANDEVISTAN [OFF]"
toggleLbl.TextColor3 = COR_CIANO
toggleLbl.Font = Enum.Font.Code
toggleLbl.TextSize = 7
toggleLbl.TextXAlignment = Enum.TextXAlignment.Left
toggleLbl.ZIndex = 5
toggleLbl.Parent = toggleBtn

local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Name = "RejoinButton"
rejoinBtn.Size = UDim2.new(0.9, 0, 0, 20)
rejoinBtn.Position = UDim2.new(0.05, 0, 0, 60)
rejoinBtn.BackgroundColor3 = COR_LAVANDA
rejoinBtn.BackgroundTransparency = 0.2
rejoinBtn.Text = ""
rejoinBtn.AutoButtonColor = false
rejoinBtn.BorderSizePixel = 0
rejoinBtn.ZIndex = 4
rejoinBtn.Parent = innerScreen

local rejoinCorner = Instance.new("UICorner")
rejoinCorner.CornerRadius = UDim.new(0, 4)
rejoinCorner.Parent = rejoinBtn

local rejoinGrad = Instance.new("UIGradient")
rejoinGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COR_LAVANDA),
    ColorSequenceKeypoint.new(0.5, COR_CIANO),
    ColorSequenceKeypoint.new(1, COR_LAVANDA)
})
rejoinGrad.Rotation = 90
rejoinGrad.Parent = rejoinBtn

local rejoinStroke = Instance.new("UIStroke")
rejoinStroke.Color = COR_CIANO
rejoinStroke.Thickness = 1
rejoinStroke.Transparency = 0.2
rejoinStroke.Parent = rejoinBtn

local rejoinAccent = Instance.new("Frame")
rejoinAccent.Name = "Accent"
rejoinAccent.Size = UDim2.new(0, 3, 1, -6)
rejoinAccent.Position = UDim2.new(0, 0, 0, 3)
rejoinAccent.BackgroundColor3 = COR_VERDE
rejoinAccent.BorderSizePixel = 0
rejoinAccent.ZIndex = 5
rejoinAccent.Parent = rejoinBtn

local rejoinAccentCorner = Instance.new("UICorner")
rejoinAccentCorner.CornerRadius = UDim.new(1, 0)
rejoinAccentCorner.Parent = rejoinAccent

local rejoinLbl = Instance.new("TextLabel")
rejoinLbl.Name = "Label"
rejoinLbl.Size = UDim2.new(1, -14, 1, 0)
rejoinLbl.Position = UDim2.new(0, 12, 0, 0)
rejoinLbl.BackgroundTransparency = 1
rejoinLbl.Text = "🔁 REJOIN"
rejoinLbl.TextColor3 = COR_CIANO
rejoinLbl.Font = Enum.Font.Code
rejoinLbl.TextSize = 7
rejoinLbl.TextXAlignment = Enum.TextXAlignment.Left
rejoinLbl.ZIndex = 5
rejoinLbl.Parent = rejoinBtn

local rejoinHoverScale = Instance.new("UIScale")
rejoinHoverScale.Scale = 1
rejoinHoverScale.Parent = rejoinBtn

table.insert(connections, rejoinBtn.MouseEnter:Connect(function()
    pcall(function()
        TweenService:Create(rejoinHoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
    end)
    rejoinBtn.BackgroundColor3 = COR_VERDE
    rejoinStroke.Color = COR_CIANO
    rejoinStroke.Transparency = 0.1
    rejoinLbl.TextColor3 = COR_LAVANDA
end))

table.insert(connections, rejoinBtn.MouseLeave:Connect(function()
    pcall(function()
        TweenService:Create(rejoinHoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Scale = 1}):Play()
    end)
    rejoinBtn.BackgroundColor3 = COR_LAVANDA
    rejoinBtn.BackgroundTransparency = 0.2
    rejoinStroke.Color = COR_CIANO
    rejoinStroke.Transparency = 0.2
    rejoinLbl.TextColor3 = COR_CIANO
end))

table.insert(connections, rejoinBtn.MouseButton1Click:Connect(function()
    if rejoining then return end
    rejoining = true
    rejoinLbl.Text = "🔁 REJOIN..."

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end)

    task.delay(3, function()
        if rejoinLbl and rejoinLbl.Parent then
            rejoinLbl.Text = "🔁 REJOIN"
        end
        rejoining = false
        if not ok then
            warn("[Sandevistan] Rejoin falhou.")
        end
    end)
end))

local footerLabel = Instance.new("TextLabel")
footerLabel.Size = UDim2.new(1, -8, 0, 10)
footerLabel.Position = UDim2.new(0, 4, 1, -13)
footerLabel.BackgroundTransparency = 1
footerLabel.Text = "PRESSIONE [F] OU CLIQUE"
footerLabel.TextColor3 = COR_CIANO
footerLabel.Font = Enum.Font.Code
footerLabel.TextSize = 6
footerLabel.TextXAlignment = Enum.TextXAlignment.Center
footerLabel.ZIndex = 4
footerLabel.Parent = innerScreen

local hoverScale = Instance.new("UIScale")
hoverScale.Scale = 1
hoverScale.Parent = toggleBtn

table.insert(connections, toggleBtn.MouseEnter:Connect(function()
    if not isActive then
        pcall(function()
            TweenService:Create(hoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
        end)
        toggleBtn.BackgroundColor3 = COR_VERDE
        toggleStroke.Color = COR_CIANO
        toggleStroke.Transparency = 0.1
        toggleLbl.TextColor3 = COR_CIANO
    end
end))

table.insert(connections, toggleBtn.MouseLeave:Connect(function()
    if not isActive then
        pcall(function()
            TweenService:Create(hoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Scale = 1}):Play()
        end)
        toggleBtn.BackgroundColor3 = COR_CIANO
        toggleBtn.BackgroundTransparency = 0.2
        toggleStroke.Color = COR_CIANO
        toggleStroke.Transparency = 0.2
        toggleLbl.TextColor3 = COR_CIANO
    end
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
-- ✨ CLONES
--=============================================================
local function createClone()
    if not isActive then return end
    if not character or not character.Parent then return end
    if not character:FindFirstChild("HumanoidRootPart") then return end
    if #activeClones >= MAX_CLONES then return end

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

    local corInicial = colorSequence[1]

    for _, obj in ipairs(clone:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Anchored = true
            obj.CanCollide = false
            obj.Material = Enum.Material.Neon
            obj.Transparency = 0
            obj.Color = corInicial
            obj.Reflectance = 0
        elseif obj:IsA("Decal") then
            obj.Transparency = 1
        elseif obj:IsA("Clothing") then
            pcall(function() obj:Destroy() end)
        elseif obj:IsA("Accessory") then
            for _, part in ipairs(obj:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Color = corInicial
                    part.Transparency = 0
                    part.Material = Enum.Material.Neon
                elseif part:IsA("Decal") then
                    part.Transparency = 1
                end
            end
        end
    end

    local highlight = Instance.new("Highlight")
    highlight.FillColor = corInicial
    highlight.OutlineColor = corInicial
    highlight.FillTransparency = 0.0
    highlight.OutlineTransparency = 0.2
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = clone

    if cloneRoot then
        local trailParticle = Instance.new("ParticleEmitter")
        trailParticle.Name = "CloneTrail"
        trailParticle.Color = ColorSequence.new(COR_CIANO)
        trailParticle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        trailParticle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)})
        trailParticle.Lifetime = NumberRange.new(0.5, 1)
        trailParticle.Rate = 40
        trailParticle.Speed = NumberRange.new(0, 2)
        trailParticle.SpreadAngle = Vector2.new(360, 360)
        trailParticle.Parent = cloneRoot
    end

    local index = 0
    local duration = SANDEVISTAN_DURATION / #colorSequence

    task.spawn(function()
        while clone and clone.Parent and isActive do
            index = index % #colorSequence + 1
            local novaCor = colorSequence[index]

            local okTween = pcall(function()
                TweenService:Create(highlight, TweenInfo.new(duration), {
                    FillColor = novaCor,
                    OutlineColor = novaCor
                }):Play()
            end)
            if not okTween then break end

            task.wait(duration)
            if not (clone and clone.Parent and isActive) then break end

            for _, obj in ipairs(clone:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.Color = novaCor
                end
            end
        end
    end)

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
        TweenService:Create(colorCorrection, TweenInfo.new(0.4), effectColors[active and "Active" or "Inactive"]):Play()
    end)

    if active then
        pcall(function()
            TweenService:Create(bloomEffect, TweenInfo.new(0.5), {Intensity = 1.2, Threshold = 1.2}):Play()
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
end

local function deactivateLagSwitch()
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
-- ✨ UI UPDATE
--=============================================================
local function atualizarBotaoUI()
    if not (screenGui and screenGui.Parent) then return end
    if not (toggleLbl and toggleLbl.Parent) then return end

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

--=============================================================
-- ✨ ARCHIVABLE
--=============================================================
local function captureOriginalArchivable()
    if archivableCaptured then return end
    if character then
        originalArchivable = character.Archivable
        archivableCaptured = true
    end
end

local function restoreArchivable()
    if not archivableCaptured then return end
    if character then
        pcall(function() character.Archivable = originalArchivable end)
    end
end

--=============================================================
-- ✨ ACTIVATE / DEACTIVATE
--=============================================================
local activate, deactivate

activate = function()
    if not running then return false end
    if isActive or isDeactivating then return false end
    if not character or not character.Parent then
        warn("[Sandevistan] Personagem não disponível.")
        return false
    end
    if not humanoid or not humanoid.Parent then
        warn("[Sandevistan] Humanoid não disponível.")
        return false
    end

    isActive = true
    captureOriginalArchivable()

    local ok, err = xpcall(function()
        pcall(function() character.Archivable = true end)
        pcall(function() humanoid.WalkSpeed = BOOSTED_SPEED end)

        setVisuals(true)

        if soundReady then
            pcall(function() sound:Play() end)
        end

        activateLagSwitch()
        attachMainParticles()

        task.spawn(function()
            flashScreen()
            cameraShake(0.25, 0.2)
        end)

        startCloneSpawning()
        atualizarBotaoUI()

        deactivateToken = deactivateToken + 1
        local myToken = deactivateToken
        task.delay(SANDEVISTAN_DURATION, function()
            if myToken ~= deactivateToken then return end
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
        setVisuals(false)
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
        task.wait(CLONE_INTERVAL * 1.5)

        pcall(cleanupClones)
        removeMainParticles()

        if humanoid and humanoid.Parent then
            pcall(function() humanoid.WalkSpeed = NORMAL_SPEED end)
        end

        setVisuals(false)
        deactivateLagSwitch()

        restoreArchivable()

        if sound then
            pcall(function() sound:Stop() end)
        end

        task.spawn(function() cameraShake(0.2, 0.15) end)
        atualizarBotaoUI()
    end, function(e) return e end)

    if not ok then
        warn("[Sandevistan] deactivate falhou: " .. tostring(err))
        pcall(function() stopCloneSpawning() end)
        pcall(function() cleanupClones() end)
        pcall(function() removeMainParticles() end)
        pcall(function() deactivateLagSwitch() end)
        setVisuals(false)
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
    if isDeactivating then return end
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

local function bindCharacter(char)
    local newHum = char:WaitForChild("Humanoid", 10)

    character = char
    humanoid = newHum

    if not humanoid then
        warn("[Sandevistan] Humanoid não encontrado.")
    end

    if not normalSpeedCaptured and humanoid then
        normalSpeedCaptured = true
        NORMAL_SPEED = humanoid.WalkSpeed
    end

    if isActive then
        task.spawn(function()
            char:WaitForChild("HumanoidRootPart", 5)
            if not isActive then return end
            if character ~= char or not char.Parent then return end

            local hum2 = humanoid
            if not hum2 or not hum2.Parent then
                hum2 = char:WaitForChild("Humanoid", 5)
            end
            if not isActive then return end
            if character ~= char or not char.Parent then return end

            if hum2 and hum2.Parent then
                pcall(function() hum2.WalkSpeed = BOOSTED_SPEED end)
            end
            pcall(function() char.Archivable = true end)
            attachMainParticles()
            activateLagSwitch()
        end)
    end

    task.spawn(function()
        task.wait(0.5)
        if not character or not character.Parent then return end
        local ok = tryMorph()
        if ok then
            print("[Sandevistan] Morph aplicado: " .. MORPH_USERNAME)
        else
            warn("[Sandevistan] Falha ao aplicar morph")
        end
    end)
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

    if humanoid and humanoid.Parent then
        pcall(function() humanoid.WalkSpeed = NORMAL_SPEED end)
        pcall(function() humanoid.CameraOffset = Vector3.zero end)
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

    if currentShakeConnection then
        pcall(function() currentShakeConnection:Disconnect() end)
        currentShakeConnection = nil
    end

    if flashGui and flashGui.Parent then pcall(function() flashGui:Destroy() end) end
    flashGui = nil

    if screenGui and screenGui.Parent then pcall(function() screenGui:Destroy() end) end
    if colorCorrection and colorCorrection.Parent then pcall(function() colorCorrection:Destroy() end) end
    if bloomEffect and bloomEffect.Parent then pcall(function() bloomEffect:Destroy() end) end
    if sound and sound.Parent then pcall(function() sound:Destroy() end) end

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
print("✨ SANDEVISTAN v4.1 — EDGERUNNERS EDITION")
print("[Sandevistan] F ou clique: liga/desliga")
print("[Sandevistan] Duração: 3.5s | Velocidade: 40")