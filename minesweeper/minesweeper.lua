-- =============
-- Render Logic
-- =============

blitCenter = function(s, t, b)
    local sX, sY = term.getSize()
    
    if #s > sX then
        s = s:sub(1, sX)
    end
    
    local cX = (sX - #s) / 2
    local _, cY = term.getCursorPos()
    term.setCursorPos(cX, cY)
    
    term.blit(s, t, b)
    print("")
end

printCenter = function(s)
    local sX, sY = term.getSize()

    if #s > sX then
        s = s:sub(1, sX)
    end

    local cX = (sX - #s) / 2
    local _, cY = term.getCursorPos()
    term.setCursorPos(cX, cY)
    print(s)
end

toBoardPos = function(x, y, rows, cols)
    local sX, sY = term.getSize()
    local bY = y - 1
    
    local cX_start = math.floor((sX - cols) / 2)
    local bX = x - cX_start + 1
    
    if bY < 1 or bY > rows or bX < 1 or bX > cols then
        return nil, nil
    end
    
    return bX, bY
end

draw = function(board, mines, flags, timer, rows, cols, ready)
    term.clear()
    term.setCursorPos(1,1)

    printCenter(string.format(
        "Mines: %03d | Flags: %03d | Time: %03d",
        mines, flags, timer
    ))

    if not ready then
        for y = 1, rows do
            local line = ""

            for x = 1, cols do
                line = line .. "~"
            end

            printCenter(line)
        end

        return
    end

    for y = 1, #board do
        local line = ""
        local fg = ""
        local bg = ""

        for x = 1, #board[y] do
            local cell = board[y][x]
            bg = bg .. "0"
            
            if cell.hid == false then
                if cell.val == true then
                    line = line .. "X"
                    fg = fg .. "e"
                elseif cell.val == 0 then
                    line = line .. "."
                    fg = fg .. "0"
                else
                    local ch = tostring(cell.val)
                    line = line .. ch
                    
                    if ch == "1" then
                        fg = fg .. "b"
                    elseif ch == "2" then
                        fg = fg .. "d"
                    elseif ch == "3" then
                        fg = fg .. "e"
                    elseif ch == "4" then
                        fg = fg .. "a"
                    elseif ch == "5" then
                        fg = fg .. "1"
                    elseif ch == "6" then
                        fg = fg .. "9"
                    elseif ch == "7" then
                        fg = fg .. "f"
                    elseif ch == "8" then
                        fg = fg .. "7"
                    end
                end
            else
                if cell.flag then
                    line = line .. "F"
                    fg = fg .. "f"
                else
                    line = line .. "~"
                    fg = fg .. "3"
                end
            end
        end

        blitCenter(line, fg, bg)
    end
end

-- =============
-- Game Logic
-- =============

genBoard = function(rows, cols, mineCount, firstX, firstY)
    local board = {}
    for y = 1, rows do
        board[y] = {}
        for x = 1, cols do
            board[y][x] = {}
            board[y][x].val = 0
            board[y][x].hid = true
            board[y][x].flag = false
        end
    end

    -- Make a list of valid mine positions
    local validPositions = {}
    for x = 1, cols do
        for y = 1, rows do
            local safeX = math.abs(x - firstX) <= 1
            local safeY = math.abs(y - firstY) <= 1

            if not (safeX and safeY) then
                table.insert(validPositions, {x = x, y = y})
            end
        end
    end

    if mineCount > #validPositions then
        error("too many mines")
    end

    -- Shuffle with Fisher-Yates
    for i = #validPositions, 2, -1 do
        local j = math.random(i)
        validPositions[i], validPositions[j] = validPositions[j], validPositions[i]
    end

    -- Place mines
    for i = 1, mineCount do
        local pos = validPositions[i]
        board[pos.y][pos.x].val = true
    end

    -- Calculate numbers
    for x = 1, cols do
        for y = 1, rows do
            local cell = board[y][x]
            if cell.val ~= true then
                local count = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local nx = x + dx
                            local ny = y + dy

                            if nx >= 1 and nx <= cols and
                            ny >= 1 and ny <= rows and
                            board[ny][nx].val == true then
                                count = count + 1
                            end
                        end
                    end
                end

                cell.val = count
            end
        end
    end

    return board
end

reveal = function(board, x, y)
    if x < 1 or x > #board[1] or
    y < 1 or y > #board then
        return
    end

    local cell = board[y][x]

    if not cell.hid or cell.flag then
        return
    end

    cell.hid = false

    if cell.val ~= 0 then
        return
    end

    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                reveal(board, x + dx, y + dy)
            end
        end
    end
end

chord = function(board, x, y, rows, cols)
    local cell = board[y][x]

    -- Must be a revealed number tile
    if cell.hid or
    cell.val == true or
    cell.val == 0 then
        return true
    end

    local flagCount = 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local nx = x + dx
                local ny = y + dy

                if nx >= 1 and nx <= cols and
                    ny >= 1 and ny <= rows and
                    board[ny][nx].flag then
                    flagCount = flagCount + 1
                end
            end
        end
    end

    if flagCount ~= cell.val then
        return true
    end

    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local nx = x + dx
                local ny = y + dy

                if nx >= 1 and nx <= cols and
                    ny >= 1 and ny <= rows then
                    local neighbor = board[ny][nx]
                    if neighbor.hid and not neighbor.flag then
                        if not click(board, nx, ny, rows, cols) then
                            return false
                        end
                    end
                end
            end
        end
    end
    
    return true
end

click = function(board, x, y, rows, cols)
    local cell = board[y][x]

    if cell.hid == false then
        if not chord(board, x, y, rows, cols) then
            return false
        end
    end

    if cell.flag then
        return true
    end

    if cell.val == true then
        cell.hid = false

        -- Reveal all mines
        for yy = 1, #board do
            for xx = 1, #board[yy] do
                if board[yy][xx].val == true then
                    board[yy][xx].hid = false
                end
            end
        end

        return false
    end

    reveal(board, x, y)
    return true
end

checkWin = function(board, rows, cols)
    for y = 1, rows do
        for x = 1, cols do
            local cell = board[y][x]
            if cell.hid and cell.val ~= true then
                return false
            end
        end
    end

    return true
end

setFlag = function(board, x, y)
    local cell = board[y][x]

    if not cell.hid then
        return nil
    end

    cell.flag = not cell.flag
    
    if cell.flag == true then
        return true
    else
        return false
    end
end

-- =============
-- Main Section
-- =============

local rows, cols, mines = ...
rows = tonumber(rows)
cols = tonumber(cols)
mines = tonumber(mines)

math.randomseed(os.time())

if not rows or not cols or not mines then
    error("usage: minesweeper <rows> <cols> <mines>")
end

do
    local sX, sY = term.getSize()
    local sY = sY - 2
    if rows > sY or cols > sX then
        error(string.format(
            "Board too large! Max: %dx%d",
            sY, sX
        ))
    end
end

-- Game Variables
local board = nil
local timer = nil
local flags = nil
local ready = nil
local loss  = nil
local win   = nil
local start = nil

local function renderLoop()
    while true do
        timer = math.floor((os.epoch("utc") - start) / 1000)
    
        draw(board, mines, flags, timer, 
            rows, cols, ready)
        
        local oldColor = term.getTextColor()
        
        if win or loss then
            term.setCursorPos(1, 3)
        end
        
        if win then
            term.setTextColor(colors.green)
            printCenter("YOU WIN")
            term.setTextColor(oldColor)
            break
        elseif loss then
            term.setTextColor(colors.red)
            printCenter("YOU LOSE")
            term.setTextColor(oldColor)
            break
        end
        
        os.sleep(0.125)
    end
end

local function inputLoop()
    while true do
        local _, button, x, y = os.pullEvent("mouse_click")
        local bX, bY = toBoardPos(
            x, y, rows, cols
        )
        
        if not bX or not bY then
            goto continue
        end
        
        if button == 1 then
            if not ready then
                ready = true
                board = genBoard(
                    rows, cols, mines, bX, bY
                )
            end
            
            if not click(board, bX, bY, rows, cols) then
                loss = true
                win = false
                return
            end
            
            win = checkWin(board, rows, cols)
            
            if win then return end
            
        elseif button == 2 then
            local result = setFlag(board, bX, bY)
            if result == true then
                flags = flags + 1
            elseif result == false then
                flags = flags - 1
            end
        end
        
        ::continue::
    end
end

while true do
    start = os.epoch("utc")
    board = nil
    flags = 0
    timer = 0
    ready = false
    win = nil
    loss = nil

    parallel.waitForAll(renderLoop, inputLoop)
    os.sleep(5)
end
