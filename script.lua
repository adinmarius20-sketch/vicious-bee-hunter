
-- Vicious Bee Stinger Hunter Script v2
-- Compatible with Delta Executor
-- Fixes: Public server hopping + Webhook saving

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local PLACE_ID = 1537690962 -- Bee Swarm Simulator

-- Configuration with saved webhook
local config = {
    webhookUrl = "",
    checkInterval = 3,
    serverHopDelay = 8,
    isRunning = false,
    stingerDetected = false,
    currentField = "None"
}

-- Load saved webhook from file
if isfile and readfile then
    if isfile("vicious_bee_webhook.txt") then
        local saved = readfile("vicious_bee_webhook.txt")
        if saved and saved ~= "" then
            config.webhookUrl = saved
            print("✅ Loaded saved webhook")
        end
    end
end

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
local function sendWebhook(title, description, color, webhookFields)
    if config.webhookUrl == "" then return end
    
    local embed = {
        ["title"] = title,
        ["description"] = description,
        ["color"] = color,
        ["fields"] = webhookFields or {},
        ["timestamp"] = DateTime.now():ToIsoDate(),
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

-- Function to get list of public servers and join one
local function serverHopPublic()
    sendWebhook(
        "🔄 Server Hopping",
        "No Vicious Bee found. Searching next public server...",
        0xFFA500,
        {}
    )
    
    print("🔄 Searching for public servers...")
    
    local success, result = pcall(function()
        -- Get server list from Roblox API
        local serversUrl = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
        local serversData = game:HttpGet(serversUrl)
        local servers = HttpService:JSONDecode(serversData)
        
        if servers and servers.data then
            -- Filter out full servers and current server
            local validServers = {}
            for _, server in pairs(servers.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    table.insert(validServers, server)
                end
            end
            
            if #validServers > 0 then
                -- Pick random server
                local randomServer = validServers[math.random(1, #validServers)]
                print("✅ Found public server:", randomServer.id)
                
                -- Teleport to that specific server
                TeleportService:TeleportToPlaceInstance(PLACE_ID, randomServer.id, player)
            else
                print("⚠️ No available servers, using fallback teleport")
                wait(2)
                TeleportService:Teleport(PLACE_ID, player)
            end
        end
    end)
    
    if not success then
        warn("Server hop failed, using fallback:", result)
        wait(2)
        -- Fallback to regular teleport
        TeleportService:Teleport(PLACE_ID, player)
    end
end

-- Main detection loop
local function mainLoop()
    while config.isRunning do
        local found, fieldName = checkForStinger()
        
        if not found and not config.stingerDetected then
            wait(config.serverHopDelay)
            if config.isRunning and not config.stingerDetected then
                serverHopPublic()
                break -- Exit loop as we're teleporting
            end
        end
        
        wait(config.checkInterval)
    end
end

-- Create GUI
local function createGUI()
    -- Check if GUI already exists
    if CoreGui:FindFirstChild("ViciousBeeHunterGUI") then
        CoreGui:FindFirstChild("ViciousBeeHunterGUI"):Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    local MainFrame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local WebhookBox = Instance.new("TextBox")
    local StartButton = Instance.new("TextButton")
    local StatusLabel = Instance.new("TextLabel")
    local FieldLabel = Instance.new("TextLabel")
    local CloseButton = Instance.new("TextButton")
    local AutoStartCheckbox = Instance.new("TextButton")
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
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -170)
    MainFrame.Size = UDim2.new(0, 400, 0, 340)
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
    Title.Text = "🐝 Vicious Bee Hunter (Public Servers)"
    Title.TextColor3 = Color3.fromRGB(20, 20, 20)
    Title.TextSize = 17
    
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
    WebhookBox.Text = config.webhookUrl
    WebhookBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookBox.TextSize = 14
    WebhookBox.ClearTextOnFocus = false
    
    UICorner2.CornerRadius = UDim.new(0, 8)
    UICorner2.Parent = WebhookBox
    
    AutoStartCheckbox.Name = "AutoStartCheckbox"
    AutoStartCheckbox.Parent = MainFrame
    AutoStartCheckbox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    AutoStartCheckbox.BorderSizePixel = 0
    AutoStartCheckbox.Position = UDim2.new(0, 20, 0, 120)
    AutoStartCheckbox.Size = UDim2.new(1, -40, 0, 30)
    AutoStartCheckbox.Font = Enum.Font.Gotham
    AutoStartCheckbox.Text = "⬜ Auto-Start on Execute (Click to Enable)"
    AutoStartCheckbox.TextColor3 = Color3.fromRGB(200, 200, 200)
    AutoStartCheckbox.TextSize = 12
    
    Instance.new("UICorner").Parent = AutoStartCheckbox
    
    StartButton.Name = "StartButton"
    StartButton.Parent = MainFrame
    StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    StartButton.BorderSizePixel = 0
    StartButton.Position = UDim2.new(0, 20, 0, 160)
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
    StatusLabel.Position = UDim2.new(0, 20, 0, 220)
    StatusLabel.Size = UDim2.new(1, -40, 0, 30)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    FieldLabel.Name = "FieldLabel"
    FieldLabel.Parent = MainFrame
    FieldLabel.BackgroundTransparency = 1
    FieldLabel.Position = UDim2.new(0, 20, 0, 250)
    FieldLabel.Size = UDim2.new(1, -40, 0, 30)
    FieldLabel.Font = Enum.Font.Gotham
    FieldLabel.Text = "Current Field: None"
    FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    FieldLabel.TextSize = 13
    FieldLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Load auto-start preference
    local autoStartEnabled = false
    if isfile and readfile and isfile("vicious_bee_autostart.txt") then
        local saved = readfile("vicious_bee_autostart.txt")
        autoStartEnabled = saved == "true"
    end
    
    if autoStartEnabled then
        AutoStartCheckbox.Text = "✅ Auto-Start on Execute (Enabled)"
        AutoStartCheckbox.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    end
    
    -- Auto-start checkbox functionality
    AutoStartCheckbox.MouseButton1Click:Connect(function()
        autoStartEnabled = not autoStartEnabled
        
        if autoStartEnabled then
            AutoStartCheckbox.Text = "✅ Auto-Start on Execute (Enabled)"
            AutoStartCheckbox.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        else
            AutoStartCheckbox.Text = "⬜ Auto-Start on Execute (Click to Enable)"
            AutoStartCheckbox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        end
        
        -- Save preference
        if writefile then
            writefile("vicious_bee_autostart.txt", tostring(autoStartEnabled))
        end
    end)
    
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
            
            -- Save webhook to file
            if writefile then
                writefile("vicious_bee_webhook.txt", webhook)
                print("✅ Webhook saved")
            end
            
            config.isRunning = true
            
            StartButton.Text = "STOP HUNTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            StatusLabel.Text = "Status: 🔍 Hunting (Public Servers)..."
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            sendWebhook(
                "🚀 Hunter Started",
                "Vicious Bee detection is now active! (Public servers only)",
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
            if not ScreenGui.Parent then break end
            
            if config.stingerDetected then
                FieldLabel.Text = "Current Field: 🐝 " .. config.currentField
                FieldLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
            else
                FieldLabel.Text = "Current Field: None"
                FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end
    end)
    
    -- Auto-start if enabled
    if autoStartEnabled and config.webhookUrl ~= "" then
        wait(1)
        StartButton.MouseButton1Click:Connect(function() end)
        StartButton:FindFirstChild("MouseButton1Click"):Fire()
    end
end

-- Initialize
print("🐝 Vicious Bee Stinger Hunter v2 Loaded!")
print("📱 Opening GUI...")
createGUI()
