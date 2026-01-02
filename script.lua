-- Vicious Bee Stinger Hunter Script v3.2 - ANTI-IDLE + SMART DETECTION
-- Detects "Thorn" parts that spawn near fields (ONCE per spawn event)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local request = request or http_request or syn.request
local player = Players.LocalPlayer

local config = {
    webhookUrl = "",
    isRunning = false,
    stingerDetected = false,
    currentField = "None",
    _descendantConnection = nil,
    _detectedStingers = {},
    detectionCount = 0,
    lastDetectionTime = 0,
    detectionCooldown = 5 -- seconds to wait before detecting again (prevents multiple alerts)
}

-- Load saved webhook
if isfile and readfile and isfile("vicious_bee_webhook.txt") then
    local saved = readfile("vicious_bee_webhook.txt")
    if saved and saved ~= "" then
        config.webhookUrl = saved
        print("✅ Loaded saved webhook")
    end
end

-- ANTI-IDLE SYSTEM
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("🔄 Anti-idle triggered (idle detection)")
end)

-- Additional anti-idle: Trigger every 10 minutes automatically
spawn(function()
    while true do
        wait(600) -- 600 seconds = 10 minutes
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        print("🔄 Anti-idle triggered (10 min auto)")
    end
end)

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

local function sendWebhook(title, description, color, webhookFields)
    if config.webhookUrl == "" then return end
    
    local embed = {
        ["title"] = title,
        ["description"] = description,
        ["color"] = color,
        ["fields"] = webhookFields or {},
        ["timestamp"] = DateTime.now():ToIsoDate(),
        ["footer"] = {["text"] = "Vicious Bee Hunter | " .. player.Name}
    }
    
    local success, err = pcall(function()
        request({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["embeds"] = {embed}, ["content"] = "@everyone"})
        })
    end)
    
    if not success then
        warn("Webhook failed:", err)
    end
end

local function getClosestField(position)
    local closestField = "Unknown"
    local closestDistance = math.huge
    
    for fieldName, fieldPos in pairs(fields) do
        local dist = (position - fieldPos).Magnitude
        if dist < closestDistance then
            closestDistance = dist
            closestField = fieldName
        end
    end
    
    return closestField, closestDistance
end

-- SMART DETECTION: Only alert ONCE per spawn event (prevents triple notifications)
local function onNewObject(obj)
    if not config.isRunning then return end

    task.wait(0.05) -- let object fully load

    if not obj or not obj.Parent then return end
    if not obj:IsA("BasePart") then return end
    
    -- CRITICAL CHECK: Must be named "Thorn"
    if obj.Name ~= "Thorn" then return end

    -- Check if object is close to any field
    local field, distance = getClosestField(obj.Position)
    if field == "Unknown" or distance > 150 then
        return -- ignore objects far from fields
    end

    -- COOLDOWN CHECK: Prevent multiple detections in quick succession
    local currentTime = tick()
    if currentTime - config.lastDetectionTime < config.detectionCooldown then
        print("⏳ Detection cooldown active, ignoring duplicate Thorn...")
        return
    end

    -- Avoid duplicate detections of the same object
    if config._detectedStingers[obj] then return end

    -- Mark object as detected
    config._detectedStingers[obj] = true
    config.stingerDetected = true
    config.currentField = field
    config.detectionCount = config.detectionCount + 1
    config.lastDetectionTime = currentTime

    -- Calculate player distance
    local playerDistance = "Unknown"
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            playerDistance = math.floor((hrp.Position - obj.Position).Magnitude) .. " studs"
        end
    end

    -- Generate join link
    local placeId = game.PlaceId
    local jobId = game.JobId
    local joinLink = string.format("https://www.roblox.com/games/start?placeId=%s&launchData=%%7B%%22gameInstanceId%%22%%3A%%22%s%%22%%7D", placeId, jobId)
    
    -- Send webhook alert with @everyone ping
    sendWebhook(
        "🎯 VICIOUS BEE STINGER DETECTED!",
        "🚨 A Thorn part (stinger) has spawned! Go collect it NOW!\n\n**Click the link below to join this server instantly!**",
        0xFF0000,
        {
            { name = "📦 Object Name", value = obj.Name, inline = true },
            { name = "🔧 Type", value = obj.ClassName, inline = true },
            { name = "📍 Field", value = config.currentField, inline = true },
            { name = "📏 Field Distance", value = math.floor(distance) .. " studs", inline = true },
            { name = "👤 Player Distance", value = playerDistance, inline = true },
            { name = "📐 Size", value = string.format("%.1f, %.1f, %.1f", obj.Size.X, obj.Size.Y, obj.Size.Z), inline = false },
            { name = "🧭 Position", value = string.format("(%.1f, %.1f, %.1f)", obj.Position.X, obj.Position.Y, obj.Position.Z), inline = false },
            { name = "🔗 Join Server", value = "[**CLICK HERE TO JOIN THIS SERVER**](" .. joinLink .. ")", inline = false },
            { name = "🌐 Server ID", value = game.JobId, inline = false },
            { name = "🔢 Detection #", value = tostring(config.detectionCount), inline = true }
        }
    )

    print("🎯 VICIOUS BEE STINGER DETECTED!")
    print("📍 Field:", config.currentField)
    print("📏 Distance from field:", math.floor(distance), "studs")
    print("🔢 Detection count:", config.detectionCount)

    -- Clean up if removed
    obj.AncestryChanged:Connect(function()
        if not obj.Parent then
            print("⚠️ Stinger removed from workspace")
            config._detectedStingers[obj] = nil
            -- Don't reset stingerDetected or currentField immediately
            -- Wait 3 seconds before clearing
            task.wait(3)
            config.stingerDetected = false
            config.currentField = "None"
        end
    end)
end

local function createGUI()
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
    local InfoLabel = Instance.new("TextLabel")
    local CloseButton = Instance.new("TextButton")
    local PositionLabel = Instance.new("TextLabel")
    local DetectionCountLabel = Instance.new("TextLabel")
    local AntiIdleLabel = Instance.new("TextLabel")
    
    ScreenGui.Name = "ViciousBeeHunterGUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -190)
    MainFrame.Size = UDim2.new(0, 400, 0, 380)
    MainFrame.Active = true
    MainFrame.Draggable = true
    
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
    
    Title.Parent = MainFrame
    Title.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🐝 Vicious Bee Detector v3.2"
    Title.TextColor3 = Color3.fromRGB(20, 20, 20)
    Title.TextSize = 17
    
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)
    
    CloseButton.Parent = MainFrame
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    CloseButton.Position = UDim2.new(1, -35, 0, 10)
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 16
    
    Instance.new("UICorner", CloseButton)
    
    WebhookBox.Parent = MainFrame
    WebhookBox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    WebhookBox.Position = UDim2.new(0, 20, 0, 70)
    WebhookBox.Size = UDim2.new(1, -40, 0, 40)
    WebhookBox.Font = Enum.Font.Gotham
    WebhookBox.PlaceholderText = "Enter Discord Webhook URL..."
    WebhookBox.Text = config.webhookUrl
    WebhookBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookBox.TextSize = 14
    WebhookBox.ClearTextOnFocus = false
    
    Instance.new("UICorner", WebhookBox).CornerRadius = UDim.new(0, 8)
    
    StartButton.Parent = MainFrame
    StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    StartButton.Position = UDim2.new(0, 20, 0, 125)
    StartButton.Size = UDim2.new(1, -40, 0, 45)
    StartButton.Font = Enum.Font.GothamBold
    StartButton.Text = "START DETECTING"
    StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartButton.TextSize = 16
    
    Instance.new("UICorner", StartButton).CornerRadius = UDim.new(0, 8)
    
    StatusLabel.Parent = MainFrame
    StatusLabel.Name = "StatusLabel"
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 20, 0, 185)
    StatusLabel.Size = UDim2.new(1, -40, 0, 25)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    FieldLabel.Parent = MainFrame
    FieldLabel.Name = "FieldLabel"
    FieldLabel.BackgroundTransparency = 1
    FieldLabel.Position = UDim2.new(0, 20, 0, 210)
    FieldLabel.Size = UDim2.new(1, -40, 0, 25)
    FieldLabel.Font = Enum.Font.Gotham
    FieldLabel.Text = "Field: Waiting..."
    FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    FieldLabel.TextSize = 13
    FieldLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    DetectionCountLabel.Parent = MainFrame
    DetectionCountLabel.Name = "DetectionCountLabel"
    DetectionCountLabel.BackgroundTransparency = 1
    DetectionCountLabel.Position = UDim2.new(0, 20, 0, 235)
    DetectionCountLabel.Size = UDim2.new(1, -40, 0, 25)
    DetectionCountLabel.Font = Enum.Font.Gotham
    DetectionCountLabel.Text = "Detections: 0"
    DetectionCountLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    DetectionCountLabel.TextSize = 13
    DetectionCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    AntiIdleLabel.Parent = MainFrame
    AntiIdleLabel.Name = "AntiIdleLabel"
    AntiIdleLabel.BackgroundTransparency = 1
    AntiIdleLabel.Position = UDim2.new(0, 20, 0, 260)
    AntiIdleLabel.Size = UDim2.new(1, -40, 0, 25)
    AntiIdleLabel.Font = Enum.Font.Gotham
    AntiIdleLabel.Text = "🔄 Anti-Idle: Active"
    AntiIdleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    AntiIdleLabel.TextSize = 13
    AntiIdleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    InfoLabel.Parent = MainFrame
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Position = UDim2.new(0, 20, 0, 290)
    InfoLabel.Size = UDim2.new(1, -40, 0, 45)
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.Text = "💡 Detects 'Thorn' parts once per spawn (no duplicates)"
    InfoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    InfoLabel.TextSize = 11
    InfoLabel.TextWrapped = true
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Left

    PositionLabel.Name = "PositionLabel"
    PositionLabel.Parent = MainFrame
    PositionLabel.BackgroundTransparency = 1
    PositionLabel.Position = UDim2.new(0, 20, 0, 345)
    PositionLabel.Size = UDim2.new(1, -40, 0, 25)
    PositionLabel.Font = Enum.Font.Gotham
    PositionLabel.Text = "Position: Waiting..."
    PositionLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    PositionLabel.TextSize = 13
    PositionLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    StartButton.MouseButton1Click:Connect(function()
        if not config.isRunning then
            local webhook = WebhookBox.Text
            if webhook == "" or not webhook:match("^https://discord%.com/api/webhooks/") then
                StatusLabel.Text = "Status: ❌ Invalid Webhook URL"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                return
            end
            
            config.webhookUrl = webhook
            
            if writefile then
                writefile("vicious_bee_webhook.txt", webhook)
                print("✅ Webhook saved")
            end
            
            config.isRunning = true
            
            -- Connect the listener for new objects EVERYWHERE in the game
            if not config._descendantConnection then
                config._descendantConnection = game.DescendantAdded:Connect(onNewObject)
                print("✅ Monitoring entire game for 'Thorn' parts...")
            end
            
            StartButton.Text = "STOP DETECTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            StatusLabel.Text = "Status: 👀 Watching for 'Thorn' parts..."
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            sendWebhook(
                "🚀 Detection Started", 
                "Now monitoring for Vicious Bee stinger spawns (Thorn parts) in this server! Anti-idle is active.", 
                0x00AAFF, 
                {{name = "🌐 Server ID", value = game.JobId, inline = false}}
            )
            
            print("🎯 DETECTION ACTIVE - Watching for 'Thorn' parts near fields...")
            print("🔄 Anti-idle system is active!")
        else
            config.isRunning = false
            
            if config._descendantConnection then
                config._descendantConnection:Disconnect()
                config._descendantConnection = nil
                print("✅ Stopped monitoring")
            end
            
            StartButton.Text = "START DETECTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            StatusLabel.Text = "Status: Stopped"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            FieldLabel.Text = "Field: Waiting..."
            FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end)
    
    CloseButton.MouseButton1Click:Connect(function()
        config.isRunning = false
        if config._descendantConnection then
            config._descendantConnection:Disconnect()
        end
        ScreenGui:Destroy()
    end)
    
    -- Update GUI labels in real-time
    RunService.RenderStepped:Connect(function()
        local gui = CoreGui:FindFirstChild("ViciousBeeHunterGUI")
        if not gui then return end
        
        local mainFrame = gui:FindFirstChild("MainFrame")
        if not mainFrame then return end
        
        -- Update position
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            local posLabel = mainFrame:FindFirstChild("PositionLabel")
            if posLabel then
                posLabel.Text = string.format("Position: (%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z)
            end
        end
        
        -- Update field and detection count
        local fieldLabel = mainFrame:FindFirstChild("FieldLabel")
        if fieldLabel and config.stingerDetected then
            fieldLabel.Text = "Field: 🎯 " .. config.currentField
            fieldLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        end
        
        local countLabel = mainFrame:FindFirstChild("DetectionCountLabel")
        if countLabel then
            countLabel.Text = "Detections: " .. config.detectionCount
        end
    end)
end

print("🐝 Vicious Bee Stinger Detector v3.2 Loaded!")
print("📱 Opening GUI...")
print("🎯 This script detects 'Thorn' parts spawning near fields!")
print("🔄 Anti-idle system enabled!")
createGUI()
