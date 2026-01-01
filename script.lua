-- Vicious Bee Stinger Hunter Script
-- Compatible with Delta Executor

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local PLACE_ID = 1537690962 -- Bee Swarm Simulator

-- Configuration
local config = {
    webhookUrl = "",
    checkInterval = 3,
    serverHopDelay = 8,
    isRunning = false,
    stingerDetected = false,
    currentField = "None"
}

-- Field positions in Bee Swarm Simulator
local fields = {
    ["Sunflower Field"] = Vector3.new(183, 4, 165),
    ["Mushroom Field"] = Vector3.new(-253, 4, 299),
    ["Dandelion Field"] = Vector3.new(-30, 4, 225),
    ["Blue Flower Field"] = Vector3.new(113, 4, 88),
    ["Clover Field"] = Vector3.new(174, 34, 189),
    ["Strawberry Field"] = Vector3.new(-169, 20, 165),
    ["Spider Field"] = Vector3.new(-57, 20, 4),
    ["Bamboo Field"] = Vector3.new(93, 20, -25),
    ["Pineapple Patch"] = Vector3.new(262, 68, -201),
    ["Pumpkin Patch"] = Vector3.new(-194, 68, -182),
    ["Cactus Field"] = Vector3.new(-194, 68, -107),
    ["Rose Field"] = Vector3.new(-322, 20, 124),
    ["Pine Tree Forest"] = Vector3.new(-318, 68, -150),
    ["Stump Field"] = Vector3.new(439, 96, -179),
    ["Coconut Field"] = Vector3.new(-255, 72, 459),
    ["Pepper Patch"] = Vector3.new(-486, 124, 517),
    ["Mountain Top Field"] = Vector3.new(76, 176, -191)
}

-- Function to send Discord webhook
local function sendWebhook(title, description, color, fields)
    if config.webhookUrl == "" then return end
    
    local embed = {
        ["title"] = title,
        ["description"] = description,
        ["color"] = color,
        ["fields"] = fields or {},
        ["timestamp"] = HttpService:JSONEncode(DateTime.now():ToIsoDate()),
        ["footer"] = {
            ["text"] = "Vicious Bee Hunter | " .. player.Name
        }
    }
    
    local data = {
        ["embeds"] = {embed}
    }
    
    local success, err = pcall(function()
        local response = request({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    if not success then
        warn("Webhook failed:", err)
    end
end

-- Function to get nearest field to position
local function getNearestField(position)
    local nearestField = "Unknown"
    local shortestDist = math.huge
    
    for fieldName, fieldPos in pairs(fields) do
        local dist = (position - fieldPos).Magnitude
        if dist < shortestDist then
            shortestDist = dist
            nearestField = fieldName
        end
    end
    
    return nearestField, shortestDist
end

-- Function to check for Vicious Bee stinger
local function checkForStinger()
    local monsters = Workspace:FindFirstChild("MonsterHolder") or Workspace:FindFirstChild("Monsters")
    
    if monsters then
        local viciousBee = monsters:FindFirstChild("Vicious Bee")
        
        if viciousBee then
            local rootPart = viciousBee:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local position = rootPart.Position
                local fieldName, distance = getNearestField(position)
                
                if not config.stingerDetected then
                    config.stingerDetected = true
                    config.currentField = fieldName
                    
                    sendWebhook(
                        "🐝 VICIOUS BEE DETECTED!",
                        "A Vicious Bee stinger has been found!",
                        0xFF0000,
                        {
                            {name = "📍 Field", value = fieldName, inline = true},
                            {name = "🌐 Server", value = game.JobId, inline = true},
                            {name = "👤 Player", value = player.Name, inline = true},
                            {name = "📊 Distance", value = math.floor(distance) .. " studs", inline = true}
                        }
                    )
                    
                    print("🐝 VICIOUS BEE FOUND IN: " .. fieldName)
                end
                
                return true, fieldName
            end
        else
            if config.stingerDetected then
                sendWebhook(
                    "✅ Vicious Bee Defeated/Despawned",
                    "The Vicious Bee is no longer present. Hopping to next server...",
                    0x00FF00,
                    {
                        {name = "Previous Field", value = config.currentField, inline = true}
                    }
                )
                
                config.stingerDetected = false
                config.currentField = "None"
                print("✅ Vicious Bee gone. Server hopping...")
            end
        end
    end
    
    return false, "None"
end

-- Function to server hop
local function serverHop()
    sendWebhook(
        "🔄 Server Hopping",
        "No Vicious Bee found. Searching next server...",
        0xFFA500,
        {}
    )
    
    print("🔄 Hopping to new server...")
    
    wait(2)
    
    -- Use Teleport to get a random server
    local success, err = pcall(function()
        TeleportService:Teleport(PLACE_ID, player)
    end)
    
    if not success then
        warn("Failed to server hop:", err)
        -- Try alternative method with game link
        game:GetService("TeleportService"):TeleportToPlaceInstance(PLACE_ID, game.JobId)
    end
end

-- Main detection loop
local function mainLoop()
    while config.isRunning do
        local found, fieldName = checkForStinger()
        
        if not found and not config.stingerDetected then
            wait(config.serverHopDelay)
            if config.isRunning and not config.stingerDetected then
                serverHop()
                break -- Exit loop as we're teleporting
            end
        end
        
        wait(config.checkInterval)
    end
end

-- Create GUI
local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    local MainFrame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local WebhookBox = Instance.new("TextBox")
    local StartButton = Instance.new("TextButton")
    local StatusLabel = Instance.new("TextLabel")
    local FieldLabel = Instance.new("TextLabel")
    local CloseButton = Instance.new("TextButton")
    local UICorner1 = Instance.new("UICorner")
    local UICorner2 = Instance.new("UICorner")
    local UICorner3 = Instance.new("UICorner")
    local UICorner4 = Instance.new("UICorner")
    
    ScreenGui.Name = "ViciousBeeHunterGUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    MainFrame.Size = UDim2.new(0, 400, 0, 300)
    MainFrame.Active = true
    MainFrame.Draggable = true
    
    UICorner1.CornerRadius = UDim.new(0, 12)
    UICorner1.Parent = MainFrame
    
    Title.Name = "Title"
    Title.Parent = MainFrame
    Title.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    Title.BorderSizePixel = 0
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🐝 Vicious Bee Stinger Hunter"
    Title.TextColor3 = Color3.fromRGB(20, 20, 20)
    Title.TextSize = 18
    
    UICorner4.CornerRadius = UDim.new(0, 12)
    UICorner4.Parent = Title
    
    CloseButton.Name = "CloseButton"
    CloseButton.Parent = MainFrame
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    CloseButton.BorderSizePixel = 0
    CloseButton.Position = UDim2.new(1, -35, 0, 10)
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 16
    
    Instance.new("UICorner").Parent = CloseButton
    
    WebhookBox.Name = "WebhookBox"
    WebhookBox.Parent = MainFrame
    WebhookBox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    WebhookBox.BorderSizePixel = 0
    WebhookBox.Position = UDim2.new(0, 20, 0, 70)
    WebhookBox.Size = UDim2.new(1, -40, 0, 40)
    WebhookBox.Font = Enum.Font.Gotham
    WebhookBox.PlaceholderText = "Enter Discord Webhook URL..."
    WebhookBox.Text = ""
    WebhookBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookBox.TextSize = 14
    WebhookBox.ClearTextOnFocus = false
    
    UICorner2.CornerRadius = UDim.new(0, 8)
    UICorner2.Parent = WebhookBox
    
    StartButton.Name = "StartButton"
    StartButton.Parent = MainFrame
    StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    StartButton.BorderSizePixel = 0
    StartButton.Position = UDim2.new(0, 20, 0, 125)
    StartButton.Size = UDim2.new(1, -40, 0, 45)
    StartButton.Font = Enum.Font.GothamBold
    StartButton.Text = "START HUNTING"
    StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartButton.TextSize = 16
    
    UICorner3.CornerRadius = UDim.new(0, 8)
    UICorner3.Parent = StartButton
    
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Parent = MainFrame
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 20, 0, 185)
    StatusLabel.Size = UDim2.new(1, -40, 0, 30)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    FieldLabel.Name = "FieldLabel"
    FieldLabel.Parent = MainFrame
    FieldLabel.BackgroundTransparency = 1
    FieldLabel.Position = UDim2.new(0, 20, 0, 215)
    FieldLabel.Size = UDim2.new(1, -40, 0, 30)
    FieldLabel.Font = Enum.Font.Gotham
    FieldLabel.Text = "Current Field: None"
    FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    FieldLabel.TextSize = 13
    FieldLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Button functionality
    StartButton.MouseButton1Click:Connect(function()
        if not config.isRunning then
            local webhook = WebhookBox.Text
            if webhook == "" or not webhook:match("^https://discord%.com/api/webhooks/") then
                StatusLabel.Text = "Status: ❌ Invalid Webhook URL"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                return
            end
            
            config.webhookUrl = webhook
            config.isRunning = true
            
            StartButton.Text = "STOP HUNTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            StatusLabel.Text = "Status: 🔍 Hunting..."
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            sendWebhook(
                "🚀 Hunter Started",
                "Vicious Bee detection is now active!",
                0x00AAFF,
                {}
            )
            
            spawn(mainLoop)
        else
            config.isRunning = false
            StartButton.Text = "START HUNTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            StatusLabel.Text = "Status: Stopped"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end)
    
    CloseButton.MouseButton1Click:Connect(function()
        config.isRunning = false
        ScreenGui:Destroy()
    end)
    
    -- Update labels loop
    spawn(function()
        while wait(0.5) do
            if config.stingerDetected then
                FieldLabel.Text = "Current Field: 🐝 " .. config.currentField
                FieldLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
            else
                FieldLabel.Text = "Current Field: None"
                FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end
    end)
end

-- Initialize
print("🐝 Vicious Bee Stinger Hunter Loaded!")
print("📱 Opening GUI...")
createGUI()

sendWebhook(
    "📱 Script Loaded",
    "Vicious Bee Hunter is ready to use!",
    0x5865F2,
    {
        {name = "Player", value = player.Name, inline = true},
        {name = "Server", value = game.JobId, inline = true}
    }
)
