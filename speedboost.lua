--[[
    UNIVERSAL ESP - Modern Dark Purple UI
    Highlight-based player detection + Speed Boost + Air Jump + FPS Counter
    Modern tabbed UI with minimize to text - Dark Purple Theme (#221C35)
]]

-- Check if script is already running and clean up
if getgenv().UniversalESP_Loaded then
    getgenv().UniversalESP_Loaded = false
    pcall(function()
        if game.CoreGui:FindFirstChild("UniversalESP_GUI") then
            game.CoreGui.UniversalESP_GUI:Destroy()
        end
        if game.CoreGui:FindFirstChild("ESP_MinimizeText") then
            game.CoreGui.ESP_MinimizeText:Destroy()
        end
    end)
    task.wait(0.5)
end

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
-- DARK PURPLE COLORS (#221C35)
-- =============================================
local BACKGROUND = Color3.fromRGB(34, 28, 53)
local TOPBAR = Color3.fromRGB(45, 35, 65)
local TABBG = Color3.fromRGB(28, 22, 45)
local ELEMBG = Color3.fromRGB(50, 40, 72)
local ELEMBGHOVER = Color3.fromRGB(65, 50, 90)
local ACCENT = Color3.fromRGB(152, 29, 151)
local ACCENT_LIGHT = Color3.fromRGB(180, 60, 180)
local BORDER = Color3.fromRGB(100, 50, 130)
local TEXT = Color3.fromRGB(255, 255, 255)
local TEXTDIM = Color3.fromRGB(200, 180, 220)

-- =============================================
-- CONFIGURATION
-- =============================================
local Config = {
    Speed = 100,
    JumpPower = 80,
    MaxAirJumps = 5,
    ESPEnabled = true,
    MaxESPDistance = 2000 -- Permanently set to 2000
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

-- FPS & Ping Tracking
local currentFPS = 0
local currentPing = 0
local frameCount = 0
local lastFPSCheck = tick()

-- Bounty
local CurrentBounty = "Searching..."

-- Set global flag for re-execution
getgenv().UniversalESP_Loaded = true
getgenv().UniversalESP_ScriptActive = true

-- =============================================
-- TERMINATE FUNCTION (Complete UI Removal)
-- =============================================
local function terminateScript()
    ScriptActive = false
    Settings.ESPEnabled = false
    getgenv().UniversalESP_ScriptActive = false
    getgenv().UniversalESP_Loaded = false
    
    -- Reset player stats
    pcall(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = 16
            char.Humanoid.JumpPower = 50
        end
    end)
    
    -- Destroy all UI elements
    pcall(function()
        if GUI then 
            GUI:Destroy() 
        end
        if game.CoreGui:FindFirstChild("UniversalESP_GUI") then
            game.CoreGui.UniversalESP_GUI:Destroy()
        end
        if game.CoreGui:FindFirstChild("ESP_MinimizeText") then
            game.CoreGui.ESP_MinimizeText:Destroy()
        end
    end)
    
    -- Destroy all ESP objects (billboards and highlights)
    for _, esp in pairs(ESPObjects) do
        pcall(function()
            if esp and esp.Billboard then 
                esp.Billboard:Destroy() 
            end
            if esp and esp.Highlight then 
                esp.Highlight:Destroy() 
            end
        end)
    end
    ESPObjects = {}
    
    -- Disconnect all connections
    for _, conn in pairs(espConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    espConnections = {}
    
    -- Clear any lingering GUI elements
    pcall(function()
        for _, obj in pairs(game.CoreGui:GetChildren()) do
            if obj.Name == "UniversalESP_GUI" or obj.Name == "ESP_MinimizeText" then
                obj:Destroy()
            end
        end
    end)
    
    print("✓ ESP Terminated - All UI removed")
    print("✓ You can re-execute the script anytime")
end

-- =============================================
-- FPS & PING FUNCTIONS
-- =============================================
local function getFPS()
    local success, result = pcall(function()
        local perfStats = Stats:FindFirstChild("PerformanceStats")
        if perfStats then
            local fps = perfStats:FindFirstChild("FPS")
            if fps then
                return math.floor(fps.Value)
            end
        end
        return 0
    end)
    if success and result and result > 0 then
        return result
    end
    return 0
end

local function getPing()
    local success, result = pcall(function()
        if LocalPlayer then
            local ping = LocalPlayer:GetNetworkPing()
            if ping then
                return math.floor(ping * 1000)
            end
        end
        return 0
    end)
    if success then
        return result
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
-- CORNER ROUNDING FUNCTION
-- =============================================
local function RoundCorners(frame, radius)
    local corner = Instance.new("UICorner")
    corner.Parent = frame
    corner.CornerRadius = UDim.new(0, radius or 14)
end

-- =============================================
-- UI STROKE HELPER
-- =============================================
local function AddStroke(frame, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Parent = frame
    stroke.Color = color or BORDER
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.3
    return stroke
end

-- =============================================
-- GUI CREATION - MODERN DARK PURPLE THEME
-- =============================================
local GUI = Instance.new("ScreenGui")
GUI.Name = "UniversalESP_GUI"
GUI.ResetOnSpawn = false
GUI.Parent = game.CoreGui
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Adjust size for mobile
local mainWidth = 640
local mainHeight = 460
if isMobile then
    mainWidth = 480
    mainHeight = 400
end

-- Main Container
local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.Size = UDim2.new(0, mainWidth, 0, mainHeight)
Main.Position = UDim2.new(0.5, -mainWidth/2, 0.5, -mainHeight/2)
Main.BackgroundColor3 = BACKGROUND
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = GUI
RoundCorners(Main, 16)

-- Shadow
local Shadow = Instance.new("Frame")
Shadow.Parent = Main
Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Shadow.BackgroundTransparency = 0.7
Shadow.BorderSizePixel = 0
Shadow.Position = UDim2.new(0, 10, 0, 10)
Shadow.Size = UDim2.new(1, -20, 1, -20)
RoundCorners(Shadow, 16)

-- Main Border
AddStroke(Main, BORDER, 1.5, 0.2)

-- =============================================
-- MINIMIZED BAR (with FPS & PING)
-- =============================================
local MinimizeText = Instance.new("TextButton")
MinimizeText.Name = "ESP_MinimizeText"
MinimizeText.Size = UDim2.new(0, isMobile and 320 or 400, 0, isMobile and 50 or 44)
MinimizeText.Position = UDim2.new(0.5, -200, 0.95, -22)
MinimizeText.BackgroundColor3 = BACKGROUND
MinimizeText.BorderSizePixel = 0
MinimizeText.TextColor3 = ACCENT
MinimizeText.Text = "👁️  Universal ESP  |  FPS: --  |  MS: --"
MinimizeText.Font = Enum.Font.GothamBold
MinimizeText.TextSize = isMobile and 14 or 13
MinimizeText.AutoButtonColor = false
MinimizeText.Visible = false
MinimizeText.Active = true
MinimizeText.ZIndex = 10
MinimizeText.Parent = GUI
RoundCorners(MinimizeText, 14)

-- Min Bar Border
AddStroke(MinimizeText, BORDER, 1, 0.2)

-- Min Bar Shadow
local MinShadow = Instance.new("Frame")
MinShadow.Parent = MinimizeText
MinShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MinShadow.BackgroundTransparency = 0.6
MinShadow.BorderSizePixel = 0
MinShadow.Position = UDim2.new(0, 6, 0, 6)
MinShadow.Size = UDim2.new(1, -12, 1, -12)
RoundCorners(MinShadow, 14)

-- =============================================
-- TOP BAR (NO CLOSE BUTTON)
-- =============================================
local TopBar = Instance.new("Frame")
TopBar.Parent = Main
TopBar.BackgroundColor3 = TOPBAR
TopBar.BackgroundTransparency = 0
TopBar.BorderSizePixel = 0
TopBar.Size = UDim2.new(1, 0, 0, 58)
RoundCorners(TopBar, 16)

-- Accent line
local AccentLine = Instance.new("Frame")
AccentLine.Parent = TopBar
AccentLine.BackgroundColor3 = ACCENT
AccentLine.BorderSizePixel = 0
AccentLine.Position = UDim2.new(0, 0, 1, -2)
AccentLine.Size = UDim2.new(1, 0, 0, 2.5)

-- Icon
local Icon = Instance.new("TextLabel")
Icon.Parent = TopBar
Icon.BackgroundTransparency = 1
Icon.Position = UDim2.new(0, 18, 0, 0)
Icon.Size = UDim2.new(0, 38, 1, 0)
Icon.Font = Enum.Font.GothamBold
Icon.Text = "👁️"
Icon.TextColor3 = ACCENT
Icon.TextSize = 24
Icon.TextXAlignment = Enum.TextXAlignment.Center

-- Title
local Title = Instance.new("TextLabel")
Title.Parent = TopBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 60, 0, 6)
Title.Size = UDim2.new(0, 200, 0, 24)
Title.Font = Enum.Font.GothamBold
Title.Text = "Universal ESP"
Title.TextColor3 = TEXT
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Subtitle
local Subtitle = Instance.new("TextLabel")
Subtitle.Parent = TopBar
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.new(0, 60, 0, 32)
Subtitle.Size = UDim2.new(0, 200, 0, 18)
Subtitle.Font = Enum.Font.Gotham
Subtitle.Text = "v3.0 • Modern Dark Purple"
Subtitle.TextColor3 = TEXTDIM
Subtitle.TextSize = 11
Subtitle.TextXAlignment = Enum.TextXAlignment.Left

-- =============================================
-- STATUS INDICATORS (Top Bar Right)
-- =============================================
-- FPS Display
local FPSDisplay = Instance.new("TextLabel")
FPSDisplay.Parent = TopBar
FPSDisplay.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
FPSDisplay.BackgroundTransparency = 0.3
FPSDisplay.BorderSizePixel = 0
FPSDisplay.Position = UDim2.new(1, -165, 0.5, -18)
FPSDisplay.Size = UDim2.new(0, 75, 0, 36)
FPSDisplay.Font = Enum.Font.GothamBold
FPSDisplay.Text = "FPS: 0"
FPSDisplay.TextColor3 = Color3.fromRGB(0, 255, 100)
FPSDisplay.TextSize = 12
FPSDisplay.TextXAlignment = Enum.TextXAlignment.Center
RoundCorners(FPSDisplay, 8)

-- Ping Display
local PingDisplay = Instance.new("TextLabel")
PingDisplay.Parent = TopBar
PingDisplay.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
PingDisplay.BackgroundTransparency = 0.3
PingDisplay.BorderSizePixel = 0
PingDisplay.Position = UDim2.new(1, -85, 0.5, -18)
PingDisplay.Size = UDim2.new(0, 75, 0, 36)
PingDisplay.Font = Enum.Font.GothamBold
PingDisplay.Text = "MS: 0"
PingDisplay.TextColor3 = Color3.fromRGB(100, 200, 255)
PingDisplay.TextSize = 12
PingDisplay.TextXAlignment = Enum.TextXAlignment.Center
RoundCorners(PingDisplay, 8)

-- Status Dot
local StatusDot = Instance.new("Frame")
StatusDot.Parent = TopBar
StatusDot.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
StatusDot.BorderSizePixel = 0
StatusDot.Position = UDim2.new(1, -8, 0.5, -4)
StatusDot.Size = UDim2.new(0, 8, 0, 8)
RoundCorners(StatusDot, 4)

-- Minimize Button (Only button on top bar now)
local MinBtn = Instance.new("TextButton")
MinBtn.Parent = TopBar
MinBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
MinBtn.BackgroundTransparency = 0.2
MinBtn.BorderSizePixel = 0
MinBtn.Position = UDim2.new(1, -45, 0.5, -16)
MinBtn.Size = UDim2.new(0, 32, 0, 32)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Text = "─"
MinBtn.TextColor3 = TEXT
MinBtn.TextSize = 20
RoundCorners(MinBtn, 16)

MinBtn.MouseEnter:Connect(function()
    TweenService:Create(MinBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.05}):Play()
end)
MinBtn.MouseLeave:Connect(function()
    TweenService:Create(MinBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play()
end)

-- =============================================
-- TABS
-- =============================================
local TabContainer = Instance.new("Frame")
TabContainer.Parent = Main
TabContainer.BackgroundColor3 = TABBG
TabContainer.BackgroundTransparency = 0
TabContainer.BorderSizePixel = 0
TabContainer.Position = UDim2.new(0, 0, 0, 58)
TabContainer.Size = UDim2.new(0, 170, 1, -58)

-- Tab Container Border
local TabBorder = Instance.new("Frame")
TabBorder.Parent = TabContainer
TabBorder.BackgroundColor3 = BORDER
TabBorder.BackgroundTransparency = 0.2
TabBorder.BorderSizePixel = 0
TabBorder.Position = UDim2.new(1, 0, 0, 0)
TabBorder.Size = UDim2.new(0, 1, 1, 0)

-- Content Area
local Content = Instance.new("ScrollingFrame")
Content.Parent = Main
Content.BackgroundColor3 = BACKGROUND
Content.BackgroundTransparency = 0
Content.BorderSizePixel = 0
Content.Position = UDim2.new(0, 170, 0, 58)
Content.Size = UDim2.new(1, -170, 1, -58)
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = BORDER
Content.ClipsDescendants = true

-- Tab system
local currentTab = nil
local tabContents = {}

-- =============================================
-- UI ELEMENTS (Modern Dark Purple)
-- =============================================
local function CreateTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Parent = TabContainer
    btn.BackgroundColor3 = TABBG
    btn.BackgroundTransparency = 0
    btn.BorderSizePixel = 0
    btn.Position = UDim2.new(0, 5, 0, #TabContainer:GetChildren() * 50 + 10)
    btn.Size = UDim2.new(1, -10, 0, 44)
    btn.Font = Enum.Font.Gotham
    btn.Text = "  " .. icon .. "  " .. name
    btn.TextColor3 = TEXTDIM
    btn.TextSize = 14
    btn.TextXAlignment = Enum.TextXAlignment.Left
    RoundCorners(btn, 8)
    
    local indicator = Instance.new("Frame")
    indicator.Parent = btn
    indicator.BackgroundColor3 = ACCENT
    indicator.BorderSizePixel = 0
    indicator.Position = UDim2.new(0, 0, 0.15, 0)
    indicator.Size = UDim2.new(0, 4, 0.7, 0)
    indicator.Visible = false
    RoundCorners(indicator, 2)
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = ELEMBGHOVER}):Play()
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= name then
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = TABBG}):Play()
        end
    end)
    
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = name .. "Content"
    tabContainer.Parent = Content
    tabContainer.BackgroundTransparency = 1
    tabContainer.Size = UDim2.new(1, 0, 0, 0)
    tabContainer.Visible = false
    tabContainer.ZIndex = 15
    tabContainer.ClipsDescendants = false
    
    tabContents[name] = {
        container = tabContainer,
        yPos = 15,
        btn = btn,
        indicator = indicator
    }
    
    local function select()
        if currentTab == name then return end
        currentTab = name
        
        for _, data in pairs(tabContents) do
            data.container.Visible = false
            data.btn.BackgroundColor3 = TABBG
            data.btn.TextColor3 = TEXTDIM
            data.indicator.Visible = false
        end
        
        local data = tabContents[name]
        if data then
            data.container.Visible = true
            data.btn.BackgroundColor3 = ELEMBGHOVER
            data.btn.TextColor3 = TEXT
            data.indicator.Visible = true
            task.wait(0.05)
            Content.CanvasSize = UDim2.new(0, 0, 0, data.yPos + 30)
        end
    end
    
    btn.MouseButton1Click:Connect(select)
    
    return {
        select = select,
        container = tabContainer,
        getY = function() return tabContents[name].yPos end,
        setY = function(val) tabContents[name].yPos = val end
    }
end

local function AddSection(text)
    local data = tabContents[currentTab]
    if not data then return end
    
    local container = data.container
    local y = data.yPos
    
    local frame = Instance.new("Frame")
    frame.Parent = container
    frame.BackgroundTransparency = 1
    frame.Position = UDim2.new(0, 15, 0, y)
    frame.Size = UDim2.new(1, -30, 0, 30)
    
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = "▸ " .. text
    label.TextColor3 = TEXTDIM
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    data.yPos = data.yPos + 38
    return frame
end

local function AddDivider()
    local data = tabContents[currentTab]
    if not data then return end
    
    local container = data.container
    local y = data.yPos
    
    local frame = Instance.new("Frame")
    frame.Parent = container
    frame.BackgroundColor3 = BORDER
    frame.BackgroundTransparency = 0.4
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0, 20, 0, y)
    frame.Size = UDim2.new(1, -40, 0, 1)
    
    data.yPos = data.yPos + 12
    return frame
end

local function AddLabel(text, color, size)
    local data = tabContents[currentTab]
    if not data then return end
    
    local container = data.container
    local y = data.yPos
    
    local frame = Instance.new("Frame")
    frame.Parent = container
    frame.BackgroundTransparency = 1
    frame.Position = UDim2.new(0, 15, 0, y)
    frame.Size = UDim2.new(1, -30, 0, 30)
    
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = color or TEXT
    label.TextSize = size or 16
    label.TextXAlignment = Enum.TextXAlignment.Center
    
    data.yPos = data.yPos + 38
    return frame
end

local function AddSmallLabel(text, color)
    local data = tabContents[currentTab]
    if not data then return end
    
    local container = data.container
    local y = data.yPos
    
    local frame = Instance.new("Frame")
    frame.Parent = container
    frame.BackgroundTransparency = 1
    frame.Position = UDim2.new(0, 15, 0, y)
    frame.Size = UDim2.new(1, -30, 0, 28)
    
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.Gotham
    label.Text = text
    label.TextColor3 = color or TEXTDIM
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Center
    
    data.yPos = data.yPos + 32
    return frame
end

local function AddButton(text, desc, callback)
    local data = tabContents[currentTab]
    if not data then return end
    
    local container = data.container
    local y = data.yPos
    
    local frame = Instance.new("Frame")
    frame.Parent = container
    frame.BackgroundColor3 = ELEMBG
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0, 15, 0, y)
    frame.Size = UDim2.new(1, -30, 0, 52)
    RoundCorners(frame, 10)
    frame.ClipsDescendants = false
    
    AddStroke(frame, BORDER, 1, 0.2)
    
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 4)
    label.Size = UDim2.new(0, 250, 0, 22)
    label.Font = Enum.Font.Gotham
    label.Text = text
    label.TextColor3 = TEXT
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    if desc then
        local descLabel = Instance.new("TextLabel")
        descLabel.Parent = frame
        descLabel.BackgroundTransparency = 1
        descLabel.Position = UDim2.new(0, 12, 0, 26)
        descLabel.Size = UDim2.new(0, 250, 0, 20)
        descLabel.Font = Enum.Font.Gotham
        descLabel.Text = desc
        descLabel.TextColor3 = TEXTDIM
        descLabel.TextSize = 11
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
    end
    
    local btn = Instance.new("TextButton")
    btn.Parent = frame
    btn.BackgroundColor3 = ACCENT
    btn.BackgroundTransparency = 0
    btn.BorderSizePixel = 0
    btn.Position = UDim2.new(1, -110, 0.5, -18)
    btn.Size = UDim2.new(0, 95, 0, 36)
    btn.Font = Enum.Font.GothamBold
    btn.Text = "Execute"
    btn.TextColor3 = TEXT
    btn.TextSize = 13
    RoundCorners(btn, 8)
    btn.ZIndex = 51
    
    btn.MouseButton1Click:Connect(callback)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = ACCENT_LIGHT}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = ACCENT}):Play()
    end)
    
    data.yPos = data.yPos + 60
    return frame
end

local function AddToggle(text, default, callback)
    local data = tabContents[currentTab]
    if not data then return end
    
    local container = data.container
    local y = data.yPos
    local state = default or false
    
    local frame = Instance.new("Frame")
    frame.Parent = container
    frame.BackgroundColor3 = ELEMBG
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0, 15, 0, y)
    frame.Size = UDim2.new(1, -30, 0, 46)
    RoundCorners(frame, 10)
    
    AddStroke(frame, BORDER, 1, 0.2)
    
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(0, 280, 1, 0)
    label.Font = Enum.Font.Gotham
    label.Text = text
    label.TextColor3 = TEXT
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    local toggle = Instance.new("Frame")
    toggle.Parent = frame
    toggle.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    toggle.BackgroundTransparency = 0
    toggle.BorderSizePixel = 0
    toggle.Position = UDim2.new(1, -55, 0.5, -15)
    toggle.Size = UDim2.new(0, 40, 0, 30)
    RoundCorners(toggle, 15)
    
    local indicator = Instance.new("Frame")
    indicator.Parent = toggle
    indicator.BackgroundColor3 = Color3.fromRGB(200, 200, 220)
    indicator.BorderSizePixel = 0
    indicator.Position = UDim2.new(0, 3, 0.5, -12)
    indicator.Size = UDim2.new(0, 24, 0, 24)
    RoundCorners(indicator, 12)
    
    local function update(val)
        state = val
        if state then
            TweenService:Create(toggle, TweenInfo.new(0.3), {BackgroundColor3 = ACCENT}):Play()
            TweenService:Create(indicator, TweenInfo.new(0.3), {Position = UDim2.new(1, -27, 0.5, -12)}):Play()
        else
            TweenService:Create(toggle, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 80, 100)}):Play()
            TweenService:Create(indicator, TweenInfo.new(0.3), {Position = UDim2.new(0, 3, 0.5, -12)}):Play()
        end
        if callback then callback(state) end
    end
    
    toggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            update(not state)
        end
    end)
    
    update(state)
    data.yPos = data.yPos + 54
    return frame
end

-- =============================================
-- CREATE TABS
-- =============================================
local ESPTab = CreateTab("ESP", "👁️")
local PlayerTab = CreateTab("Player", "👤")
local SettingsTab = CreateTab("Settings", "⚙️")

-- =============================================
-- ESP TAB CONTENT
-- =============================================
ESPTab.select()

AddSection("ESP CONTROLS")

local ESPStatus = Instance.new("TextLabel")
ESPStatus.Size = UDim2.new(1, -30, 0, 18)
ESPStatus.Position = UDim2.new(0, 15, 0, ESPTab.getY())
ESPStatus.BackgroundTransparency = 1
ESPStatus.TextColor3 = Color3.fromRGB(0, 255, 100)
ESPStatus.Text = "● ESP Active"
ESPStatus.TextXAlignment = Enum.TextXAlignment.Left
ESPStatus.Font = Enum.Font.Gotham
ESPStatus.TextSize = 11
ESPStatus.Parent = ESPTab.container
ESPTab.setY(ESPTab.getY() + 24)

AddToggle("Enable ESP", true, function(state)
    Config.ESPEnabled = state
    ESPStatus.Text = state and "● ESP Active" or "● ESP Disabled"
    ESPStatus.TextColor3 = state and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
end)

AddDivider()
AddSection("PLAYER STATS")

local SpeedDisplay = Instance.new("TextLabel")
SpeedDisplay.Size = UDim2.new(1, -30, 0, 18)
SpeedDisplay.Position = UDim2.new(0, 15, 0, ESPTab.getY())
SpeedDisplay.BackgroundTransparency = 1
SpeedDisplay.TextColor3 = Color3.fromRGB(0, 200, 255)
SpeedDisplay.Text = "⚡ Speed: " .. Config.Speed
SpeedDisplay.TextXAlignment = Enum.TextXAlignment.Left
SpeedDisplay.Font = Enum.Font.GothamBold
SpeedDisplay.TextSize = 11
SpeedDisplay.Parent = ESPTab.container
ESPTab.setY(ESPTab.getY() + 22)

local JumpDisplay = Instance.new("TextLabel")
JumpDisplay.Size = UDim2.new(1, -30, 0, 18)
JumpDisplay.Position = UDim2.new(0, 15, 0, ESPTab.getY())
JumpDisplay.BackgroundTransparency = 1
JumpDisplay.TextColor3 = Color3.fromRGB(100, 200, 255)
JumpDisplay.Text = "🦘 Jump: " .. Config.JumpPower .. " | Air: " .. Config.MaxAirJumps
JumpDisplay.TextXAlignment = Enum.TextXAlignment.Left
JumpDisplay.Font = Enum.Font.GothamBold
JumpDisplay.TextSize = 11
JumpDisplay.Parent = ESPTab.container
ESPTab.setY(ESPTab.getY() + 22)

local RangeDisplay = Instance.new("TextLabel")
RangeDisplay.Size = UDim2.new(1, -30, 0, 18)
RangeDisplay.Position = UDim2.new(0, 15, 0, ESPTab.getY())
RangeDisplay.BackgroundTransparency = 1
RangeDisplay.TextColor3 = Color3.fromRGB(255, 200, 0)
RangeDisplay.Text = "📏 Range: 2000m (Permanent)"
RangeDisplay.TextXAlignment = Enum.TextXAlignment.Left
RangeDisplay.Font = Enum.Font.GothamBold
RangeDisplay.TextSize = 11
RangeDisplay.Parent = ESPTab.container
ESPTab.setY(ESPTab.getY() + 28)

-- =============================================
-- PLAYER TAB CONTENT
-- =============================================
PlayerTab.select()

AddSection("PLAYER INFO")

local PlayerNameDisplay = Instance.new("TextLabel")
PlayerNameDisplay.Size = UDim2.new(1, -30, 0, 22)
PlayerNameDisplay.Position = UDim2.new(0, 15, 0, PlayerTab.getY())
PlayerNameDisplay.BackgroundTransparency = 1
PlayerNameDisplay.TextColor3 = TEXT
PlayerNameDisplay.Text = "👤 " .. LocalPlayer.Name
PlayerNameDisplay.TextXAlignment = Enum.TextXAlignment.Left
PlayerNameDisplay.Font = Enum.Font.GothamBold
PlayerNameDisplay.TextSize = 15
PlayerNameDisplay.Parent = PlayerTab.container
PlayerTab.setY(PlayerTab.getY() + 28)

local PlayerBounty = Instance.new("Frame")
PlayerBounty.Size = UDim2.new(1, -30, 0, 44)
PlayerBounty.Position = UDim2.new(0, 15, 0, PlayerTab.getY())
PlayerBounty.BackgroundColor3 = ELEMBG
PlayerBounty.BorderSizePixel = 0
PlayerBounty.Parent = PlayerTab.container
RoundCorners(PlayerBounty, 8)
AddStroke(PlayerBounty, BORDER, 1, 0.2)

local PlayerBountyLabel = Instance.new("TextLabel")
PlayerBountyLabel.Size = UDim2.new(1, -20, 0, 14)
PlayerBountyLabel.Position = UDim2.new(0, 10, 0, 5)
PlayerBountyLabel.BackgroundTransparency = 1
PlayerBountyLabel.TextColor3 = TEXTDIM
PlayerBountyLabel.Text = "BOUNTY"
PlayerBountyLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerBountyLabel.Font = Enum.Font.GothamBold
PlayerBountyLabel.TextSize = 9
PlayerBountyLabel.Parent = PlayerBounty

local PlayerBountyValue = Instance.new("TextLabel")
PlayerBountyValue.Size = UDim2.new(1, -20, 0, 20)
PlayerBountyValue.Position = UDim2.new(0, 10, 0, 18)
PlayerBountyValue.BackgroundTransparency = 1
PlayerBountyValue.TextColor3 = Color3.fromRGB(255, 200, 0)
PlayerBountyValue.Text = "Searching..."
PlayerBountyValue.TextXAlignment = Enum.TextXAlignment.Left
PlayerBountyValue.Font = Enum.Font.GothamBold
PlayerBountyValue.TextSize = 14
PlayerBountyValue.Parent = PlayerBounty
PlayerTab.setY(PlayerTab.getY() + 52)

AddDivider()
AddSection("HEALTH")

local HealthBarBg = Instance.new("Frame")
HealthBarBg.Size = UDim2.new(1, -30, 0, 22)
HealthBarBg.Position = UDim2.new(0, 15, 0, PlayerTab.getY())
HealthBarBg.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
HealthBarBg.BorderSizePixel = 0
HealthBarBg.Parent = PlayerTab.container
RoundCorners(HealthBarBg, 6)

local HealthBar = Instance.new("Frame")
HealthBar.Size = UDim2.new(1, 0, 1, 0)
HealthBar.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
HealthBar.BorderSizePixel = 0
HealthBar.Parent = HealthBarBg
RoundCorners(HealthBar, 6)

local HealthText = Instance.new("TextLabel")
HealthText.Size = UDim2.new(1, 0, 1, 0)
HealthText.BackgroundTransparency = 1
HealthText.TextColor3 = TEXT
HealthText.Text = "100%"
HealthText.Font = Enum.Font.GothamBold
HealthText.TextSize = 11
HealthText.Parent = HealthBar
PlayerTab.setY(PlayerTab.getY() + 30)

AddDivider()
AddSection("DETECTED PLAYERS")

local PlayerCountLabel = Instance.new("TextLabel")
PlayerCountLabel.Size = UDim2.new(1, -30, 0, 18)
PlayerCountLabel.Position = UDim2.new(0, 15, 0, PlayerTab.getY())
PlayerCountLabel.BackgroundTransparency = 1
PlayerCountLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
PlayerCountLabel.Text = "👥 Players in game: " .. #Players:GetPlayers()
PlayerCountLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerCountLabel.Font = Enum.Font.GothamBold
PlayerCountLabel.TextSize = 12
PlayerCountLabel.Parent = PlayerTab.container
PlayerTab.setY(PlayerTab.getY() + 26)

-- =============================================
-- SETTINGS TAB CONTENT
-- =============================================
SettingsTab.select()

AddSection("PERMANENT STATS")

AddSmallLabel("⚡ Walk Speed: " .. Config.Speed, Color3.fromRGB(0, 200, 255))
AddSmallLabel("🦘 Jump Power: " .. Config.JumpPower, Color3.fromRGB(100, 200, 255))
AddSmallLabel("🌀 Air Jumps: " .. Config.MaxAirJumps, Color3.fromRGB(200, 200, 100))
AddSmallLabel("📏 ESP Range: 2000m (Fixed)", Color3.fromRGB(255, 200, 0))

AddDivider()
AddSection("CONTROLS")

AddButton("🔄 Toggle ESP", "Enable or disable ESP", function()
    Config.ESPEnabled = not Config.ESPEnabled
    ESPStatus.Text = Config.ESPEnabled and "● ESP Active" or "● ESP Disabled"
    ESPStatus.TextColor3 = Config.ESPEnabled and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
end)

AddButton("⚠️ TERMINATE SCRIPT", "⚠️ Completely close the script and remove all UI", function()
    terminateScript()
end)

AddDivider()
AddSmallLabel("✦ Made with ❤️ by QueezZy123", Color3.fromRGB(150, 100, 180))
AddSmallLabel("✦ Click '─' to minimize", Color3.fromRGB(100, 80, 120))

-- =============================================
-- SELECT DEFAULT TAB (ESP)
-- =============================================
ESPTab.select()

-- =============================================
-- MINIMIZE / EXPAND FUNCTIONS
-- =============================================
local function showMain()
    Main.Visible = true
    MinimizeText.Visible = false
    Settings.Minimized = false
end

local function showMinBar()
    Main.Visible = false
    MinimizeText.Visible = true
    Settings.Minimized = true
end

MinBtn.Activated:Connect(showMinBar)
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

TopBar.InputBegan:Connect(function(input)
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

TopBar.InputChanged:Connect(function(input)
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
-- UPDATE LOOPS - REAL-TIME FPS & PING
-- =============================================

-- FPS Counter using Heartbeat
RunService.Heartbeat:Connect(function()
    if not ScriptActive then return end
    frameCount = frameCount + 1
end)

-- FPS & Ping Update loop
task.spawn(function()
    while ScriptActive do
        -- Calculate FPS
        local currentTime = tick()
        local deltaTime = currentTime - lastFPSCheck
        
        if deltaTime >= 0.5 then
            currentFPS = math.floor(frameCount / deltaTime)
            frameCount = 0
            lastFPSCheck = currentTime
        end
        
        -- Get Ping
        currentPing = getPing()
        
        -- Update FPS Display with color coding
        FPSDisplay.Text = "FPS: " .. currentFPS
        if currentFPS >= 60 then
            FPSDisplay.TextColor3 = Color3.fromRGB(0, 255, 100)
            FPSDisplay.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
            FPSDisplay.BackgroundTransparency = 0.85
        elseif currentFPS >= 45 then
            FPSDisplay.TextColor3 = Color3.fromRGB(100, 255, 100)
            FPSDisplay.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
            FPSDisplay.BackgroundTransparency = 0.85
        elseif currentFPS >= 30 then
            FPSDisplay.TextColor3 = Color3.fromRGB(255, 220, 50)
            FPSDisplay.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
            FPSDisplay.BackgroundTransparency = 0.85
        elseif currentFPS >= 20 then
            FPSDisplay.TextColor3 = Color3.fromRGB(255, 150, 50)
            FPSDisplay.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
            FPSDisplay.BackgroundTransparency = 0.85
        else
            FPSDisplay.TextColor3 = Color3.fromRGB(255, 50, 50)
            FPSDisplay.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            FPSDisplay.BackgroundTransparency = 0.85
        end
        
        -- Update Ping Display with color coding
        PingDisplay.Text = "MS: " .. currentPing
        if currentPing <= 50 then
            PingDisplay.TextColor3 = Color3.fromRGB(100, 255, 255)
            PingDisplay.BackgroundColor3 = Color3.fromRGB(100, 255, 255)
            PingDisplay.BackgroundTransparency = 0.85
        elseif currentPing <= 80 then
            PingDisplay.TextColor3 = Color3.fromRGB(100, 200, 255)
            PingDisplay.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
            PingDisplay.BackgroundTransparency = 0.85
        elseif currentPing <= 120 then
            PingDisplay.TextColor3 = Color3.fromRGB(255, 220, 50)
            PingDisplay.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
            PingDisplay.BackgroundTransparency = 0.85
        elseif currentPing <= 200 then
            PingDisplay.TextColor3 = Color3.fromRGB(255, 150, 50)
            PingDisplay.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
            PingDisplay.BackgroundTransparency = 0.85
        else
            PingDisplay.TextColor3 = Color3.fromRGB(255, 50, 50)
            PingDisplay.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            PingDisplay.BackgroundTransparency = 0.85
        end
        
        -- Update Status Dot
        if currentPing <= 50 then
            StatusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 255)
        elseif currentPing <= 80 then
            StatusDot.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
        elseif currentPing <= 120 then
            StatusDot.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
        elseif currentPing <= 200 then
            StatusDot.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
        else
            StatusDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        end
        
        -- Update Minimized Bar
        if Settings.Minimized then
            MinimizeText.Text = "👁️  Universal ESP  |  FPS: " .. currentFPS .. "  |  MS: " .. currentPing
            
            if currentFPS >= 60 then
                MinimizeText.TextColor3 = Color3.fromRGB(0, 255, 100)
            elseif currentFPS >= 30 then
                MinimizeText.TextColor3 = Color3.fromRGB(255, 220, 50)
            else
                MinimizeText.TextColor3 = Color3.fromRGB(255, 50, 50)
            end
        end
        
        task.wait(0.15)
    end
end)

-- Player count
task.spawn(function()
    while ScriptActive do
        local count = #Players:GetPlayers()
        PlayerCountLabel.Text = "👥 Players in game: " .. count
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

-- Apply Stats Loop
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
                local inRange = dist <= Config.MaxESPDistance -- Permanently 2000
                
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
print("║     UNIVERSAL ESP - Modern UI       ║")
print("╠══════════════════════════════════════╣")
print("║  ⚡ Speed: " .. Config.Speed .. "                      ║")
print("║  🦘 Jump: " .. Config.JumpPower .. " | Air: " .. Config.MaxAirJumps .. "   ║")
print("║  👁️  ESP Active                      ║")
print("║  📏 Range: 2000m (Permanent)        ║")
print("╠══════════════════════════════════════╣")
print("║  Dark Purple Theme (#221C35)        ║")
print("║  Modern Tabbed UI                   ║")
print("║  Click '─' to minimize to bar       ║")
print("║  Click text to restore GUI          ║")
print("║  Use 'TERMINATE SCRIPT' to close    ║")
print("║  Re-execute anytime after close     ║")
print("╚══════════════════════════════════════╝")
print("")
