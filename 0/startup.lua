-- Computer 0: Pocket Computer GUI
local player_name = "hool6"
local entities = {
    { id = "etho", default_name = "Etho", uuid = "69bf4b52-912a-4b0a-887d-137403e3a193", colors = {bg = colors.lightGray, fg = colors.black} },
    { id = "bdubs", default_name = "BDoubleO100", uuid = "c7fc3693-7e90-44df-ba9b-9a7e55c0c178", colors = {bg = colors.brown, fg = colors.white} },
    { id = "keralis", default_name = "Keralis1", uuid = "06408466-b91c-48a5-9875-75ca2fd44c63", colors = {bg = colors.orange, fg = colors.white} },
    { id = "mumbo", default_name = "Mumbo", uuid = "0a805206-2467-47b6-b7db-84f5d5b3245b", colors = {bg = colors.lightBlue, fg = colors.white} }
}
local command_computer_id = 1

-- Load saved names
local saved_names = {}
if fs.exists("names.txt") then
    local f = fs.open("names.txt", "r")
    if f then
        local data = f.readAll()
        saved_names = textutils.unserialize(data) or {}
        f.close()
    end
end

local function saveNames()
    local f = fs.open("names.txt", "w")
    if f then
        f.write(textutils.serialize(saved_names))
        f.close()
    end
end

local function getName(entity_id)
    return saved_names[entity_id] or (function() 
        for _, e in ipairs(entities) do if e.id == entity_id then return e.default_name end end return "Unknown"
    end)()
end

local function setName(entity_id, new_name)
    saved_names[entity_id] = new_name
    saveNames()
end

local current_state = "none" -- 'none', 'etho', 'bdubs', 'keralis', 'mumbo'
if fs.exists("state.txt") then
    local f = fs.open("state.txt", "r")
    if f then
        current_state = f.readAll()
        f.close()
    end
end

local function saveState()
    local f = fs.open("state.txt", "w")
    if f then
        f.write(tostring(current_state))
        f.close()
    end
end

local function findModem()
    for _, side in ipairs(rs.getSides()) do
        if peripheral.getType(side) == "modem" then return side end
    end
    return nil
end

local modemSide = findModem()
if modemSide then
    rednet.open(modemSide)
else
    print("Warning: No wireless modem found! Communication will fail.")
    sleep(2)
end

local function getCommandsForTransition(from_id, to_id)
    local cmds = {}
    
    local from_ent, to_ent
    for _, e in ipairs(entities) do
        if e.id == from_id then from_ent = e end
        if e.id == to_id then to_ent = e end
    end
    
    if from_ent then
        -- Undo previous state
        table.insert(cmds, "tp " .. from_ent.uuid .. " " .. player_name)
        table.insert(cmds, "effect clear " .. from_ent.uuid)
    end
    
    if to_ent then
        -- Apply new state
        table.insert(cmds, "skinshifter set " .. player_name .. " " .. to_ent.default_name)
        table.insert(cmds, "tp " .. player_name .. " " .. to_ent.uuid)
        table.insert(cmds, "effect give " .. to_ent.uuid .. " minecraft:invisibility infinite 0 true")
        table.insert(cmds, "tp " .. to_ent.uuid .. " -6.43 -60.00 23.18")
    else
        -- Going to 'none' state
        table.insert(cmds, "skinshifter reset " .. player_name)
    end
    
    return cmds
end

local w, h = term.getSize()
local buttons = {}

local function drawGUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    term.write("   Character Selector   ")
    
    buttons = {}
    local y_offset = 3
    for i, ent in ipairs(entities) do
        local name = getName(ent.id)
        local is_active = (current_state == ent.id)
        
        -- Draw Button
        local btn_bg = is_active and colors.lime or ent.colors.bg
        local btn_fg = is_active and colors.black or ent.colors.fg
        
        paintutils.drawLine(2, y_offset, 20, y_offset, btn_bg)
        paintutils.drawLine(2, y_offset+1, 20, y_offset+1, btn_bg)
        paintutils.drawLine(2, y_offset+2, 20, y_offset+2, btn_bg)
        
        term.setCursorPos(3, y_offset+1)
        term.setBackgroundColor(btn_bg)
        term.setTextColor(btn_fg)
        local display_name = name
        if string.len(display_name) > 16 then display_name = string.sub(display_name, 1, 16) end
        term.write(display_name)
        
        -- Pencil Icon (Edit)
        paintutils.drawLine(22, y_offset, 24, y_offset, colors.gray)
        paintutils.drawLine(22, y_offset+1, 24, y_offset+1, colors.lightGray)
        paintutils.drawLine(22, y_offset+2, 24, y_offset+2, colors.gray)
        term.setCursorPos(23, y_offset+1)
        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.black)
        term.write("E")
        
        -- Store touch zones
        table.insert(buttons, {
            id = ent.id,
            type = "select",
            x1 = 2, y1 = y_offset, x2 = 20, y2 = y_offset+2
        })
        table.insert(buttons, {
            id = ent.id,
            type = "edit",
            x1 = 22, y1 = y_offset, x2 = 24, y2 = y_offset+2
        })
        
        y_offset = y_offset + 4
    end
    
    -- Reset / None button
    local is_none = (current_state == "none")
    local r_bg = is_none and colors.lime or colors.red
    local r_fg = is_none and colors.black or colors.white
    paintutils.drawLine(2, y_offset, 24, y_offset, r_bg)
    paintutils.drawLine(2, y_offset+1, 24, y_offset+1, r_bg)
    term.setCursorPos(10, y_offset+1)
    term.setBackgroundColor(r_bg)
    term.setTextColor(r_fg)
    term.write("RESET")
    table.insert(buttons, {
        id = "none",
        type = "select",
        x1 = 2, y1 = y_offset, x2 = 24, y2 = y_offset+1
    })
end

local function handleStateChange(new_state)
    if current_state == new_state then return end
    
    local cmds = getCommandsForTransition(current_state, new_state)
    if #cmds > 0 then
        rednet.send(command_computer_id, {type="commands", commands=cmds}, "state_shift")
    end
    
    current_state = new_state
    saveState()
    drawGUI()
end

local function promptEditName(ent_id)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 2)
    term.setTextColor(colors.white)
    print("Enter new name for:")
    term.setTextColor(colors.yellow)
    print(getName(ent_id))
    print()
    term.setTextColor(colors.white)
    term.write("> ")
    local input = read()
    if input and input ~= "" then
        setName(ent_id, input)
    end
    drawGUI()
end

drawGUI()

while true do
    local e = {os.pullEvent()}
    local event = e[1]
    
    if event == "mouse_click" or event == "monitor_touch" then
        local x, y = e[3], e[4]
        for _, btn in ipairs(buttons) do
            if x >= btn.x1 and x <= btn.x2 and y >= btn.y1 and y <= btn.y2 then
                if btn.type == "select" then
                    handleStateChange(btn.id)
                elseif btn.type == "edit" then
                    promptEditName(btn.id)
                end
                break
            end
        end
    elseif event == "rednet_message" then
        local senderId, message, protocol = e[2], e[3], e[4]
        if protocol == "state_shift" and type(message) == "table" and message.type == "cycle" then
            local next_id
            if current_state == "none" then
                next_id = entities[1].id
            else
                for i, ent in ipairs(entities) do
                    if ent.id == current_state then
                        local next_index = i + 1
                        if next_index > #entities then
                            next_index = 1
                        end
                        next_id = entities[next_index].id
                        break
                    end
                end
            end
            if next_id then
                handleStateChange(next_id)
            end
        end
    end
end
