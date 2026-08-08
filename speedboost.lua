--[[
    UNIVERSAL ESP - Sailor Piece Style UI
    Highlight-based player detection + Speed Boost + Air Jump + FPS Counter
    Clean tabbed UI with minimize to text - NO external dependencies
]]

repeat wait() until game:IsLoaded() and game.Players and game.Players.LocalPlayer and game.Players.LocalPlayer.Character

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Camera = game:GetService("Workspace").CurrentCamera
local Teams = game:GetService("Teams")

-- Detect platform
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- =============================================
-- CONFIGURATION
-- =============================================
local Config = {
    Speed = 100,
    JumpPower = 80,
    MaxAirJumps = 5,
    ESPEnabled = true,
    MaxESPDistance = 2000
}

-- Toggle Settings
local Settings = {
    Minimized = false,
    ESPEnabled = true
}

local ScriptActive = true
local airJumpsLeft = 0
local isGrounded = false
local ESPObjects = {}
local espConnections = {}

-- FPS Tracking
local fpsCount, fps, lastFPSUpdate = 0, 0, tick()

-- Bounty
local CurrentBounty = "Searching..."

-- Clean up
if getgenv().UniversalESP_Loaded then
    getgenv().UniversalESP_Loaded = false
    if game.CoreGui:FindFirstChild("UniversalESP_GUI") then
        game.CoreGui.UniversalESP_GUI:Destroy()
    end
    if game.CoreGui:FindFirstChild("ESP_MinimizeText") then
        game.CoreGui.ESP_MinimizeText:Destroy()
    end
end
getgenv().UniversalESP_Loaded = true

-- =============================================
-- TERMINATE FUNCTION
-- =============================================
local function terminateScript()
    ScriptActive = false
    Settings.ESPEnabled = false
    
    pcall(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = 16
            char.Humanoid.JumpPower = 50
        end
    end)
    
    if GUI then GUI:Destroy() end
    if game.CoreGui:FindFirstChild("ESP_MinimizeText") then
        game.CoreGui.ESP_MinimizeText:Destroy()
    end
    
    for _, esp in pairs(ESPObjects) do
        if esp and esp.Billboard then esp.Billboard:Destroy() end
        if esp and esp.Highlight then esp.Highlight:Destroy() end
    end
    ESPObjects = {}
    
    for _, conn in pairs(espConnections) do
        conn:Disconnect()
    end
    espConnections = {}
    
    print("✓ ESP Terminated")
end

-- =============================================
-- FPS COUNTER
-- =============================================
local function getFPS()
    local fps = Stats:FindFirstChild("PerformanceStats")
    if fps then
        local f = fps:FindFirstChild("FPS")
        if f then return math.floor(f.Value) end
    end
    return 0
end

-- =============================================
-- GET TEAM COLOR
-- =============================================
local function getTeamColor(player)
    if player.Team then
        return player.Team.TeamColor.Color
    end
    return Color3.fromRGB(0, 150, 255)
end

-- =============================================
-- BOUNTY SCANNER
-- =============================================
local function scanBounty()
    local bounty = nil
    
    pcall(function()
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats") or LocalPlayer:FindFirstChild("stats") or LocalPlayer:FindFirstChild("Data")
        if leaderstats then
            for _, stat in pairs(leaderstats:GetChildren()) do
                local name = string.lower(stat.Name)
                if string.find(name, "bounty") or string.find(name, "beli") then
                    if stat:IsA("IntValue") or stat:IsA("NumberValue") then
                        bounty = tostring(stat.Value)
                        break
                    elseif stat:IsA("StringValue") then
                        bounty = stat.Value
                        break
                    end
                end
            end
        end
        
        if not bounty then
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui then
                for _, child in pairs(playerGui:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        local text = child.Text or ""
                        local textLower = string.lower(text)
                        if string.find(textLower, "bounty") then
                            local number = string.match(text, "[%d,]+")
                            if number then
                                bounty = number
                                break
                            else
                                local clean = text:gsub("Bounty", ""):gsub("bounty", ""):gsub("%s*:%s*", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                                if clean ~= "" then
                                    bounty = clean
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return bounty
end

-- =============================================
-- GUI CREATION (IDENTICAL TO SAILOR PIECE)
-- =============================================
local GUI = Instance.new("ScreenGui")
GUI.Name = "UniversalESP_GUI"
GUI.ResetOnSpawn = false
GUI.Parent = game.CoreGui
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Adjust size for mobile
local mainWidth = 500
local mainHeight = 450
if isMobile then
    mainWidth = 380
    mainHeight = 370
end

-- Main Container
local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.Size = UDim2.new(0, mainWidth, 0, mainHeight)
Main.Position = isMobile and UDim2.new(0.5, -mainWidth/2, 0.5, -mainHeight/2) or UDim2.new(0.5, -250, 0.5, -225)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = GUI

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = Main

-- Minimize Text Button
local MinimizeText = Instance.new("TextButton")
MinimizeText.Name = "ESP_MinimizeText"
MinimizeText.Size = UDim2.new(0, isMobile and 200 or 180, 0, isMobile and 50 or 40)
MinimizeText.Position = UDim2.new(0, 10, 0, isMobile and 140 or 80)
MinimizeText.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MinimizeText.BorderSizePixel = 0
MinimizeText.TextColor3 = Color3.fromRGB(0, 200, 255)
MinimizeText.Text = "👁️ Universal ESP"
MinimizeText.Font = Enum.Font.GothamBold
MinimizeText.TextSize = isMobile and 16 or 14
MinimizeText.AutoButtonColor = false
MinimizeText.Visible = false
MinimizeText.Active = true
MinimizeText.ZIndex = 10
MinimizeText.Parent = GUI

local TextCorner = Instance.new("UICorner")
TextCorner.CornerRadius = UDim.new(0, 8)
TextCorner.Parent = MinimizeText

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, isMobile and 36 or 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

-- FPS
local FPSDisplay = Instance.new("TextLabel")
FPSDisplay.Size = UDim2.new(0, 55, 1, 0)
FPSDisplay.Position = UDim2.new(0, 8, 0, 0)
FPSDisplay.BackgroundTransparency = 1
FPSDisplay.TextColor3 = Color3.fromRGB(0, 255, 100)
FPSDisplay.Text = "FPS: --"
FPSDisplay.TextXAlignment = Enum.TextXAlignment.Left
FPSDisplay.Font = Enum.Font.GothamBold
FPSDisplay.TextSize = isMobile and 11 or 10
FPSDisplay.Parent = TitleBar

-- Ping
local PingDisplay = Instance.new("TextLabel")
PingDisplay.Size = UDim2.new(0, 65, 1, 0)
PingDisplay.Position = UDim2.new(0, 60, 0, 0)
PingDisplay.BackgroundTransparency = 1
PingDisplay.TextColor3 = Color3.fromRGB(100, 200, 255)
PingDisplay.Text = "Ping: --"
PingDisplay.TextXAlignment = Enum.TextXAlignment.Left
PingDisplay.Font = Enum.Font.GothamBold
PingDisplay.TextSize = isMobile and 11 or 10
PingDisplay.Parent = TitleBar

-- Player Count
local PlayerCountDisplay = Instance.new("TextLabel")
PlayerCountDisplay.Size = UDim2.new(0, 65, 1, 0)
PlayerCountDisplay.Position = UDim2.new(0, 128, 0, 0)
PlayerCountDisplay.BackgroundTransparency = 1
PlayerCountDisplay.TextColor3 = Color3.fromRGB(100, 255, 100)
PlayerCountDisplay.Text = "👤 0"
PlayerCountDisplay.TextXAlignment = Enum.TextXAlignment.Left
PlayerCountDisplay.Font = Enum.Font.GothamBold
PlayerCountDisplay.TextSize = isMobile and 11 or 10
PlayerCountDisplay.Parent = TitleBar

-- Title
local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -290, 1, 0)
TitleText.Position = UDim2.new(0, isMobile and 200 or 210, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.TextColor3 = Color3.fromRGB(180, 180, 180)
TitleText.Text = "Universal ESP"
TitleText.TextXAlignment = Enum.TextXAlignment.Right
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = isMobile and 12 or 11
TitleText.Parent = TitleBar

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, isMobile and 32 or 28, 0, isMobile and 32 or 28)
MinBtn.Position = UDim2.new(1, isMobile and -38 or -33, 0, isMobile and 2 or 2)
MinBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MinBtn.BorderSizePixel = 0
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = isMobile and 16 or 14
MinBtn.AutoButtonColor = false
MinBtn.Active = true
MinBtn.ZIndex = 10
MinBtn.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 4)
MinCorner.Parent = MinBtn

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, isMobile and 32 or 28, 0, isMobile and 32 or 28)
CloseBtn.Position = UDim2.new(1, isMobile and -8 or -3, 0, isMobile and 2 or 2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
CloseBtn.BorderSizePixel = 0
CloseBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = isMobile and 14 or 12
CloseBtn.AutoButtonColor = false
CloseBtn.Active = true
CloseBtn.ZIndex = 10
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseBtn

CloseBtn.Activated:Connect(terminateScript)

-- Content Container
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, 0, 1, isMobile and -36 or -32)
ContentContainer.Position = UDim2.new(0, 0, 0, isMobile and 36 or 32)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = Main

-- Sidebar
local sidebarWidth = isMobile and 130 or 140
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
Sidebar.Position = UDim2.new(0, 0, 0, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = ContentContainer

local SidebarBorder = Instance.new("Frame")
SidebarBorder.Size = UDim2.new(0, 1, 1, 0)
SidebarBorder.Position = UDim2.new(1, 0, 0, 0)
SidebarBorder.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
SidebarBorder.BorderSizePixel = 0
SidebarBorder.Parent = Sidebar

-- Sidebar Logo
local SidebarLogo = Instance.new("Frame")
SidebarLogo.Size = UDim2.new(1, 0, 0, isMobile and 40 or 45)
SidebarLogo.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
SidebarLogo.BorderSizePixel = 0
SidebarLogo.Parent = Sidebar

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, -20, 0, 20)
LogoText.Position = UDim2.new(0, 10, 0, 5)
LogoText.BackgroundTransparency = 1
LogoText.TextColor3 = Color3.fromRGB(0, 200, 255)
LogoText.Text = "👁️ ESP"
LogoText.TextXAlignment = Enum.TextXAlignment.Left
LogoText.Font = Enum.Font.GothamBold
LogoText.TextSize = isMobile and 12 or 14
LogoText.Parent = SidebarLogo

local LogoSub = Instance.new("TextLabel")
LogoSub.Size = UDim2.new(1, -20, 0, 14)
LogoSub.Position = UDim2.new(0, 10, 0, 26)
LogoSub.BackgroundTransparency = 1
LogoSub.TextColor3 = Color3.fromRGB(120, 120, 120)
LogoSub.Text = "Universal"
LogoSub.TextXAlignment = Enum.TextXAlignment.Left
LogoSub.Font = Enum.Font.Gotham
LogoSub.TextSize = isMobile and 8 or 9
LogoSub.Parent = SidebarLogo

-- Tab System
local TabButtons = {}
local TabPages = {}

local function CreateTab(name, icon, index)
    local btnSize = isMobile and 28 or 32
    local btnFont = isMobile and 10 or 11
    local startY = isMobile and 46 or 52
    local spacing = isMobile and 32 or 36
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, btnSize)
    btn.Position = UDim2.new(0, 10, 0, startY + (index - 1) * spacing)
    btn.BackgroundColor3 = index == 1 and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(23, 23, 23)
    btn.BorderSizePixel = 0
    btn.TextColor3 = index == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
    btn.Text = "  " .. icon .. "  " .. name
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = btnFont
    btn.AutoButtonColor = false
    btn.Active = true
    btn.ZIndex = 10
    btn.Parent = Sidebar
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn
    
    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, -sidebarWidth, 1, 0)
    page.Position = UDim2.new(0, sidebarWidth, 0, 0)
    page.BackgroundTransparency = 1
    page.Visible = (index == 1)
    page.Parent = ContentContainer
    
    btn.Activated:Connect(function()
        for i = 1, #TabButtons do
            TabButtons[i].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
            TabButtons[i].TextColor3 = Color3.fromRGB(150, 150, 150)
            TabPages[i].Visible = false
        end
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        page.Visible = true
    end)
    
    table.insert(TabButtons, btn)
    table.insert(TabPages, page)
    return page
end

-- =============================================
-- UI HELPERS (IDENTICAL TO SAILOR PIECE)
-- =============================================
local function CreateSection(parent, title, yPos)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -30, 0, 20)
    section.Position = UDim2.new(0, 15, 0, yPos)
    section.BackgroundTransparency = 1
    section.Parent = parent
    
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 0, 0)
    line.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    line.BorderSizePixel = 0
    line.Parent = section
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 0, 16)
    text.Position = UDim2.new(0, 0, 0, 3)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(120, 120, 120)
    text.Text = title
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Font = Enum.Font.GothamBold
    text.TextSize = 9
    text.Parent = section
    
    return section
end

local function CreateToggle(parent, title, default, yPos, callback)
    local bgSize = isMobile and 34 or 30
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, -30, 0, bgSize)
    bg.Position = UDim2.new(0, 15, 0, yPos)
    bg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    bg.BorderSizePixel = 0
    bg.Parent = parent
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 4)
    bgCorner.Parent = bg
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, -10, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Text = title
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = isMobile and 10 or 11
    label.Parent = bg
    
    local state = default
    
    local switchSize = isMobile and 40 or 36
    local switchHeight = isMobile and 20 or 18
    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, switchSize, 0, switchHeight)
    switch.Position = UDim2.new(1, isMobile and -52 or -46, 0.5, isMobile and -10 or -9)
    switch.BackgroundColor3 = state and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(50, 50, 50)
    switch.BorderSizePixel = 0
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Active = true
    switch.ZIndex = 10
    switch.Parent = bg
    
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch
    
    local dotSize = isMobile and 16 or 14
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, dotSize, 0, dotSize)
    dot.Position = state and UDim2.new(1, isMobile and -18 or -16, 0.5, isMobile and -8 or -7) or UDim2.new(0, 2, 0.5, isMobile and -8 or -7)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel = 0
    dot.Parent = switch
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot
    
    local function toggleSwitch()
        state = not state
        switch.BackgroundColor3 = state and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(50, 50, 50)
        local targetPos = state and UDim2.new(1, isMobile and -18 or -16, 0.5, isMobile and -8 or -7) or UDim2.new(0, 2, 0.5, isMobile and -8 or -7)
        local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(dot, tweenInfo, {Position = targetPos})
        tween:Play()
        callback(state)
    end
    
    switch.Activated:Connect(toggleSwitch)
    
    return bg
end

local function CreateButton(parent, title, yPos, callback)
    local btnSize = isMobile and 36 or 32
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -30, 0, btnSize)
    btn.Position = UDim2.new(0, 15, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.BorderSizePixel = 0
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = title
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = isMobile and 10 or 11
    btn.AutoButtonColor = false
    btn.Active = true
    btn.ZIndex = 10
    btn.Parent = parent
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn
    
    btn.Activated:Connect(callback)
    
    return btn
end

local function CreateInfoLabel(parent, text, yPos, color)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -30, 0, 18)
    label.Position = UDim2.new(0, 15, 0, yPos)
    label.BackgroundTransparency = 1
    label.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 10
    label.Parent = parent
    return label
end

-- =============================================
-- CREATE TABS
-- =============================================
local ESPPage = CreateTab("ESP", "👁️", 1)
local PlayerPage = CreateTab("Player", "👤", 2)
local SettingsPage = CreateTab("Settings", "⚙️", 3)

-- =============================================
-- ESP TAB
-- =============================================
CreateSection(ESPPage, "ESP CONTROLS", 10)

local ESPStatus = Instance.new("TextLabel")
ESPStatus.Size = UDim2.new(1, -30, 0, 16)
ESPStatus.Position = UDim2.new(0, 15, 0, isMobile and 36 or 34)
ESPStatus.BackgroundTransparency = 1
ESPStatus.TextColor3 = Color3.fromRGB(0, 255, 100)
ESPStatus.Text = "● ESP Active"
ESPStatus.TextXAlignment = Enum.TextXAlignment.Left
ESPStatus.Font = Enum.Font.Gotham
ESPStatus.TextSize = 10
ESPStatus.Parent = ESPPage

CreateToggle(ESPPage, "Enable ESP", true, isMobile and 58 or 54, function(state)
    Config.ESPEnabled = state
    ESPStatus.Text = state and "● ESP Active" or "● ESP Disabled"
    ESPStatus.TextColor3 = state and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
end)

CreateSection(ESPPage, "STATS", isMobile and 100 or 92)

local SpeedDisplay = Instance.new("TextLabel")
SpeedDisplay.Size = UDim2.new(1, -30, 0, 16)
SpeedDisplay.Position = UDim2.new(0, 15, 0, isMobile and 124 or 116)
SpeedDisplay.BackgroundTransparency = 1
SpeedDisplay.TextColor3 = Color3.fromRGB(0, 200, 255)
SpeedDisplay.Text = "⚡ Speed: " .. Config.Speed
SpeedDisplay.TextXAlignment = Enum.TextXAlignment.Left
SpeedDisplay.Font = Enum.Font.GothamBold
SpeedDisplay.TextSize = 10
SpeedDisplay.Parent = ESPPage

local JumpDisplay = Instance.new("TextLabel")
JumpDisplay.Size = UDim2.new(1, -30, 0, 16)
JumpDisplay.Position = UDim2.new(0, 15, 0, isMobile and 146 or 138)
JumpDisplay.BackgroundTransparency = 1
JumpDisplay.TextColor3 = Color3.fromRGB(100, 200, 255)
JumpDisplay.Text = "🦘 Jump: " .. Config.JumpPower .. " | Air: " .. Config.MaxAirJumps
JumpDisplay.TextXAlignment = Enum.TextXAlignment.Left
JumpDisplay.Font = Enum.Font.GothamBold
JumpDisplay.TextSize = 10
JumpDisplay.Parent = ESPPage

local RangeDisplay = Instance.new("TextLabel")
RangeDisplay.Size = UDim2.new(1, -30, 0, 16)
RangeDisplay.Position = UDim2.new(0, 15, 0, isMobile and 168 or 160)
RangeDisplay.BackgroundTransparency = 1
RangeDisplay.TextColor3 = Color3.fromRGB(255, 200, 0)
RangeDisplay.Text = "📏 Range: " .. Config.MaxESPDistance .. "m"
RangeDisplay.TextXAlignment = Enum.TextXAlignment.Left
RangeDisplay.Font = Enum.Font.GothamBold
RangeDisplay.TextSize = 10
RangeDisplay.Parent = ESPPage

-- =============================================
-- PLAYER TAB
-- =============================================
CreateSection(PlayerPage, "PLAYER INFO", 10)

local PlayerNameDisplay = Instance.new("TextLabel")
PlayerNameDisplay.Size = UDim2.new(1, -30, 0, 20)
PlayerNameDisplay.Position = UDim2.new(0, 15, 0, 34)
PlayerNameDisplay.BackgroundTransparency = 1
PlayerNameDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerNameDisplay.Text = "👤 " .. LocalPlayer.Name
PlayerNameDisplay.TextXAlignment = Enum.TextXAlignment.Left
PlayerNameDisplay.Font = Enum.Font.GothamBold
PlayerNameDisplay.TextSize = 12
PlayerNameDisplay.Parent = PlayerPage

local PlayerBounty = Instance.new("Frame")
PlayerBounty.Size = UDim2.new(1, -30, 0, 40)
PlayerBounty.Position = UDim2.new(0, 15, 0, 60)
PlayerBounty.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PlayerBounty.BorderSizePixel = 0
PlayerBounty.Parent = PlayerPage

local PlayerBountyCorner = Instance.new("UICorner")
PlayerBountyCorner.CornerRadius = UDim.new(0, 4)
PlayerBountyCorner.Parent = PlayerBounty

local PlayerBountyLabel = Instance.new("TextLabel")
PlayerBountyLabel.Size = UDim2.new(1, -20, 0, 14)
PlayerBountyLabel.Position = UDim2.new(0, 10, 0, 5)
PlayerBountyLabel.BackgroundTransparency = 1
PlayerBountyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
PlayerBountyLabel.Text = "BOUNTY"
PlayerBountyLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerBountyLabel.Font = Enum.Font.GothamBold
PlayerBountyLabel.TextSize = 8
PlayerBountyLabel.Parent = PlayerBounty

local PlayerBountyValue = Instance.new("TextLabel")
PlayerBountyValue.Size = UDim2.new(1, -20, 0, 18)
PlayerBountyValue.Position = UDim2.new(0, 10, 0, 18)
PlayerBountyValue.BackgroundTransparency = 1
PlayerBountyValue.TextColor3 = Color3.fromRGB(255, 200, 0)
PlayerBountyValue.Text = "Searching..."
PlayerBountyValue.TextXAlignment = Enum.TextXAlignment.Left
PlayerBountyValue.Font = Enum.Font.GothamBold
PlayerBountyValue.TextSize = 13
PlayerBountyValue.Parent = PlayerBounty

CreateSection(PlayerPage, "HEALTH", 112)

local HealthBarBg = Instance.new("Frame")
HealthBarBg.Size = UDim2.new(1, -30, 0, 20)
HealthBarBg.Position = UDim2.new(0, 15, 0, 136)
HealthBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
HealthBarBg.BorderSizePixel = 0
HealthBarBg.Parent = PlayerPage

local HealthBarCorner = Instance.new("UICorner")
HealthBarCorner.CornerRadius = UDim.new(0, 4)
HealthBarCorner.Parent = HealthBarBg

local HealthBar = Instance.new("Frame")
HealthBar.Size = UDim2.new(1, 0, 1, 0)
HealthBar.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
HealthBar.BorderSizePixel = 0
HealthBar.Parent = HealthBarBg

local HealthBarCorner2 = Instance.new("UICorner")
HealthBarCorner2.CornerRadius = UDim.new(0, 4)
HealthBarCorner2.Parent = HealthBar

local HealthText = Instance.new("TextLabel")
HealthText.Size = UDim2.new(1, 0, 1, 0)
HealthText.BackgroundTransparency = 1
HealthText.TextColor3 = Color3.fromRGB(255, 255, 255)
HealthText.Text = "100%"
HealthText.Font = Enum.Font.GothamBold
HealthText.TextSize = 10
HealthText.Parent = HealthBar

CreateSection(PlayerPage, "DETECTED PLAYERS", 168)

local PlayerCountLabel = Instance.new("TextLabel")
PlayerCountLabel.Size = UDim2.new(1, -30, 0, 16)
PlayerCountLabel.Position = UDim2.new(0, 15, 0, 192)
PlayerCountLabel.BackgroundTransparency = 1
PlayerCountLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
PlayerCountLabel.Text = "Players in game: " .. #Players:GetPlayers()
PlayerCountLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerCountLabel.Font = Enum.Font.GothamBold
PlayerCountLabel.TextSize = 10
PlayerCountLabel.Parent = PlayerPage

-- =============================================
-- SETTINGS TAB
-- =============================================
CreateSection(SettingsPage, "PERMANENT STATS", 10)

CreateInfoLabel(SettingsPage, "Walk Speed: " .. Config.Speed, 34, Color3.fromRGB(0, 200, 255))
CreateInfoLabel(SettingsPage, "Jump Power: " .. Config.JumpPower, 54, Color3.fromRGB(100, 200, 255))
CreateInfoLabel(SettingsPage, "Air Jumps: " .. Config.MaxAirJumps, 74, Color3.fromRGB(200, 200, 100))
CreateInfoLabel(SettingsPage, "ESP Range: " .. Config.MaxESPDistance .. "m", 94, Color3.fromRGB(255, 200, 0))

CreateSection(SettingsPage, "CONTROLS", 126)

CreateButton(SettingsPage, "🔄 Toggle ESP", 150, function()
    Config.ESPEnabled = not Config.ESPEnabled
    ESPStatus.Text = Config.ESPEnabled and "● ESP Active" or "● ESP Disabled"
    ESPStatus.TextColor3 = Config.ESPEnabled and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
end)

CreateButton(SettingsPage, "⚠️ TERMINATE SCRIPT", 190, function()
    terminateScript()
end)

-- =============================================
-- MINIMIZE TO TEXT (IDENTICAL TO SAILOR PIECE)
-- =============================================
local function showMain()
    Main.Visible = true
    MinimizeText.Visible = false
    Settings.Minimized = false
end

local function showText()
    Main.Visible = false
    MinimizeText.Visible = true
    Settings.Minimized = true
end

MinBtn.Activated:Connect(showText)
MinimizeText.Activated:Connect(showMain)

-- Text button: tap to restore, drag to move
local textDragging = false
local textDragStart
local textStartPos
local textMoved = false

MinimizeText.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        textDragging = true
        textMoved = false
        textDragStart = input.Position
        textStartPos = MinimizeText.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if textDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - textDragStart
        if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then
            textMoved = true
        end
        MinimizeText.Position = UDim2.new(textStartPos.X.Scale, textStartPos.X.Offset + delta.X, textStartPos.Y.Scale, textStartPos.Y.Offset + delta.Y)
    end
end)

MinimizeText.InputEnded:Connect(function(input)
    if textDragging then
        if not textMoved then
            showMain()
        end
        textDragging = false
    end
end)

-- Main window draggable
local dragActive = false
local dragInput
local dragStart
local startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragActive = true
        dragStart = input.Position
        startPos = Main.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragActive = false
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

RunService.RenderStepped:Connect(function()
    if dragActive and dragInput then
        local delta = dragInput.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- =============================================
-- SPEED & JUMP SYSTEM
-- =============================================
local function applyStats()
    if not ScriptActive then return end
    pcall(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            local h = char.Humanoid
            h.WalkSpeed = Config.Speed
            h.JumpPower = Config.JumpPower
        end
    end)
end

UserInputService.JumpRequest:Connect(function()
    if not ScriptActive then return end
    
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        
        local h = char:FindFirstChild("Humanoid")
        if not h then return end
        
        if h.FloorMaterial ~= Enum.Material.Air then
            airJumpsLeft = Config.MaxAirJumps
            return
        end
        
        if airJumpsLeft > 0 and h.FloorMaterial == Enum.Material.Air then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
            airJumpsLeft = airJumpsLeft - 1
        end
    end)
end)

-- =============================================
-- HIGHLIGHT-BASED ESP SYSTEM
-- =============================================
local function createESP(player)
    if player == LocalPlayer or not ScriptActive then return end
    
    if ESPObjects[player.Name] then
        pcall(function()
            if ESPObjects[player.Name].Billboard then ESPObjects[player.Name].Billboard:Destroy() end
            if ESPObjects[player.Name].Highlight then ESPObjects[player.Name].Highlight:Destroy() end
        end)
        ESPObjects[player.Name] = nil
    end
    
    local function addESP(character)
        if not character then return end
        local h = character:FindFirstChild("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        if not h or not root or not head then return end
        
        local color = getTeamColor(player)
        
        local highlight = Instance.new("Highlight")
        highlight.FillColor = color
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.35
        highlight.OutlineTransparency = 0
        highlight.Enabled = true
        highlight.Parent = character
        
        local billboard = Instance.new("BillboardGui")
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 180, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = true
        billboard.Parent = character
        
        local container = Instance.new("Frame", billboard)
        container.Size = UDim2.new(1, 0, 1, 0)
        container.BackgroundTransparency = 1
        
        local nameL = Instance.new("TextLabel", container)
        nameL.Size = UDim2.new(1, 0, 0, 16)
        nameL.Position = UDim2.new(0, 0, 0, 0)
        nameL.BackgroundTransparency = 1
        nameL.Text = player.Name
        nameL.TextColor3 = color
        nameL.TextSize = 16
        nameL.Font = Enum.Font.GothamBold
        nameL.TextStrokeTransparency = 0
        nameL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameL.TextXAlignment = Enum.TextXAlignment.Center
        
        local healthBg = Instance.new("Frame", container)
        healthBg.Size = UDim2.new(0.9, 0, 0, 8)
        healthBg.Position = UDim2.new(0.05, 0, 0.3, 0)
        healthBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        healthBg.BorderSizePixel = 1
        healthBg.BorderColor3 = Color3.fromRGB(0, 0, 0)
        local c1 = Instance.new("UICorner", healthBg)
        c1.CornerRadius = UDim.new(0, 2)
        
        local healthFill = Instance.new("Frame", healthBg)
        healthFill.Size = UDim2.new(1, 0, 1, 0)
        healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        healthFill.BorderSizePixel = 0
        local c2 = Instance.new("UICorner", healthFill)
        c2.CornerRadius = UDim.new(0, 2)
        
        local distL = Instance.new("TextLabel", container)
        distL.Size = UDim2.new(1, 0, 0, 12)
        distL.Position = UDim2.new(0, 0, 0.6, 0)
        distL.BackgroundTransparency = 1
        distL.Text = "0m"
        distL.TextColor3 = Color3.fromRGB(255, 200, 0)
        distL.TextSize = 11
        distL.Font = Enum.Font.GothamBold
        distL.TextXAlignment = Enum.TextXAlignment.Center
        distL.TextStrokeTransparency = 0.5
        distL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        
        ESPObjects[player.Name] = {
            Billboard = billboard,
            Highlight = highlight,
            HealthFill = healthFill,
            DistLabel = distL
        }
    end
    
    if player.Character then addESP(player.Character) end
    local conn = player.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        addESP(character)
    end)
    table.insert(espConnections, conn)
end

-- =============================================
-- TEAM CHANGE
-- =============================================
local function onTeamChanged(player)
    if player == LocalPlayer then return end
    local esp = ESPObjects[player.Name]
    if esp and esp.Highlight then
        esp.Highlight.FillColor = getTeamColor(player)
    end
end

-- =============================================
-- UPDATE LOOPS
-- =============================================

-- FPS
task.spawn(function()
    while ScriptActive do
        local fps = getFPS()
        FPSDisplay.Text = "FPS: " .. fps
        FPSDisplay.TextColor3 = fps >= 50 and Color3.fromRGB(0, 255, 100) or (fps >= 25 and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 80, 80))
        task.wait(0.5)
    end
end)

-- Ping
task.spawn(function()
    while ScriptActive do
        pcall(function()
            local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
            PingDisplay.Text = "Ping: " .. ping .. "ms"
            PingDisplay.TextColor3 = ping <= 80 and Color3.fromRGB(100, 200, 255) or (ping <= 150 and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 100, 100))
        end)
        task.wait(1)
    end
end)

-- Player count
task.spawn(function()
    while ScriptActive do
        local count = #Players:GetPlayers()
        PlayerCountDisplay.Text = "👤 " .. count
        PlayerCountLabel.Text = "Players in game: " .. count
        task.wait(1)
    end
end)

-- Health
task.spawn(function()
    while ScriptActive do
        pcall(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") then
                local hp = char.Humanoid.Health
                local maxHP = char.Humanoid.MaxHealth
                local percent = hp / maxHP
                HealthBar.Size = UDim2.new(percent, 0, 1, 0)
                HealthText.Text = math.floor(percent * 100) .. "%"
                HealthBar.BackgroundColor3 = percent > 0.5 and Color3.fromRGB(60, 200, 60) or (percent > 0.25 and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 50, 50))
            end
        end)
        task.wait(0.3)
    end
end)

-- Bounty
task.spawn(function()
    while ScriptActive do
        local bounty = scanBounty()
        if bounty then
            CurrentBounty = bounty
            PlayerBountyValue.Text = bounty
        else
            PlayerBountyValue.Text = "Not found"
        end
        task.wait(3)
    end
end)

-- Apply Stats
task.spawn(function()
    while ScriptActive do
        applyStats()
        task.wait(0.3)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    applyStats()
    airJumpsLeft = Config.MaxAirJumps
end)

-- =============================================
-- MAIN ESP UPDATE LOOP
-- =============================================
task.spawn(function()
    while ScriptActive do
        task.wait(0.15)
        pcall(function()
            for name, esp in pairs(ESPObjects) do
                if not esp or not esp.Highlight then continue end
                local p = Players:FindFirstChild(name)
                if not p then
                    if esp.Billboard then esp.Billboard:Destroy() end
                    if esp.Highlight then esp.Highlight:Destroy() end
                    ESPObjects[name] = nil
                    continue
                end
                local char = p.Character
                if not char then
                    if esp.Highlight then esp.Highlight.Enabled = false end
                    if esp.Billboard then esp.Billboard.Enabled = false end
                    continue
                end
                local root = char:FindFirstChild("HumanoidRootPart")
                local h = char:FindFirstChild("Humanoid")
                local head = char:FindFirstChild("Head")
                if not root or not h or not head then
                    if esp.Highlight then esp.Highlight.Enabled = false end
                    if esp.Billboard then esp.Billboard.Enabled = false end
                    continue
                end
                if esp.Billboard then esp.Billboard.Adornee = head end
                if esp.Highlight then esp.Highlight.Parent = char end
                
                local dist = (Camera.CFrame.Position - root.Position).Magnitude
                local inRange = dist <= Config.MaxESPDistance
                
                if inRange and Config.ESPEnabled then
                    if esp.Highlight then esp.Highlight.Enabled = true end
                    if esp.Billboard then esp.Billboard.Enabled = true end
                    local hp = math.clamp(h.Health / h.MaxHealth, 0, 1)
                    if esp.HealthFill then
                        esp.HealthFill.Size = UDim2.new(hp, 0, 1, 0)
                        esp.HealthFill.BackgroundColor3 = hp > 0.5 and Color3.fromRGB(0, 255, 0) or (hp > 0.25 and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0))
                    end
                    if esp.DistLabel and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local d = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - root.Position).Magnitude)
                        esp.DistLabel.Text = d .. "m"
                        esp.DistLabel.TextColor3 = d < 50 and Color3.fromRGB(0, 255, 0) or (d < 150 and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 100, 100))
                    end
                else
                    if esp.Highlight then esp.Highlight.Enabled = false end
                    if esp.Billboard then esp.Billboard.Enabled = false end
                end
            end
        end)
    end
end)

-- =============================================
-- INITIALIZE ESP
-- =============================================
task.wait(1)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        createESP(p)
        p:GetPropertyChangedSignal("Team"):Connect(function() onTeamChanged(p) end)
    end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        task.wait(1)
        createESP(p)
        p:GetPropertyChangedSignal("Team"):Connect(function() onTeamChanged(p) end)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if ESPObjects[p.Name] then
        pcall(function()
            if ESPObjects[p.Name].Billboard then ESPObjects[p.Name].Billboard:Destroy() end
            if ESPObjects[p.Name].Highlight then ESPObjects[p.Name].Highlight:Destroy() end
        end)
        ESPObjects[p.Name] = nil
    end
end)

print("")
print("╔══════════════════════════════════════╗")
print("║     UNIVERSAL ESP - Tabbed UI       ║")
print("╠══════════════════════════════════════╣")
print("║  ⚡ Speed: " .. Config.Speed .. "                      ║")
print("║  🦘 Jump: " .. Config.JumpPower .. " | Air: " .. Config.MaxAirJumps .. "   ║")
print("║  👁️  ESP Active                      ║")
print("║  📏 Range: " .. Config.MaxESPDistance .. "m              ║")
print("╠══════════════════════════════════════╣")
print("║  Zero Dependencies - 100% Standalone║")
print("║  Sailor Piece Style Tabbed UI       ║")
print("║  Click '—' to minimize to text      ║")
print("║  Tap text to restore GUI            ║")
print("║  Click '✕' to terminate             ║")
print("╚══════════════════════════════════════╝")
print("")
