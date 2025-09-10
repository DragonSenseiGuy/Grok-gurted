-- keep chat history in memory
local send = gurt.select('#send')
local input = gurt.select('#input')
local history = {}

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
    local response = fetch(server .. "/submit", {
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = JSON.stringify({ prompt = prompt, history = history })
    })

    if not response:ok() then
        trace.log("Submit failed: " .. response.status)
        busy = false
        send.text = originalBtnText
        return
    end

    local data = response:json()
    local jobId = data.jobId

    local assistantEl = appendMessage("assistant", "", true)

    intervalId = setInterval(function()
        local pollResp = fetch(server .. "/poll/" .. jobId)
        if pollResp:ok() then
            local pollData = pollResp:json()
            if pollData.tokens then
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
            end
        else
            trace.log("Poll failed: " .. pollResp.status)
        end
    end, 1000)
end

send:on('click', function()
    local query = input.value
    if query ~= '' then
        sendMessage(query)
        input.value = '' -- clear input
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
