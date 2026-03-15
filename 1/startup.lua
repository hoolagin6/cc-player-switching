-- Computer 1: Command Computer Listener
local function findModem()
    for _, side in ipairs(rs.getSides()) do
        if peripheral.getType(side) == "modem" then
            return side
        end
    end
    return nil
end

local modemSide = findModem()
if modemSide then
    rednet.open(modemSide)
    print("Rednet opened on " .. modemSide)
else
    print("Error: No modem attached!")
    return
end

print("Command Computer Listener Started.")
print("Waiting for commands on 'state_shift' protocol...")

local wasPowered = false
local function checkPower()
    for _, side in ipairs(rs.getSides()) do
        if rs.getInput(side) then return true end
    end
    return false
end
wasPowered = checkPower()

while true do
    local eventData = {os.pullEvent()}
    local event = eventData[1]
    
    if event == "rednet_message" then
        local senderId, message, protocol = eventData[2], eventData[3], eventData[4]
        if protocol == "state_shift" and type(message) == "table" and message.type == "commands" then
            print("Received " .. #message.commands .. " commands from " .. senderId)
            for _, cmd in ipairs(message.commands) do
                print("Executing: " .. cmd)
                local success, result = commands.exec(cmd)
                if not success then
                    print(" -> Failed!")
                end
            end
        end
    elseif event == "redstone" then
        local isPowered = checkPower()
        if isPowered and not wasPowered then
            print("Redstone pulse detected, sending cycle command...")
            rednet.broadcast({type="cycle"}, "state_shift")
        end
    end
    wasPowered = checkPower()
end
