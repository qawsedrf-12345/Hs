--=============================================================
-- SANDEVISTAN v2 — Toggle real: ativa/desativa no clique
-- Tecla: F | Duração: 3.5s | Vel: 38 | Pulo: Normal
-- Clique/tecla OFF → flash preto + delete clones + som off
-- ✅ Outros jogadores se movem normalmente (freeze removido)
--=============================================================

--=============================================================
-- ⚡ SERVICES
--=============================================================
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

--=============================================================
-- ⚡ CLEANUP ANTERIOR
--=============================================================
if getgenv and getgenv().SandevistanCleanup then
    pcall(getgenv().SandevistanCleanup)
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

    if not GUI_PARENT then return end
end

--=============================================================
-- ⚡ SETTINGS
--=============================================================
local TOGGLE_KEY = Enum.KeyCode.F
local NORMAL_SPEED = 16
local BOOSTED_SPEED = 38
local SANDEVISTAN_DURATION = 3.5
local CLONE_INTERVAL = 0.15
local MAX_CLONES = 25
local MORPH_USERNAME = "ZiemekaTheSequel"

--=============================================================
-- ⚡ STATE
--=============================================================
local isActive = false
local isDeactivating = false
local flashGui = nil
local currentShakeConnection = nil
local deactivateCoroutine = nil
local character, humanoid
local cloneSpawning = false
local cloneTask = nil
local activeSeat = nil
local activeWeld = nil
local frozenStates = {}
local activeClones = {}
local connections = {}
local morphUserId = nil

--=============================================================
-- 🎨 PALETA — CIANO, VERDE, LAVANDA
--=============================================================
local COR_CIANO    = Color3.fromRGB(0, 240, 255)
local COR_VERDE    = Color3.fromRGB(75, 255, 33)
local COR_LAVANDA  = Color3.fromRGB(244, 213, 253)

--=============================================================
-- ⚡ TIME SPEED
--=============================================================
local timeSpeed = Instance.new("NumberValue")
timeSpeed.Name = "TimeSpeed"
timeSpeed.Value = 1
timeSpeed.Parent = Workspace

--=============================================================
-- 🎨 COLOR CORRECTION
--=============================================================
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "SandevistanEffect"
colorCorrection.Parent = Lighting

--=============================================================
-- 🔊 SOM
--=============================================================
local sound = Instance.new("Sound")
sound.Name = "SandevistanSound"
sound.SoundId = "rbxassetid://130840290979991"
sound.Volume = 1
sound.Looped = false
sound.Parent = Workspace

--=============================================================
-- 🎨 SEQUÊNCIA DE CORES
--=============================================================
local colorSequence = {
    COR_CIANO,
    COR_VERDE,
    COR_LAVANDA
}

local effectColors = {
    Active = { Contrast = 0.5, Saturation = 0.25, TintColor = Color3.fromRGB(85, 255, 127) },
    Inactive = { Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }
}

--=============================================================
-- ✨ MORPH — ZiemekaTheSequel
--=============================================================
local function morphIntoUser(targetUserId)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not char or not hum or not targetUserId then
        return false
    end

    local modelSuccess, generatedModel = pcall(function()
        local desc = Players:GetHumanoidDescriptionFromUserId(targetUserId)
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
    end)

    if not (modelSuccess and generatedModel) then
        return false
    end

    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") or item:IsA("CharacterMesh") then
            item:Destroy()
        end
    end

    for _, targetItem in ipairs(generatedModel:GetChildren()) do
        local existingPart = char:FindFirstChild(targetItem.Name)
        if existingPart and existingPart:IsA("BasePart") and existingPart.Name ~= "HumanoidRootPart" then
            existingPart.Color = targetItem.Color
        end
    end

    local targetHead = generatedModel:FindFirstChild("Head")
    local currentHead = char:FindFirstChild("Head")
    if targetHead and currentHead then
        local oldFace = currentHead:FindFirstChildOfClass("Decal")
        if oldFace then oldFace:Destroy() end

        local newFace = targetHead:FindFirstChildOfClass("Decal")
        if newFace then
            newFace:Clone().Parent = currentHead
        else
            local defaultFace = Instance.new("Decal")
            defaultFace.Name = "face"
            defaultFace.Texture = "rbxasset://textures/face.png"
            defaultFace.Parent = currentHead
        end

        local oldMesh = currentHead:FindFirstChildOfClass("SpecialMesh")
        if oldMesh then oldMesh:Destroy() end

        local newMesh = targetHead:FindFirstChildOfClass("SpecialMesh")
        if newMesh then
            newMesh:Clone().Parent = currentHead
        end
    end

    for _, item in ipairs(generatedModel:GetChildren()) do
        if item:IsA("Clothing") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") or item:IsA("CharacterMesh") then
            item:Clone().Parent = char
        elseif item:IsA("Accessory") then
            local clonedAccessory = item:Clone()
            local handle = clonedAccessory:FindFirstChild("Handle")
            if handle then
                local attachment = handle:FindFirstChildOfClass("Attachment")
                if attachment then
                    local targetAttachment = char:FindFirstChild(attachment.Name, true)
                    if targetAttachment then
                        handle.CFrame = targetAttachment.WorldCFrame
                        local weld = Instance.new("Weld")
                        weld.Name = "AccessoryWeld"
                        weld.Part0 = handle
                        weld.Part1 = targetAttachment.Parent
                        weld.C0 = attachment.CFrame
                        weld.C1 = targetAttachment.CFrame
                        weld.Parent = handle
                    end
                end
            end
            clonedAccessory.Parent = char
        end
    end

    generatedModel:Destroy()
    return true
end

local function tryMorph()
    if not morphUserId then
        local ok, result = pcall(function()
            return Players:GetUserIdFromNameAsync(MORPH_USERNAME)
        end)
        if ok and result then
            morphUserId = result
        else
            return false
        end
    end
    return morphIntoUser(morphUserId)
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

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 120, 0, 140)
mainFrame.Position = UDim2.new(0, 20, 0.35, -70)
mainFrame.BackgroundColor3 = COR_CIANO
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
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

local function fazerCanto(posX, posY, offX, offY)
    local cH = Instance.new("Frame")
    cH.Size = UDim2.new(0, 10, 0, 2)
    cH.Position = UDim2.new(posX.Scale, posX.Offset + offX, posY.Scale, posY.Offset)
    cH.BackgroundColor3 = COR_CIANO
    cH.BorderSizePixel = 0
    cH.ZIndex = 5
    cH.Parent = mainFrame
    local cHc = Instance.new("UICorner")
    cHc.CornerRadius = UDim.new(1, 0)
    cHc.Parent = cH

    local cV = Instance.new("Frame")
    cV.Size = UDim2.new(0, 2, 0, 10)
    cV.Position = UDim2.new(posX.Scale, posX.Offset, posY.Scale, posY.Offset + offY)
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
    while liveDot and liveDot.Parent do
        liveDot.BackgroundTransparency = 0
        liveDotStroke.Transparency = 0.1
        pcall(function()
            TweenService:Create(liveDot, TweenInfo.new(0.3), {Size = UDim2.new(0, 8, 0, 8)}):Play()
        end)
        task.wait(0.8)
        if not (liveDot and liveDot.Parent) then break end
        liveDot.BackgroundTransparency = 0.7
        liveDotStroke.Transparency = 0.8
        pcall(function()
            TweenService:Create(liveDot, TweenInfo.new(0.3), {Size = UDim2.new(0, 4, 0, 4)}):Play()
        end)
        task.wait(0.8)
    end
end)

--=============================================================
-- ✨ BOTÃO TOGGLE
--=============================================================
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

--=============================================================
-- 🔁 BOTÃO REJOIN
--=============================================================
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

rejoinBtn.MouseEnter:Connect(function()
    pcall(function()
        TweenService:Create(rejoinHoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
    end)
    rejoinBtn.BackgroundColor3 = COR_VERDE
    rejoinStroke.Color = COR_CIANO
    rejoinStroke.Transparency = 0.1
    rejoinLbl.TextColor3 = COR_LAVANDA
end)

rejoinBtn.MouseLeave:Connect(function()
    pcall(function()
        TweenService:Create(rejoinHoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Scale = 1}):Play()
    end)
    rejoinBtn.BackgroundColor3 = COR_LAVANDA
    rejoinBtn.BackgroundTransparency = 0.2
    rejoinStroke.Color = COR_CIANO
    rejoinStroke.Transparency = 0.2
    rejoinLbl.TextColor3 = COR_CIANO
end)

rejoinBtn.MouseButton1Click:Connect(function()
    rejoinLbl.Text = "🔁 REJOIN..."
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end)
end)

--=============================================================
-- ✨ FOOTER
--=============================================================
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

toggleBtn.MouseEnter:Connect(function()
    if not isActive then
        pcall(function()
            TweenService:Create(hoverScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
        end)
        toggleBtn.BackgroundColor3 = COR_VERDE
        toggleStroke.Color = COR_CIANO
        toggleStroke.Transparency = 0.1
        toggleLbl.TextColor3 = COR_CIANO
    end
end)

toggleBtn.MouseLeave:Connect(function()
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
end)

--=============================================================
-- ✨ FLASH BRANCO (ativação)
--=============================================================
local function flashScreen()
    if flashGui and flashGui.Parent then
        flashGui:Destroy()
    end

    flashGui = Instance.new("ScreenGui")
    flashGui.Name = "SandevistanFlashGui"
    flashGui.IgnoreGuiInset = true
    flashGui.ResetOnSpawn = false
    flashGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    flashGui.Parent = player:WaitForChild("PlayerGui")

    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.Position = UDim2.new(0, 0, 0, 0)
    flash.BackgroundColor3 = COR_CIANO
    flash.BorderSizePixel = 0
    flash.BackgroundTransparency = 1
    flash.ZIndex = 999
    flash.Parent = flashGui

    local tweenIn = TweenService:Create(flash, TweenInfo.new(0.05), { BackgroundTransparency = 0 })
    tweenIn:Play()
    tweenIn.Completed:Wait()

    local tweenOut = TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
    tweenOut:Play()
    tweenOut.Completed:Wait()

    if flashGui then
        flashGui:Destroy()
        flashGui = nil
    end
end

--=============================================================
-- ✨ FLASH PRETO (desativação)
--=============================================================
local function blackFlash()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SandevistanBlackFlash"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.Parent = player:WaitForChild("PlayerGui")

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
    tweenIn.Completed:Wait()

    task.wait(0.1)

    local tweenOut = TweenService:Create(flash, TweenInfo.new(0.15), { BackgroundTransparency = 1 })
    tweenOut:Play()
    tweenOut.Completed:Wait()

    gui:Destroy()
end

--=============================================================
-- ✨ CAMERA SHAKE
--=============================================================
local function cameraShake(duration, magnitude)
    if currentShakeConnection then
        currentShakeConnection:Disconnect()
    end
    local startTime = tick()
    currentShakeConnection = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed > duration then
            currentShakeConnection:Disconnect()
            currentShakeConnection = nil
            return
        end
        local offset = CFrame.new(
            (math.random() - 0.5) * 2 * magnitude,
            (math.random() - 0.5) * 2 * magnitude,
            (math.random() - 0.5) * 2 * magnitude
        )
        camera.CFrame = camera.CFrame * offset
    end)
end

--=============================================================
-- ✨ CLONE
--=============================================================
local function createClone()
    if not isActive then return end
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    if #activeClones >= MAX_CLONES then return end

    character.Archivable = true
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local clone = character:Clone()
    clone.Name = "SandevistanClone"
    clone.Parent = workspace
    clone:SetPrimaryPartCFrame(root.CFrame * CFrame.new(0, 1.5, 0))

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
            obj:Destroy()
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

    local index = 1
    local duration = SANDEVISTAN_DURATION / #colorSequence

    task.spawn(function()
        while clone and clone.Parent and isActive do
            index = index % #colorSequence + 1
            local novaCor = colorSequence[index]

            local tweenHL = TweenService:Create(highlight, TweenInfo.new(duration), {
                FillColor = novaCor,
                OutlineColor = novaCor
            })
            tweenHL:Play()

            for _, obj in ipairs(clone:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.Color = novaCor
                end
            end

            tweenHL.Completed:Wait()
            if not (clone and clone.Parent and isActive) then break end
        end
    end)

    table.insert(activeClones, { clone = clone, highlight = highlight })
end

--=============================================================
-- ✨ CLEANUP — limpa lista + varre órfãos
--=============================================================
local function cleanupClones()
    local copia = activeClones
    activeClones = {}

    for _, data in ipairs(copia) do
        local clone = data.clone
        if clone and clone.Parent then
            clone:Destroy()
        end
    end

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "SandevistanClone" then
            pcall(function() obj:Destroy() end)
        end
    end
end

--=============================================================
-- ✨ CLONE SPAWNER
--=============================================================
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
-- ✨ VISUAL / TIME
--=============================================================
local function setVisuals(active)
    pcall(function()
        TweenService:Create(colorCorrection, TweenInfo.new(0.4), effectColors[active and "Active" or "Inactive"]):Play()
    end)
end

local function setTimeScale(scale)
    pcall(function()
        TweenService:Create(timeSpeed, TweenInfo.new(0.4), { Value = scale }):Play()
    end)
end

--=============================================================
-- ✨ FREEZE OUTROS — DESATIVADO
-- Outros jogadores continuam se movendo normalmente.
-- A função foi mantida vazia para compatibilidade com o resto do script.
--=============================================================
local function freezeOthers(freeze)
    -- Não faz nada intencionalmente.
end

--=============================================================
-- ✨ LAG SWITCH
--=============================================================
local function activateLagSwitch()
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if not hrp or not torso then return end

    local seat = Instance.new("Seat")
    seat.Name = "invischair"
    seat.Transparency = 1
    seat.Anchored = false
    seat.CanCollide = false
    seat.Size = Vector3.new(2, 1, 2)
    seat.CFrame = hrp.CFrame
    seat.Parent = workspace
    activeSeat = seat

    local weld = Instance.new("Weld")
    weld.Part0 = seat
    weld.Part1 = torso
    weld.C0 = CFrame.new()
    weld.C1 = CFrame.new()
    weld.Parent = seat
    activeWeld = weld

    task.wait()
    pcall(function()
        seat.AssemblyAngularVelocity = Vector3.zero
        seat.AssemblyLinearVelocity = Vector3.zero
        seat.CFrame = hrp.CFrame
    end)
end

local function deactivateLagSwitch()
    if activeWeld then
        activeWeld:Destroy()
        activeWeld = nil
    end
    if activeSeat then
        activeSeat:Destroy()
        activeSeat = nil
    end
end

--=============================================================
-- ✨ UI ATUALIZAR
--=============================================================
local function atualizarBotaoUI()
    if isActive then
        toggleLbl.Text = "⚡ SANDEVISTAN [ON]"
        toggleLbl.TextColor3 = COR_LAVANDA
        toggleBtn.BackgroundColor3 = COR_VERDE
        toggleBtn.BackgroundTransparency = 0
        toggleStroke.Color = COR_CIANO
        toggleStroke.Transparency = 0.1
        toggleAccent.BackgroundColor3 = COR_CIANO
        liveDot.BackgroundColor3 = COR_VERDE
        toggleBtn.Active = true
    else
        toggleLbl.Text = "⚡ SANDEVISTAN [OFF]"
        toggleLbl.TextColor3 = COR_CIANO
        toggleBtn.BackgroundColor3 = COR_CIANO
        toggleBtn.BackgroundTransparency = 0.2
        toggleStroke.Color = COR_CIANO
        toggleStroke.Transparency = 0.2
        toggleAccent.BackgroundColor3 = COR_CIANO
        liveDot.BackgroundColor3 = COR_CIANO
        toggleBtn.Active = true
    end
end

--=============================================================
-- ✨ FORWARD DECL
--=============================================================
local activate, deactivate

--=============================================================
-- ✨ ATIVAR
--=============================================================
activate = function()
    if isActive or isDeactivating then return end
    if not character or not humanoid then return end

    isActive = true

    humanoid.WalkSpeed = BOOSTED_SPEED

    setVisuals(true)
    setTimeScale(0.1)
    -- freezeOthers(true) — REMOVIDO: outros players se movem normalmente

    pcall(function()
        sound:Play()
    end)

    activateLagSwitch()

    task.spawn(function()
        flashScreen()
        cameraShake(0.25, 0.2)
    end)

    startCloneSpawning()

    atualizarBotaoUI()

    if deactivateCoroutine and coroutine.status(deactivateCoroutine) == "suspended" then
        pcall(function() coroutine.close(deactivateCoroutine) end)
    end

    -- ⏱ Timer automático de 3.5s → desativa sozinho
    deactivateCoroutine = coroutine.create(function()
        task.wait(SANDEVISTAN_DURATION)
        if isActive then
            deactivate()
        end
    end)
    coroutine.resume(deactivateCoroutine)
end

--=============================================================
-- ✨ DESATIVAR — flash preto + delete clones + som off + visual off
--=============================================================
deactivate = function()
    if not isActive or isDeactivating then return end
    isDeactivating = true
    isActive = false

    -- 🖤 Flash preto imediato
    task.spawn(blackFlash)

    -- ✅ Para spawner
    stopCloneSpawning()

    -- ✅ Espera o task terminar
    task.wait(CLONE_INTERVAL * 1.5)

    -- ✅ Delete instantâneo dos clones
    pcall(cleanupClones)

    -- ✅ Restaura velocidade
    if character and humanoid and humanoid.Parent then
        pcall(function()
            humanoid.WalkSpeed = NORMAL_SPEED
        end)
    end

    -- ✅ Remove visual verde + time scale
    setVisuals(false)
    setTimeScale(1)
    -- freezeOthers(false) — REMOVIDO: outros players se movem normalmente
    deactivateLagSwitch()

    -- ✅ Para o áudio imediatamente
    if sound then
        pcall(function()
            sound:Stop()
            sound.Volume = 1
        end)
    end

    -- ✅ Flash + shake levinho no fim
    task.spawn(function()
        cameraShake(0.2, 0.15)
    end)

    atualizarBotaoUI()

    -- ✅ Encerra o coroutine de auto-deactivate se ainda existir
    if deactivateCoroutine and coroutine.status(deactivateCoroutine) == "suspended" then
        pcall(function() coroutine.close(deactivateCoroutine) end)
        deactivateCoroutine = nil
    end

    isDeactivating = false
end

--=============================================================
-- ✨ TOGGLE — ativa se OFF, desativa se ON
--=============================================================
local function toggleSandevistan()
    if isDeactivating then return end
    if isActive then
        deactivate()
    else
        activate()
    end
end

--=============================================================
-- ✨ HANDLERS
--=============================================================
toggleBtn.MouseButton1Click:Connect(function()
    toggleSandevistan()
end)

local function bindCharacter(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    NORMAL_SPEED = humanoid.WalkSpeed

    task.spawn(function()
        task.wait(0.5)
        local ok = tryMorph()
        if ok then
            print("[Sandevistan] Morph reaplicado: " .. MORPH_USERNAME)
        else
            warn("[Sandevistan] Falha ao reaplicar morph em " .. MORPH_USERNAME)
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
-- ✨ PROTEÇÃO CONTRA ÓRFÃOS (roda a cada 5s)
--=============================================================
task.spawn(function()
    while true do
        task.wait(5)
        if not isActive then
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name == "SandevistanClone" then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end
end)

--=============================================================
-- ✨ CLEANUP GLOBAL
--=============================================================
local function fullCleanup()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)

    stopCloneSpawning()
    pcall(cleanupClones)
    pcall(deactivateLagSwitch)

    if flashGui and flashGui.Parent then flashGui:Destroy() end
    if screenGui and screenGui.Parent then screenGui:Destroy() end
    if colorCorrection and colorCorrection.Parent then colorCorrection:Destroy() end
    if sound and sound.Parent then sound:Destroy() end
    if timeSpeed and timeSpeed.Parent then timeSpeed:Destroy() end

    -- frozenStates não é mais usado, mas mantemos por segurança
    for part, original in pairs(frozenStates) do
        if part and part.Parent then
            pcall(function() part.Anchored = original end)
        end
    end
    table.clear(frozenStates)

    if getgenv then getgenv().SandevistanCleanup = nil end
end

if getgenv then getgenv().SandevistanCleanup = fullCleanup end

print("✨ SANDEVISTAN v2 — Toggle real + flash preto ao desativar")
print("[Sandevistan] F ou clique: liga/desliga")
print("[Sandevistan] Duração automática: 3.5s | Velocidade: 38")
print("[Sandevistan] Ao desativar: flash preto + delete clones + som off + visual off")
print("[Sandevistan] ✅ Outros jogadores se movem normalmente")