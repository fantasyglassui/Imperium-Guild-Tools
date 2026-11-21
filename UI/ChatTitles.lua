--[[
  Warcrest
  Titles in chat: when a guildmate with a Warcrest title says something
  (guild, officer, say, yell, party, raid, whispers and chat channels), your
  chat window shows their title in gold at the start of the message:
      [Lyra]: (the Avenger) anyone up for Tarren Mill?
  This only changes what your own chat window shows; the message itself is
  untouched, so players without Warcrest see it as normal. Turn it off on the
  Achievements tab (Title > Show titles in chat).
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local EVENTS = {
  "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
  "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL",
}
local GOLD = "|cffd4af37"

ns.OnLoad(function()
  if ns.db.chatTitles == nil then ns.db.chatTitles = true end
end)

-- The message with the author's title in front, or nil to leave it alone.
function ns.TitledChatText(msg, author)
  if not ns.db or not ns.db.chatTitles then return nil end
  if type(msg) ~= "string" or type(author) ~= "string" or author == "" then return nil end
  if issecretvalue and (issecretvalue(msg) or issecretvalue(author)) then return nil end
  if not ns.Member or not ns.Member(author) then return nil end -- guildmates only
  local title = ns.TitleOf and ns.TitleOf(Ambiguate(author, "short"))
  if not title then return nil end
  return GOLD .. "(" .. ns.T(title) .. ")|r " .. msg
end

local function filter(_, _, msg, author, ...)
  local ok, text = pcall(ns.TitledChatText, msg, author)
  if ok and text then return false, text, author, ... end
  return false, msg, author, ...
end

for _, e in ipairs(EVENTS) do ChatFrameUtil.AddMessageEventFilter(e, filter) end
