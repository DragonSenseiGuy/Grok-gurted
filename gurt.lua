-- keep chat history in memory
local send = gurt.select('#send')
local input = gurt.select('#input')
local history = {}

local currentAssistantEl = nil

function appendMessage(role, text, streaming)
    local chat = gurt.select('#chat')

    local msg = gurt.create('div', { text = text or "" })
    msg:setAttribute('class', role)

    -- local totalHeight = 0
    -- for i = 1, #chat.children do
    --     local child = chat.children[i]
    --     totalHeight = totalHeight + child.size.height
    -- end

    -- local mtUnit = math.floor(math.sqrt(totalHeight) / 2)

    -- msg:setAttribute('style', 'mt-' .. mtUnit)

    chat:append(msg)

    return msg
end

function sendMessage(prompt)
    appendMessage("user", prompt, false)
    table.insert(history, { role = "user", content = prompt })

    local server = "http://10.0.0.155:23100"
    local response = fetch(server .. "/submit", {
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = JSON.stringify({ prompt = prompt, history = history })
    })

    if not response:ok() then
        trace.log("Submit failed: " .. response.status)
        return
    end

    local data = response:json()
    local jobId = data.jobId

    local assistantEl = appendMessage("assistant", "", true)
    assistantEl.text = "thinking";

    intervalId = setInterval(function()
        local pollResp = fetch(server .. "/poll/" .. jobId)
        if pollResp:ok() then
            local pollData = pollResp:json()
            if pollData.tokens then
                assistantEl.text = pollData.tokens
            end
            if pollData.done then
                table.insert(history, { role = "assistant", content = assistantEl.text })
                clearInterval(intervalId)
                trace.log("Finished " .. pollData.tokens)
                assistantEl.text = pollData.tokens
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