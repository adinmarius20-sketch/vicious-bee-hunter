-- Vicious Bee Stinger Hunter Script v3.6 - SECURED WITH WEBHOOK TOKEN
-- Detects "Thorn" parts (Size: 3×2×1.5) that spawn near fields (ONCE per spawn event)

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
    pcServerUrl = "", -- Your PC's HTTP server URL (e.g., http://192.168.1.100:8080/log)
    webhookSecret = "your_secret_webhook_token_here_change_this_12345", -- MUST MATCH SERVER!
    isRunning = false,
    stingerDetected = false,
    currentField = "None",
    _descendantConnection = nil,
    _detectedStingers = {},
    detectionCount = 0,
    lastDetectionTime = 0,
    detectionCooldown = 5,
    serverType = "Public",
    privateServerLink = "",
    expectedSize = Vector3.new(3.0, 2.0, 1.5),
    sizeTolerance = 0.1,
    stingerActiveTime = 240, -- 4 minutes in seconds
    _activeStatusTimer = nil
}

-- Load saved webhook
if isfile and readfile and isfile("vicious_bee_webhook.txt") then
    local saved = readfile("vicious_bee_webhook.txt")
    if saved and saved ~= "" then
        config.webhookUrl = saved
        print("✅ Loaded saved webhook")
    end
end

-- Load saved PC server URL
if isfile and readfile and isfile("vicious_bee_pcserver.txt") then
    local saved = readfile("vicious_bee_pcserver.txt")
    if saved and saved ~= "" then
        config.pcServerUrl = saved
        print("✅ Loaded saved PC server URL")
    end
end

-- Load saved webhook secret
if isfile and readfile and isfile("vicious_bee_secret.txt") then
    local saved = readfile("vicious_bee_secret.txt")
    if saved and saved ~= "" then
        config.webhookSecret = saved
        print("✅ Loaded saved webhook secret")
    end
end

-- Load saved server type and private link
if isfile and readfile and isfile("vicious_bee_serverconfig.txt") then
    local success, result = pcall(function()
        local saved = readfile("vicious_bee_serverconfig.txt")
        if saved and saved ~= "" then
            return HttpService:JSONDecode(saved)
        end
    end)
    if success and result then
        config.serverType = result.serverType or "Public"
        config.privateServerLink = result.privateServerLink or ""
        print("✅ Loaded saved server config:", config.serverType)
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
        wait(600)
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

local function verifySizeMatch(objSize)
    return math.abs(objSize.X - config.expectedSize.X) <= config.sizeTolerance and
           math.abs(objSize.Y - config.expectedSize.Y) <= config.sizeTolerance and
           math.abs(objSize.Z - config.expectedSize.Z) <= config.sizeTolerance
end

local function generateJoinLink()
    -- Generate proper clickable join link
    if config.serverType == "Private" and config.privateServerLink ~= "" then
        return config.privateServerLink
    else
        local placeId = game.PlaceId
        local jobId = game.JobId
        -- Use Roblox's deep link format that actually works
        return string.format("roblox://experiences/start?placeId=%d&gameInstanceId=%s", placeId, jobId)
    end
end

local function updateStingerLog(playerName, field, status, joinLink)
    -- Send to PC server if URL is configured
    if config.pcServerUrl ~= "" then
        local logData = {
            player = playerName,
            field = field,
            status = status,
            timestamp = os.time(),
            detectionTime = os.time(),
            serverLink = joinLink or "N/A"
        }
        
        local success, err = pcall(function()
            request({
                Url = config.pcServerUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-Webhook-Token"] = config.webhookSecret -- SEND SECRET TOKEN!
                },
                Body = HttpService:JSONEncode(logData)
            })
        end)
        
        if success then
            print("✅ Log sent to PC server (SECURE):", playerName, "-", field, "-", status)
        else
            warn("❌ Failed to send log to PC:", err)
        end
    end
    
    -- Still save locally as backup
    if not writefile or not readfile or not isfile then
        return
    end
    
    local logData = {}
    
    if isfile("vicious_bee_stinger_log.txt") then
        local success, result = pcall(function()
            local content = readfile("vicious_bee_stinger_log.txt")
            if content and content ~= "" then
                return HttpService:JSONDecode(content)
            end
        end)
        if success and result then
            logData = result
        end
    end
    
    local timestamp = os.time()
    logData[playerName] = {
        Field = field,
        Status = status,
        LastUpdate = timestamp,
        DetectionTime = logData[playerName] and logData[playerName].DetectionTime or timestamp,
        ServerLink = joinLink or "N/A"
    }
    
    pcall(function()
        writefile("vicious_bee_stinger_log.txt", HttpService:JSONEncode(logData, true))
    end)
end

local function formatLogToReadable()
    if not readfile or not isfile or not isfile("vicious_bee_stinger_log.txt") then
        return "No log file found"
    end
    
    local success, logData = pcall(function()
        local content = readfile("vicious_bee_stinger_log.txt")
        if content and content ~= "" then
            return HttpService:JSONDecode(content)
        end
    end)
    
    if not success or not logData then
        return "Failed to read log file"
    end
    
    local output = "=== VICIOUS BEE STINGER LOG ===\n\n"
    local currentTime = os.time()
    
    for playerName, data in pairs(logData) do
        output = output .. "Player: " .. playerName .. "\n"
        output = output .. "Field: " .. data.Field .. "\n"
        
        -- Check if 4 minutes have passed since detection
        local timeSinceDetection = currentTime - (data.DetectionTime or 0)
        local status = (timeSinceDetection < config.stingerActiveTime) and "ACTIVE" or "NOT ACTIVE"
        
        output = output .. "Status: " .. status .. "\n"
        
        if status == "ACTIVE" then
            local remainingTime = config.stingerActiveTime - timeSinceDetection
            output = output .. "Time Remaining: " .. math.floor(remainingTime / 60) .. "m " .. (remainingTime % 60) .. "s\n"
        end
        
        output = output .. "Server Link: " .. (data.ServerLink or "N/A") .. "\n"
        output = output .. "\n"
    end
    
    return output
end

-- Auto-update status every 30 seconds
spawn(function()
    while true do
        wait(30)
        if readfile and isfile and writefile and isfile("vicious_bee_stinger_log.txt") then
            local success, logData = pcall(function()
                local content = readfile("vicious_bee_stinger_log.txt")
                if content and content ~= "" then
                    return HttpService:JSONDecode(content)
                end
            end)
            
            if success and logData then
                local currentTime = os.time()
                local updated = false
                
                for playerName, data in pairs(logData) do
                    local timeSinceDetection = currentTime - (data.DetectionTime or 0)
                    local newStatus = (timeSinceDetection < config.stingerActiveTime) and "ACTIVE" or "NOT ACTIVE"
                    
                    if data.Status ~= newStatus then
                        data.Status = newStatus
                        data.LastUpdate = currentTime
                        updated = true
                    end
                end
                
                if updated then
                    pcall(function()
                        writefile("vicious_bee_stinger_log.txt", HttpService:JSONEncode(logData, true))
                        print("🔄 Stinger log statuses updated")
                    end)
                end
            end
        end
    end
end)

-- SMART DETECTION: Only alert ONCE per spawn event with size verification
local function onNewObject(obj)
    if not config.isRunning then return end

    task.wait(0.05)

    if not obj or not obj.Parent then return end
    if not obj:IsA("BasePart") then return end
    
    -- Must be named "Thorn"
    if obj.Name ~= "Thorn" then return end
    
    -- SIZE VERIFICATION: Must match stinger dimensions (3.0, 2.0, 1.5)
    if not verifySizeMatch(obj.Size) then
        print("⚠️ Ignored 'Thorn' with wrong size:", string.format("%.2f×%.2f×%.2f", obj.Size.X, obj.Size.Y, obj.Size.Z))
        return
    end

    -- Check if object is close to any field
    local field, distance = getClosestField(obj.Position)
    if field == "Unknown" or distance > 150 then
        return
    end

    -- COOLDOWN CHECK
    local currentTime = tick()
    if currentTime - config.lastDetectionTime < config.detectionCooldown then
        print("⏳ Detection cooldown active, ignoring duplicate Thorn...")
        return
    end

    -- Avoid duplicate detections
    if config._detectedStingers[obj] then return end

    -- Mark object as detected
    config._detectedStingers[obj] = true
    config.stingerDetected = true
    config.currentField = field
    config.detectionCount = config.detectionCount + 1
    config.lastDetectionTime = currentTime

    -- Generate join link
    local joinLink = generateJoinLink()
    local serverTypeText = config.serverType == "Private" and "🔒 Private Server" or "🌐 Public Server"

    -- Update log file with ACTIVE status and server link (SECURE WITH TOKEN)
    updateStingerLog(player.Name, field, "ACTIVE", joinLink)
    
    -- Set timer to change status to NOT ACTIVE after 4 minutes
    if config._activeStatusTimer then
        task.cancel(config._activeStatusTimer)
    end
    
    config._activeStatusTimer = task.delay(config.stingerActiveTime, function()
        updateStingerLog(player.Name, field, "NOT ACTIVE", joinLink)
        print("⏰ Stinger status changed to NOT ACTIVE (4 minutes passed)")
    end)

    -- Calculate player distance
    local playerDistance = "Unknown"
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            playerDistance = math.floor((hrp.Position - obj.Position).Magnitude) .. " studs"
        end
    end
    
    -- Send webhook alert with @everyone ping and CLICKABLE link
    sendWebhook(
        "🎯 VICIOUS BEE STINGER DETECTED!",
        "🚨 A stinger was found!\n\n**🔗 [CLICK HERE TO JOIN THIS SERVER](" .. joinLink .. ")**",
        0xFF0000,
        {
            { name = "📦 Object Name", value = obj.Name, inline = true },
            { name = "🔧 Type", value = obj.ClassName, inline = true },
            { name = "📍 Field", value = config.currentField, inline = true },
            { name = "📏 Field Distance", value = math.floor(distance) .. " studs", inline = true },
            { name = "👤 Player Distance", value = playerDistance, inline = true },
            { name = "🖥️ Server Type", value = serverTypeText, inline = true },
            { name = "📐 Size", value = string.format("%.1f×%.1f×%.1f", obj.Size.X, obj.Size.Y, obj.Size.Z), inline = true },
            { name = "✅ Size Verified", value = "Matches stinger (3×2×1.5)", inline = true },
            { name = "🧭 Position", value = string.format("(%.1f, %.1f, %.1f)", obj.Position.X, obj.Position.Y, obj.Position.Z), inline = false },
            { name = "🔢 Detection #", value = tostring(config.detectionCount), inline = true }
        }
    )

    print("🎯 VICIOUS BEE STINGER DETECTED!")
    print("📍 Field:", config.currentField)
    print("📏 Distance from field:", math.floor(distance), "studs")
    print("📐 Size:", string.format("%.1f×%.1f×%.1f", obj.Size.X, obj.Size.Y, obj.Size.Z))
    print("✅ Size verified: Matches stinger dimensions")
    print("🖥️ Server Type:", serverTypeText)
    print("🔗 Join Link:", joinLink)
    print("🔢 Detection count:", config.detectionCount)
    print("🔐 Log sent with webhook secret token")

    -- Clean up if removed
    obj.AncestryChanged:Connect(function()
        if not obj.Parent then
            print("⚠️ Stinger removed from workspace")
            config._detectedStingers[obj] = nil
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
    local PCServerBox = Instance.new("TextBox")
    local PCServerLabel = Instance.new("TextLabel")
    local WebhookSecretBox = Instance.new("TextBox")
    local WebhookSecretLabel = Instance.new("TextLabel")
    local ServerTypeLabel = Instance.new("TextLabel")
    local PublicButton = Instance.new("TextButton")
    local PrivateButton = Instance.new("TextButton")
    local PrivateServerBox = Instance.new("TextBox")
    local StartButton = Instance.new("TextButton")
    local StatusLabel = Instance.new("TextLabel")
    local FieldLabel = Instance.new("TextLabel")
    local InfoLabel = Instance.new("TextLabel")
    local CloseButton = Instance.new("TextButton")
    local PositionLabel = Instance.new("TextLabel")
    local DetectionCountLabel = Instance.new("TextLabel")
    local AntiIdleLabel = Instance.new("TextLabel")
    local ViewLogButton = Instance.new("TextButton")
    
    ScreenGui.Name = "ViciousBeeHunterGUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -350)
    MainFrame.Size = UDim2.new(0, 400, 0, 700)
    MainFrame.Active = true
    MainFrame.Draggable = true
    
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
    
    Title.Parent = MainFrame
    Title.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🐝 Vicious Bee Detector v3.6 🔐"
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
    
    PCServerLabel.Parent = MainFrame
    PCServerLabel.BackgroundTransparency = 1
    PCServerLabel.Position = UDim2.new(0, 20, 0, 120)
    PCServerLabel.Size = UDim2.new(1, -40, 0, 20)
    PCServerLabel.Font = Enum.Font.GothamBold
    PCServerLabel.Text = "PC Server URL (for log file):"
    PCServerLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    PCServerLabel.TextSize = 12
    PCServerLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    PCServerBox.Parent = MainFrame
    PCServerBox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    PCServerBox.Position = UDim2.new(0, 20, 0, 145)
    PCServerBox.Size = UDim2.new(1, -40, 0, 40)
    PCServerBox.Font = Enum.Font.Gotham
    PCServerBox.PlaceholderText = "https://YOUR-NGROK-URL.ngrok-free.app/log"
    PCServerBox.Text = config.pcServerUrl
    PCServerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    PCServerBox.TextSize = 13
    PCServerBox.ClearTextOnFocus = false
    
    Instance.new("UICorner", PCServerBox).CornerRadius = UDim.new(0, 8)
    
    WebhookSecretLabel.Parent = MainFrame
    WebhookSecretLabel.BackgroundTransparency = 1
    WebhookSecretLabel.Position = UDim2.new(0, 20, 0, 195)
    WebhookSecretLabel.Size = UDim2.new(1, -40, 0, 20)
    WebhookSecretLabel.Font = Enum.Font.GothamBold
    WebhookSecretLabel.Text = "🔐 Webhook Secret Token:"
    WebhookSecretLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    WebhookSecretLabel.TextSize = 12
    WebhookSecretLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    WebhookSecretBox.Parent = MainFrame
    WebhookSecretBox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    WebhookSecretBox.Position = UDim2.new(0, 20, 0, 220)
    WebhookSecretBox.Size = UDim2.new(1, -40, 0, 40)
    WebhookSecretBox.Font = Enum.Font.Gotham
    WebhookSecretBox.PlaceholderText = "Enter secret token (must match server)..."
    WebhookSecretBox.Text = config.webhookSecret
    WebhookSecretBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookSecretBox.TextSize = 13
    WebhookSecretBox.ClearTextOnFocus = false
    
    Instance.new("UICorner", WebhookSecretBox).CornerRadius = UDim.new(0, 8)
    
    ServerTypeLabel.Parent = MainFrame
    ServerTypeLabel.BackgroundTransparency = 1
    ServerTypeLabel.Position = UDim2.new(0, 20, 0, 275)
    ServerTypeLabel.Size = UDim2.new(1, -40, 0, 20)
    ServerTypeLabel.Font = Enum.Font.GothamBold
    ServerTypeLabel.Text = "Server Type:"
    ServerTypeLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
    ServerTypeLabel.TextSize = 13
    ServerTypeLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    PublicButton.Parent = MainFrame
    PublicButton.BackgroundColor3 = config.serverType == "Public" and Color3.fromRGB(50, 150, 255) or Color3.fromRGB(60, 60, 65)
    PublicButton.Position = UDim2.new(0, 20, 0, 300)
    PublicButton.Size = UDim2.new(0.48, -15, 0, 35)
    PublicButton.Font = Enum.Font.GothamBold
    PublicButton.Text = "🌐 Public Server"
    PublicButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PublicButton.TextSize = 14
    
    Instance.new("UICorner", PublicButton).CornerRadius = UDim.new(0, 8)
    
    PrivateButton.Parent = MainFrame
    PrivateButton.BackgroundColor3 = config.serverType == "Private" and Color3.fromRGB(50, 150, 255) or Color3.fromRGB(60, 60, 65)
    PrivateButton.Position = UDim2.new(0.52, 5, 0, 300)
    PrivateButton.Size = UDim2.new(0.48, -15, 0, 35)
    PrivateButton.Font = Enum.Font.GothamBold
    PrivateButton.Text = "🔒 Private Server"
    PrivateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrivateButton.TextSize = 14
    
    Instance.new("UICorner", PrivateButton).CornerRadius = UDim.new(0, 8)
    
    PrivateServerBox.Parent = MainFrame
    PrivateServerBox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    PrivateServerBox.Position = UDim2.new(0, 20, 0, 345)
    PrivateServerBox.Size = UDim2.new(1, -40, 0, 40)
    PrivateServerBox.Font = Enum.Font.Gotham
    PrivateServerBox.PlaceholderText = "Paste Private Server Link Here..."
    PrivateServerBox.Text = config.privateServerLink
    PrivateServerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrivateServerBox.TextSize = 13
    PrivateServerBox.ClearTextOnFocus = false
    PrivateServerBox.Visible = config.serverType == "Private"
    
    Instance.new("UICorner", PrivateServerBox).CornerRadius = UDim.new(0, 8)
    
    StartButton.Parent = MainFrame
    StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    StartButton.Position = UDim2.new(0, 20, 0, 395)
    StartButton.Size = UDim2.new(1, -40, 0, 45)
    StartButton.Font = Enum.Font.GothamBold
    StartButton.Text = "START DETECTING"
    StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartButton.TextSize = 16
    
    Instance.new("UICorner", StartButton).CornerRadius = UDim.new(0, 8)
    
    StatusLabel.Parent = MainFrame
    StatusLabel.Name = "StatusLabel"
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 20, 0, 455)
    StatusLabel.Size = UDim2.new(1, -40, 0, 25)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    FieldLabel.Parent = MainFrame
    FieldLabel.Name = "FieldLabel"
    FieldLabel.BackgroundTransparency = 1
    FieldLabel.Position = UDim2.new(0, 20, 0, 480)
    FieldLabel.Size = UDim2.new(1, -40, 0, 25)
    FieldLabel.Font = Enum.Font.Gotham
    FieldLabel.Text = "Field: Waiting..."
    FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    FieldLabel.TextSize = 13
    FieldLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    DetectionCountLabel.Parent = MainFrame
    DetectionCountLabel.Name = "DetectionCountLabel"
    DetectionCountLabel.BackgroundTransparency = 1
    DetectionCountLabel.Position = UDim2.new(0, 20, 0, 505)
    DetectionCountLabel.Size = UDim2.new(1, -40, 0, 25)
    DetectionCountLabel.Font = Enum.Font.Gotham
    DetectionCountLabel.Text = "Detections: 0"
    DetectionCountLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    DetectionCountLabel.TextSize = 13
    DetectionCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    AntiIdleLabel.Parent = MainFrame
    AntiIdleLabel.Name = "AntiIdleLabel"
    AntiIdleLabel.BackgroundTransparency = 1
    AntiIdleLabel.Position = UDim2.new(0, 20, 0, 530)
    AntiIdleLabel.Size = UDim2.new(1, -40, 0, 25)
    AntiIdleLabel.Font = Enum.Font.Gotham
    AntiIdleLabel.Text = "🔄 Anti-Idle: Active"
    AntiIdleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    AntiIdleLabel.TextSize = 13
    AntiIdleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    InfoLabel.Parent = MainFrame
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Position = UDim2.new(0, 20, 0, 560)
    InfoLabel.Size = UDim2.new(1, -40, 0, 45)
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.Text = "🔐 Secured with webhook token | Size: 3×2×1.5"
    InfoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    InfoLabel.TextSize = 11
    InfoLabel.TextWrapped = true
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Left

    PositionLabel.Name = "PositionLabel"
    PositionLabel.Parent = MainFrame
    PositionLabel.BackgroundTransparency = 1
    PositionLabel.Position = UDim2.new(0, 20, 0, 615)
    PositionLabel.Size = UDim2.new(1, -40, 0, 25)
    PositionLabel.Font = Enum.Font.Gotham
    PositionLabel.Text = "Position: Waiting..."
    PositionLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    PositionLabel.TextSize = 13
    PositionLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    ViewLogButton.Parent = MainFrame
    ViewLogButton.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
    ViewLogButton.Position = UDim2.new(0, 20, 0, 650)
    ViewLogButton.Size = UDim2.new(1, -40, 0, 35)
    ViewLogButton.Font = Enum.Font.GothamBold
    ViewLogButton.Text = "📋 VIEW STINGER LOG"
    ViewLogButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ViewLogButton.TextSize = 14
    
    Instance.new("UICorner", ViewLogButton).CornerRadius = UDim.new(0, 8)
    
    -- Button handlers
    PublicButton.MouseButton1Click:Connect(function()
        config.serverType = "Public"
        PublicButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        PrivateButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        PrivateServerBox.Visible = false
        
        if writefile then
            writefile("vicious_bee_serverconfig.txt", HttpService:JSONEncode({
                serverType = config.serverType,
                privateServerLink = config.privateServerLink
            }))
            print("✅ Server type set to Public")
        end
    end)
    
    PrivateButton.MouseButton1Click:Connect(function()
        config.serverType = "Private"
        PrivateButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        PublicButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        PrivateServerBox.Visible = true
        
        if writefile then
            writefile("vicious_bee_serverconfig.txt", HttpService:JSONEncode({
                serverType = config.serverType,
                privateServerLink = config.privateServerLink
            }))
            print("✅ Server type set to Private")
        end
    end)
    
    PrivateServerBox.FocusLost:Connect(function()
        config.privateServerLink = PrivateServerBox.Text
        if writefile then
            writefile("vicious_bee_serverconfig.txt", HttpService:JSONEncode({
                serverType = config.serverType,
                privateServerLink = config.privateServerLink
            }))
            print("✅ Private server link saved")
        end
    end)
    
    WebhookBox.FocusLost:Connect(function()
        if writefile then
            writefile("vicious_bee_webhook.txt", WebhookBox.Text)
        end
    end)
    
    PCServerBox.FocusLost:Connect(function()
        config.pcServerUrl = PCServerBox.Text
        if writefile then
            writefile("vicious_bee_pcserver.txt", PCServerBox.Text)
            print("✅ PC server URL saved:", config.pcServerUrl)
        end
    end)
    
    WebhookSecretBox.FocusLost:Connect(function()
        config.webhookSecret = WebhookSecretBox.Text
        if writefile then
            writefile("vicious_bee_secret.txt", WebhookSecretBox.Text)
            print("✅ Webhook secret saved (KEEP THIS SECRET!)")
        end
    end)
    
    StartButton.MouseButton1Click:Connect(function()
        if not config.isRunning then
            local webhook = WebhookBox.Text
            if webhook == "" or not webhook:match("^https://discord%.com/api/webhooks/") then
                StatusLabel.Text = "Status: ❌ Invalid Webhook URL"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                return
            end
            
            if config.webhookSecret == "" or config.webhookSecret == "your_secret_webhook_token_here_change_this_12345" then
                StatusLabel.Text = "Status: ❌ Set webhook secret token first!"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                return
            end
            
            if config.serverType == "Private" and (config.privateServerLink == "" or not config.privateServerLink:match("^https://")) then
                StatusLabel.Text = "Status: ❌ Invalid Private Server Link"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                return
            end
            
            config.webhookUrl = webhook
            
            if writefile then
                writefile("vicious_bee_webhook.txt", webhook)
                print("✅ Webhook saved")
            end
            
            config.isRunning = true
            
            if not config._descendantConnection then
                config._descendantConnection = game.DescendantAdded:Connect(onNewObject)
                print("✅ Monitoring entire game for 'Thorn' parts with size 3×2×1.5...")
            end
            
            StartButton.Text = "STOP DETECTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            StatusLabel.Text = "Status: 👀 Watching (SECURED)"
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            local serverTypeText = config.serverType == "Private" and "🔒 Private Server" or "🌐 Public Server"
            
            sendWebhook(
                "🚀 Detection Started", 
                "Now monitoring for Vicious Bee stinger spawns! Anti-idle is active. 🔐 Secured with webhook token.", 
                0x00AAFF, 
                {
                    {name = "🖥️ Server Type", value = serverTypeText, inline = true},
                    {name = "📐 Target Size", value = "3.0×2.0×1.5", inline = true},
                    {name = "🔐 Security", value = "Webhook Token Active", inline = true}
                }
            )
            
            print("🎯 DETECTION ACTIVE - Watching for 'Thorn' parts with size 3×2×1.5...")
            print("🔄 Anti-idle system is active!")
            print("🖥️ Server Type:", serverTypeText)
            print("🔐 Webhook secret token is configured")
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
        if config._activeStatusTimer then
            task.cancel(config._activeStatusTimer)
        end
        ScreenGui:Destroy()
    end)
    
    ViewLogButton.MouseButton1Click:Connect(function()
        local logContent = formatLogToReadable()
        print("\n" .. logContent)
        
        StatusLabel.Text = "Status: 📋 Log printed to console!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
        
        task.wait(2)
        if config.isRunning then
            StatusLabel.Text = "Status: 👀 Watching (SECURED)"
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            StatusLabel.Text = "Status: Idle"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end)
    
    -- Update GUI labels in real-time
    RunService.RenderStepped:Connect(function()
        local gui = CoreGui:FindFirstChild("ViciousBeeHunterGUI")
        if not gui then return end
        
        local mainFrame = gui:FindFirstChild("MainFrame")
        if not mainFrame then return end
        
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            local posLabel = mainFrame:FindFirstChild("PositionLabel")
            if posLabel then
                posLabel.Text = string.format("Position: (%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z)
            end
        end
        
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

print("🐝 Vicious Bee Stinger Detector v3.6 Loaded!")
print("📱 Opening GUI...")
print("🎯 This script detects 'Thorn' parts (Size: 3×2×1.5) spawning near fields!")
print("🔄 Anti-idle system enabled!")
print("🖥️ Server Type:", config.serverType)
print("✅ Size verification active: Only detects stingers with exact size 3.0×2.0×1.5")
print("🔐 SECURITY: Webhook secret token system enabled!")
print("⚠️  IMPORTANT: Set your webhook secret token before starting!")
createGUI()
