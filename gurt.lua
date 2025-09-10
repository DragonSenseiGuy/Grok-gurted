-- ChatGPT-like multi-chat UI and logic

-- Elements
local send = gurt.select('#send')
local input = gurt.select('#input')
local chatEl = gurt.select('#chat')
local newChatBtn = gurt.select('#new-chat')
local chatListEl = gurt.select('#chat-list')
local appEl = gurt.select('#app')
local openSidebarBtn = gurt.select('#open-sidebar')
local closeSidebarBtn = gurt.select('#close-sidebar')

-- Server (keeps your updated HTTPS endpoint by default)
local SERVER = "gurt://s.73206141212.com"
-- local ALT_SERVER = "gurt://10.0.0.155" -- fallback if needed

-- State
local chats = {}
local currentChatId = nil
local busy = false
local sidebarOpen = false
local baseAppClass = 'app'

-- Utils
local function uid()
    return tostring(os.time()) .. "-" .. tostring(math.random(1000, 999999))
end

local function autoscroll()
    if chatEl and chatEl.scrollHeight then
        chatEl.scrollTop = chatEl.scrollHeight
    else
        chatEl.scrollTop = 999999
    end
end

local function applySidebarState()
    if not appEl then return end
    if sidebarOpen then
        appEl:setAttribute('class', baseAppClass .. ' sidebar-open')
    else
        appEl:setAttribute('class', baseAppClass)
    end
end

local function makeTitleFrom(text)
    if not text or text == '' then return 'New chat' end
    local oneLine = string.gsub(text, "\n", " ")
    if #oneLine > 40 then
        return string.sub(oneLine, 1, 40) .. "…"
    end
    return oneLine
end

local function getCurrentChat()
    for _, c in ipairs(chats) do
        if c.id == currentChatId then return c end
    end
    return nil
end

-- Rendering
local function clearChat()
    -- Setting text clears children in this environment
    chatEl.text = ''
end

local function bubbleStyle(role, streaming)
    local base = 'max-w-[80%] rounded-[12] px-3 py-2'
    if role == 'user' then
        base = base .. ' self-end bg-[#3b82f6] text-white'
    else
        base = base .. ' self-start bg-[#374151]'
    end
    if streaming then
        base = base .. ' opacity-80'
    end
    return base
end

function appendMessage(role, text, streaming)
    local msg = gurt.create('div', { text = text or '', style = bubbleStyle(role, streaming) })
    chatEl:append(msg)
    autoscroll()
    return msg
end

local function renderChatHistory()
    clearChat()
    local c = getCurrentChat()
    if not c then return end
    for i = 1, #c.history do
        local m = c.history[i]
        appendMessage(m.role, m.content, false)
    end
end

local function renderSidebar()
    if not chatListEl then return end
    chatListEl.text = ''
    for _, c in ipairs(chats) do
        local isActive = (c.id == currentChatId)
        local style = 'w-full text-left px-3 py-2 rounded border border-[#2b3444] ' .. (isActive and 'bg-[#1b2437]' or 'bg-transparent hover:bg-[#232e45]')
        local btn = gurt.create('button', { text = c.title or 'New chat', style = style })
        btn:on('click', function()
            currentChatId = c.id
            renderSidebar()
            renderChatHistory()
        end)
        chatListEl:append(btn)
    end
end

-- Chat management
local function newChat()
    local c = { id = uid(), title = 'New chat', history = {} }
    table.insert(chats, 1, c) -- newest on top like ChatGPT
    currentChatId = c.id
    renderSidebar()
    renderChatHistory()
end

-- Messaging
function sendMessage(prompt)
    if busy then return end
    local c = getCurrentChat()
    if not c then newChat(); c = getCurrentChat() end

    appendMessage('user', prompt, false)
    table.insert(c.history, { role = 'user', content = prompt })

    if c.title == 'New chat' or not c.title or c.title == '' then
        c.title = makeTitleFrom(prompt)
        renderSidebar()
    end

    busy = true
    local originalBtnText = send.text or 'Send'
    send.text = 'Sending…'

    local response = fetch(SERVER .. "/submit", {
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = JSON.stringify({ prompt = prompt, history = c.history })
    })

    if not response:ok() then
        trace.log("Submit failed: " .. response.status)
        busy = false
        send.text = originalBtnText
        return
    end

    local data = response:json()
    local jobId = data.jobId

    local assistantEl = appendMessage('assistant', '', true)

    intervalId = setInterval(function()
        local pollResp = fetch(SERVER .. "/poll/" .. jobId)
        if pollResp:ok() then
            local pollData = pollResp:json()
            if pollData.tokens then
                assistantEl.text = pollData.tokens
                autoscroll()
            end
            if pollData.done then
                table.insert(c.history, { role = 'assistant', content = assistantEl.text })
                clearInterval(intervalId)
                trace.log("Finished " .. pollData.tokens)
                assistantEl:setAttribute('style', bubbleStyle('assistant', false))
                busy = false
                send.text = originalBtnText
                autoscroll()
            end
        else
            trace.log("Poll failed: " .. pollResp.status)
        end
    end, 200)
end

-- Events
send:on('click', function()
    local query = input.value
    if query ~= '' then
        sendMessage(query)
        input.value = ''
    end
end)

-- Enter to send
input:on('keydown', function(ev)
    if ev and (ev.key == 'Enter' or ev.keyCode == 13) then
        local query = input.value
        if query ~= '' then
            sendMessage(query)
            input.value = ''
        end
    end
end)

-- New chat button
if newChatBtn then
    newChatBtn:on('click', function()
        if busy then return end
        newChat()
    end)
end

-- Sidebar toggles (mobile)
if openSidebarBtn then
    openSidebarBtn:on('click', function()
        sidebarOpen = true
        applySidebarState()
    end)
end
if closeSidebarBtn then
    closeSidebarBtn:on('click', function()
        sidebarOpen = false
        applySidebarState()
    end)
end

-- Init
applySidebarState()
newChat()
