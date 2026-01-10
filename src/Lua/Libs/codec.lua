
-- yes, this does allow for more codecs in the future
-- no, i did not do this thinking there will be more

---@class squiggle_codeclib Library responsible for handling SRB2: All-Stars' codec calls.
local codec = {}

-- vars, should all be local (hopefully)
codec.vars = {
    shouldrender = true, ---@type boolean Should the codec be rendered, if one is being played?
    current = nil, ---@type string? The current codec's ID. `nil` means there's none being played.
    next = nil, ---@type string? The next codec's ID. `nil` means there's none in queue.
    time_started = 0, ---@type tic_t When the codec's been started.
}

---@class squiggleCodec_t
local codecTemplate = {
    id = nil, ---@type string How the codec will be called internally.
    duration = 0, ---@type tic_t The codec's duration, in tics
    caller = "Snake", ---@type string? Who's calling? Use `"player"` for it to be a specified player.
    receiver = "player", ---@type string? Who's being called? Use `"player"` for it to be the local player.
    dialog = sfx_none, ---@type integer? The codec call's dialog sfx, uses `sfx_` constants.
    lyrics = nil ---@type string? The codec's lyrics.
}

local codec_meta = {__index = codecTemplate}
local codecList = {} ---@type table<integer, squiggleCodec_t?> the list of codecs
local id_repeat = {}

---@param definition squiggleCodec_t
---@return squiggleCodec_t? codecAdded Was the codec added?
function codec:addCodec(definition)
    if not definition.id then
        error("It seems you've forgotten to specify an ID for your codec definition!", 2)
        return
    end

    if not definition.duration then
        error("It seems you've forgotten to specify a duration for your codec definition!", 2)
        return
    end

    local id = definition.id:lower()
    definition.id = nil

    if codecList[id] ~= nil then
        id_repeat[id] = ($+1 or 1)
        id = $ + id_repeat[id]

        print("It seems your id was found already, adding it as '" + id + "' instead!")
    end

    codecList[id] = setmetatable(definition, codec_meta)
    return codecList[id]
end

---@param id string
---@return squiggleCodec_t?
function codec:getCodec(id)
    if id == nil then return end

    return codecList[tostring(id):lower()]
end

---@param id string
---@param p player_t?
---@return boolean codecChanged Has the codec been changed?
function codec:changeCodec(id, p)
    if id == nil then return false end

    local codec_t = self:getCodec(id)
    if codec_t == nil then return false end

    self.vars.next = id
    return true
end

local codec_fadeIn_dur = TICRATE/4
local codec_fadeOut_dur = codec_fadeIn_dur

---@param v videolib
function codec:renderer(v)
    if self.vars.current == nil
    and self.vars.next == nil then return end

    local codec_t = self:getCodec(self.vars.current)
    if not codec_t then
        local nuCodec_t = self:getCodec(self.vars.next)
        if self.vars.next ~= nil and nuCodec_t then
            self.vars.current, self.vars.next = $2, $1

            self.vars.time_started = (leveltime or 0)
            S_StartSound(nil, nuCodec_t.dialog)
        end
        return
    end

    -- logic stuff, in-hud since all vars are per-client anyways :PP
    local total_time = (leveltime - self.vars.time_started)
    local time = total_time

    if time > codec_t.duration then
        self.vars.current = nil
        return
    end

    if not self.vars.shouldrender then return end

    -- handle the background stuff
    -- this here is the fade-in
    if time < codec_fadeIn_dur then
        local strength = ease.linear(FixedDiv(time, codec_fadeIn_dur), 0, 31*FU)
        v.fadeScreen(0xFA00, strength/FU)
        return
    end
    time = $ - codec_fadeIn_dur
    
    local trans = 0

    -- this here is the fade-out / black bg
    if codec_t.duration - total_time < codec_fadeOut_dur then
        local fadeTime = FixedDiv(codec_t.duration - total_time, codec_fadeOut_dur)
        local strength = ease.linear(fadeTime, 0, 31*FU)
        trans = ease.linear(fadeTime, 0, 10*FU) / FU
        v.fadeScreen(0xFA00, strength/FU)
        return
    else
        v.drawFill()
    end

    if trans >= 10 then return end


    v.drawString(160, 100, "kept u watigin", 0, "center")
end

codec:addCodec({
    id = "waiting",
    duration = 5*TICRATE,
    caller = "Snake",
    receiver = "player",
    dialog = freeslot("sfx_kepuwa"),
    lyrics = "Kept you waiting, huh?"
})

if devparm then
    COM_AddCommand("squiggle_codecstart", function(_, arg)
        if codec:getCodec(arg) then
            codec:changeCodec(arg)
            print("Changed to codec with ID '"+arg+"'!")
        else
            print("There's no codec with ID '"+arg+"'.")
        end
    end, COM_ADMIN)

    addHook("HUD", function(v)
        codec:renderer(v)
    end)
end