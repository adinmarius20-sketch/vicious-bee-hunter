-- Vicious Bee Stinger Hunter Script v2 - FIXED
-- Compatible with Delta Executor

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local request = request or http_request or syn.request

local player = Players.LocalPlayer
local PLACE_ID = 1537690962

local SCRIPT_RAW_URL = "https://raw.githubusercontent.com/adinmarius20-sketch/vicious-bee-hunter/main/script.lua"

local function queueScript()
    if queue_on_teleport then
        queue_on_teleport([[ loadstring(game:HttpGet("]] .. SCRIPT_RAW_URL .. [["))() ]])
    elseif syn and syn.queue_on_teleport then
        syn.queue_on_teleport([[ loadstring(game:HttpGet("]] .. SCRIPT_RAW_URL .. [["))() ]])
    end
end

local config = {
    webhookUrl = "",
    checkInterval = 3,
    serverHopDelay = 8,
    isRunning = false,
    stingerDetected = false,
    currentField = "None"
}

-- Load saved webhook
if isfile and readfile and isfile("vicious_bee_webhook.txt") then
    local saved = readfile("vicious_bee_webhook.txt")
    if saved and saved ~= "" then
        config.webhookUrl = saved
        print("✅ Loaded saved webhook")
    end
end

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
            Body = HttpService:JSONEncode({["embeds"] = {embed}})
        })
    end)
    
    if not success then
        warn("Webhook failed:", err)
    end
end

-- FIXED: Improved stinger detection
local function findStingerData()
    -- Search all workspace descendants for Stinger object
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Stinger" then
            local fieldName = "Unknown"
            local parent = obj.Parent
            
            -- Check parent chain for field name
            while parent and parent ~= Workspace do
                if fields[parent.Name] then
                    fieldName = parent.Name
                    break
                end
                parent = parent.Parent
            end
            
            -- If unknown, find closest field by distance (increased range)
            if fieldName == "Unknown" then
                local closestField = nil
                local closestDistance = math.huge
                
                for name, pos in pairs(fields) do
                    local distance = (obj.Position - pos).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestField = name
                    end
                end
                
                -- Increased range to 300 studs to catch more fields
                if closestField and closestDistance < 300 then
                    -- Only accept if it's a valid Vicious Bee spawn field
                    if validViciousFields[closestField] then
                        fieldName = closestField .. " (~" .. math.floor(closestDistance) .. " studs)"
                    else
                        print("⚠️ Stinger found near " .. closestField .. " but that's not a valid Vicious spawn field!")
                        return nil, nil -- Ignore false positives
                    end
                end
            end
            
            return obj, fieldName
        end
    end
    
    -- Check Monsters folder as backup
    local monsters = Workspace:FindFirstChild("Monsters")
    if monsters then
        for _, mob in ipairs(monsters:GetChildren()) do
            if mob.Name:lower():find("vicious") then
                local stinger = mob:FindFirstChild("Stinger", true)
                if stinger then
                    local closestField = "Unknown"
                    local closestDistance = math.huge
                    
                    for name, pos in pairs(fields) do
                        local distance = (mob:GetPivot().Position - pos).Magnitude
                        if distance < closestDistance then
                            closestDistance = distance
                            closestField = name
                        end
                    end
                    
                    -- Validate it's a real Vicious Bee spawn location
                    if closestField and validViciousFields[closestField] then
                        return stinger, closestField
                    else
                        print("⚠️ Found stinger-like object but not in valid Vicious field")
                        return nil, nil
                    end
                end
            end
        end
    end
    
    return nil, nil
end

-- FIXED: Added missing checkForStinger function
local function checkForStinger()
    local viciousPart, fieldName = findStingerData()
    
    if viciousPart then
        if not config.stingerDetected then
            config.stingerDetected = true
            config.currentField = fieldName
            
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local distance = "Unknown"
            
            if hrp then
                distance = math.floor((hrp.Position - viciousPart.Position).Magnitude) .. " studs"
            end
            
            sendWebhook(
                "🎯 VICIOUS BEE FOUND!",
                "A Vicious Bee has been detected!",
                0xFF0000,
                {
                    {name = "📍 Field", value = fieldName, inline = true},
                    {name = "📏 Distance", value = distance, inline = true},
                    {name = "🌐 Server ID", value = game.JobId, inline = false}
                }
            )
            
            -- Update GUI status
            local gui = CoreGui:FindFirstChild("ViciousBeeHunterGUI")
            if gui and gui:FindFirstChild("MainFrame") then
                local statusLabel = gui.MainFrame:FindFirstChild("StatusLabel")
                if statusLabel then
                    statusLabel.Text = "Status: 🎯 VICIOUS BEE FOUND!"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
                end
            end
            
            print("🎯 VICIOUS BEE FOUND IN:", fieldName)
        end
        return true, fieldName
    else
        -- Vicious Bee despawned or defeated
        if config.stingerDetected then
            sendWebhook(
                "✅ Vicious Bee Defeated/Despawned",
                "The Vicious Bee is no longer present. Continuing search...",
                0x00FF00,
                {
                    {name = "Previous Field", value = config.currentField, inline = true}
                }
            )
            
            config.stingerDetected = false
            config.currentField = "None"
            print("✅ Vicious Bee gone.")
        end
    end
    
    return false, nil
end

local function serverHopPublic()
    sendWebhook(
        "🔄 Server Hopping",
        "No Vicious Bee found. Searching next public server...",
        0xFFA500,
        {}
    )
    
    print("🔄 Searching for public servers...")
    
    local success = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
        local data = HttpService:JSONDecode(game:HttpGet(url))
        
        if data and data.data then
            local validServers = {}
            for _, server in pairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    table.insert(validServers, server)
                end
            end
            
            if #validServers > 0 then
                local randomServer = validServers[math.random(1, #validServers)]
                print("✅ Found server:", randomServer.id)
                queueScript()
                TeleportService:TeleportToPlaceInstance(PLACE_ID, randomServer.id, player)
                return
            end
        end
    end)
    
    if not success then
        warn("Fallback teleport")
        wait(2)
        queueScript()
        TeleportService:Teleport(PLACE_ID, player)
    end
end

local function mainLoop()
    print("🔍 Starting hunt loop...")
    
    while config.isRunning do
        print("🔎 Checking for stingers...")
        local found, fieldName = checkForStinger()
        
        if found then
            print("✅ Stinger detected! Staying in server.")
            -- Found it! Stay in this server
            wait(config.checkInterval)
        else
            print("❌ No stinger found. Waiting " .. config.serverHopDelay .. " seconds before hopping...")
            
            -- Update GUI
            local gui = CoreGui:FindFirstChild("ViciousBeeHunterGUI")
            if gui and gui:FindFirstChild("MainFrame") then
                local statusLabel = gui.MainFrame:FindFirstChild("StatusLabel")
                if statusLabel then
                    statusLabel.Text = "Status: No stinger found, hopping in " .. config.serverHopDelay .. "s..."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                end
            end
            
            wait(config.serverHopDelay)
            
            if config.isRunning and not config.stingerDetected then
                print("🔄 Server hopping now...")
                serverHopPublic()
                break
            end
        end
        
        wait(config.checkInterval)
    end
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
    local CloseButton = Instance.new("TextButton")
    local AutoStartCheckbox = Instance.new("TextButton")
    local DebugButton = Instance.new("TextButton")
    
    ScreenGui.Name = "ViciousBeeHunterGUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -180)
    MainFrame.Size = UDim2.new(0, 400, 0, 370)
    MainFrame.Active = true
    MainFrame.Draggable = true
    
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
    
    Title.Parent = MainFrame
    Title.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🐝 Vicious Bee Hunter (Public Servers)"
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
    
    AutoStartCheckbox.Parent = MainFrame
    AutoStartCheckbox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    AutoStartCheckbox.Position = UDim2.new(0, 20, 0, 120)
    AutoStartCheckbox.Size = UDim2.new(1, -40, 0, 30)
    AutoStartCheckbox.Font = Enum.Font.Gotham
    AutoStartCheckbox.Text = "⬜ Auto-Start on Execute (Click to Enable)"
    AutoStartCheckbox.TextColor3 = Color3.fromRGB(200, 200, 200)
    AutoStartCheckbox.TextSize = 12
    
    Instance.new("UICorner", AutoStartCheckbox)
    
    DebugButton.Parent = MainFrame
    DebugButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
    DebugButton.Position = UDim2.new(0, 20, 0, 285)
    DebugButton.Size = UDim2.new(1, -40, 0, 35)
    DebugButton.Font = Enum.Font.GothamBold
    DebugButton.Text = "🔍 DEBUG: Find All Stingers"
    DebugButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    DebugButton.TextSize = 14
    
    Instance.new("UICorner", DebugButton)
    
    StartButton.Parent = MainFrame
    StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    StartButton.Position = UDim2.new(0, 20, 0, 160)
    StartButton.Size = UDim2.new(1, -40, 0, 40)
    StartButton.Font = Enum.Font.GothamBold
    StartButton.Text = "START HUNTING"
    StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartButton.TextSize = 16
    
    Instance.new("UICorner", StartButton).CornerRadius = UDim.new(0, 8)
    
    StatusLabel.Parent = MainFrame
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 20, 0, 210)
    StatusLabel.Size = UDim2.new(1, -40, 0, 30)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    FieldLabel.Parent = MainFrame
    FieldLabel.BackgroundTransparency = 1
    FieldLabel.Position = UDim2.new(0, 20, 0, 240)
    FieldLabel.Size = UDim2.new(1, -40, 0, 30)
    FieldLabel.Font = Enum.Font.Gotham
    FieldLabel.Text = "Current Field: None"
    FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    FieldLabel.TextSize = 13
    FieldLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Load auto-start setting
    local autoStartEnabled = false
    if isfile and readfile and isfile("vicious_bee_autostart.txt") then
        autoStartEnabled = readfile("vicious_bee_autostart.txt") == "true"
    end
    
    if autoStartEnabled then
        AutoStartCheckbox.Text = "✅ Auto-Start on Execute (Enabled)"
        AutoStartCheckbox.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    end
    
    AutoStartCheckbox.MouseButton1Click:Connect(function()
        autoStartEnabled = not autoStartEnabled
        
        if autoStartEnabled then
            AutoStartCheckbox.Text = "✅ Auto-Start on Execute (Enabled)"
            AutoStartCheckbox.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        else
            AutoStartCheckbox.Text = "⬜ Auto-Start on Execute (Click to Enable)"
            AutoStartCheckbox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        end
        
        if writefile then
            writefile("vicious_bee_autostart.txt", tostring(autoStartEnabled))
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
            
            config.webhookUrl = webhook
            
            if writefile then
                writefile("vicious_bee_webhook.txt", webhook)
                print("✅ Webhook saved")
            end
            
            config.isRunning = true
            StartButton.Text = "STOP HUNTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            StatusLabel.Text = "Status: 🔍 Hunting (Public Servers)..."
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            sendWebhook("🚀 Hunter Started", "Vicious Bee detection is now active!", 0x00AAFF, {})
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
    
    -- Debug button to find all stingers
    DebugButton.MouseButton1Click:Connect(function()
        print("🔍 DEBUG: Scanning for all Stinger objects...")
        
        local stingerInfo = {}
        local count = 0
        
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Stinger" and obj:IsA("BasePart") then
                count = count + 1
                local info = string.format(
                    "**Stinger #%d**\nPosition: `%s`\nParent: `%s`\nClass: `%s`\nSize: `%s`\nTransparency: `%.2f`",
                    count,
                    tostring(obj.Position),
                    obj.Parent and obj.Parent.Name or "nil",
                    obj.ClassName,
                    tostring(obj.Size),
                    obj.Transparency
                )
                table.insert(stingerInfo, info)
                
                print("Found Stinger #" .. count)
                print("  Position:", obj.Position)
                print("  Parent:", obj.Parent and obj.Parent.Name or "nil")
                print("  Class:", obj.ClassName)
            end
        end
        
        if count > 0 then
            -- Send to webhook with all stinger data
            local description = count .. " Stinger object(s) found in Workspace:\n\n" .. table.concat(stingerInfo, "\n\n")
            
            sendWebhook(
                "🔍 DEBUG: All Stingers Found",
                description,
                0xFFA500,
                {}
            )
            
            StatusLabel.Text = "Status: Found " .. count .. " stinger(s) - Check webhook!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
        else
            sendWebhook(
                "🔍 DEBUG: No Stingers Found",
                "No objects named 'Stinger' were found in Workspace.",
                0x808080,
                {}
            )
            
            StatusLabel.Text = "Status: No stingers found"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        
        print("🔍 DEBUG: Scan complete - " .. count .. " stinger(s) found")
    end)
    
    -- Update field label
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
    
    -- FIXED: Auto-start logic
    if autoStartEnabled and config.webhookUrl ~= "" then
        task.delay(1, function()
            if not config.isRunning then
                config.isRunning = true
                StartButton.Text = "STOP HUNTING"
                StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                StatusLabel.Text = "Status: 🔍 Hunting (Public Servers)..."
                StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                
                sendWebhook("🚀 Hunter Started", "Auto-started after teleport", 0x00AAFF, {})
                spawn(mainLoop)
            end
        end)
    end
end

print("🐝 Vicious Bee Stinger Hunter v2 Loaded!")
print("📱 Opening GUI...")
createGUI()
