-- keep chat history in memory
local send = gurt.select('#send')
local input = gurt.select('#input')
local history = {}
<<<<<<< HEAD

local busy = false

local function autoscroll()
    local chat = gurt.select('#chat')
    if chat and chat.scrollHeight then
        chat.scrollTop = chat.scrollHeight
    else
        -- naive fallback
        chat.scrollTop = 999999
    end
end

function appendMessage(role, text, streaming)
    local chat = gurt.select('#chat')

    local msg = gurt.create('div', { text = text or "" })
    msg:setAttribute('class', 'message ' .. role .. (streaming and ' thinking' or ''))

    chat:append(msg)
    autoscroll()

    return msg
end

function sendMessage(prompt)
    if busy then return end

    appendMessage("user", prompt, false)
    table.insert(history, { role = "user", content = prompt })

    busy = true
    local originalBtnText = send.text or 'Send'
    send.text = 'Sending…'

    local server = "http://10.0.0.155:23100"
=======
local inputBar = gurt.select("#input-bar");
local chat = gurt.select('#chat')

-- all messages live in here
local allMessages = {}
chat.text = "Start chatting with Gronk"
function appendMessage(role, text, streaming)
    local message = { role = role, text = text or "" }
    table.insert(allMessages, message)

    -- force initial render
    local function render()
        local combined = {}
        for _, m in ipairs(allMessages) do
            table.insert(combined, string.replace(string.replace(m.role, "assistant", "Gronk"), "user", "You") .. ": " .. m.text)
        end
        local text = table.concat(combined, "\n\n") -- spacing
        chat.text = text
    end

    render()

    -- return updater function
    return function(newText)
        message.text = newText
        render()
    end
end

function countNewlines(str)
    local count = 0
    for _ in str:gmatch("\n") do
        count = count + 1
    end
    return count
end

function sendMessage(prompt)
    appendMessage("user", prompt, false)
    table.insert(history, { role = "user", content = prompt })

    local server = "https://s.73206141212.com:23100"
>>>>>>> other_repo/main
    local response = fetch(server .. "/submit", {
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = JSON.stringify({ prompt = prompt, history = history })
    })

    if not response:ok() then
        trace.log("Submit failed: " .. response.status)
<<<<<<< HEAD
        busy = false
        send.text = originalBtnText
=======
>>>>>>> other_repo/main
        return
    end

    local data = response:json()
    local jobId = data.jobId

<<<<<<< HEAD
    local assistantEl = appendMessage("assistant", "", true)
=======
    local assistant = appendMessage("assistant", "", true)
    assistant("thinking")
>>>>>>> other_repo/main

    intervalId = setInterval(function()
        local pollResp = fetch(server .. "/poll/" .. jobId)
        if pollResp:ok() then
            local pollData = pollResp:json()
            if pollData.tokens then
<<<<<<< HEAD
                assistantEl.text = pollData.tokens
                autoscroll()
            end
            if pollData.done then
                table.insert(history, { role = "assistant", content = assistantEl.text })
                clearInterval(intervalId)
                trace.log("Finished " .. pollData.tokens)
                assistantEl:setAttribute('class', 'message assistant')
                busy = false
                send.text = originalBtnText
                autoscroll()
=======
                assistant(pollData.tokens)
            end
            if pollData.done then
                table.insert(history, { role = "assistant", content = pollData.tokens })
                clearInterval(intervalId)
                trace.log("Finished " .. pollData.tokens)
                assistant(pollData.tokens)
>>>>>>> other_repo/main
            end
        else
            trace.log("Poll failed: " .. pollResp.status)
        end
<<<<<<< HEAD
    end, 1000)
end

=======
    end, 100)
end


>>>>>>> other_repo/main
send:on('click', function()
    local query = input.value
    if query ~= '' then
        sendMessage(query)
        input.value = '' -- clear input
    end
<<<<<<< HEAD
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
=======
end)
>>>>>>> other_repo/main
