-- Makes the stub game client look like WoW: Forever's (Mainline UI, 12.x API):
-- the old globals it no longer has are gone, their newer homes are there, and
-- registering an event it doesn't have is an error. From the lists in
-- Ketho/BlizzardInterfaceResources (forever branch).
local old = {
  GetItemInfo = GetItemInfo, GetSpellInfo = GetSpellInfo, SendChatMessage = SendChatMessage,
  ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter, ChatFrame_OpenChat = ChatFrame_OpenChat,
  GuildInvite = GuildInvite, GetGuildRosterMOTD = GetGuildRosterMOTD,
}
C_Item.GetItemInfo = old.GetItemInfo
C_Spell.GetSpellInfo = function(id)
  local name = spellNames and spellNames[id]
  if name then return { name = name, spellID = id } end
end
C_ChatInfo.SendChatMessage = old.SendChatMessage
ChatFrameUtil = ChatFrameUtil or {}
ChatFrameUtil.AddMessageEventFilter = old.ChatFrame_AddMessageEventFilter
ChatFrameUtil.OpenChat = old.ChatFrame_OpenChat or function() end
C_GuildInfo.Invite = old.GuildInvite
C_GuildInfo.GetMOTD = old.GetGuildRosterMOTD

RaidWarningUtil = { AddMessage = function(text, info) RaidNotice_AddMessage(RaidWarningFrame, text, info) end }

-- The profession window, through C_TradeSkillUI (from the same tradeSkill table the old functions read).
C_TradeSkillUI = {
  GetBaseProfessionInfo = function()
    if not tradeSkill then return { professionName = "", skillLevel = 0, maxSkillLevel = 0 } end
    return { professionName = tradeSkill.name, skillLevel = tradeSkill.rank, maxSkillLevel = tradeSkill.max }
  end,
  GetChildProfessionInfo = function() return nil end,
  IsTradeSkillLinked = function() return false end,
  IsTradeSkillGuild = function() return false end,
  IsNPCCrafting = function() return false end,
  GetAllRecipeIDs = function()
    local ids = {}
    for i, r in ipairs(tradeSkill and tradeSkill.recipes or {}) do
      -- A recipe's id is its spell's: the enchant's own, or a made-up one for an item.
      if r[2] ~= "header" and r[2] ~= "subheader" then
        ids[#ids + 1] = tonumber(r[3] and r[3]:match("enchant:(%d+)")) or (90000 + i)
      end
    end
    return ids
  end,
  GetRecipeInfo = function(id)
    for i, r in ipairs(tradeSkill and tradeSkill.recipes or {}) do
      if (tonumber(r[3] and r[3]:match("enchant:(%d+)")) or (90000 + i)) == id then
        return { recipeID = id, name = r[1], learned = true }
      end
    end
  end,
  GetRecipeSchematic = function(id)
    local r = tradeSkill and tradeSkill.recipes[id - 90000]
    local item = r and r[3] and r[3]:match("item:(%d+)")
    return { recipeID = id, outputItemID = item and tonumber(item) or nil }
  end,
  GetRecipeItemLink = function(id)
    local r = tradeSkill and tradeSkill.recipes[id - 90000]
    return r and r[3] and r[3]:find("item:") and r[3] or nil
  end,
}

for _, name in ipairs({ "GetItemInfo", "GetSpellInfo", "SendChatMessage", "ChatFrame_AddMessageEventFilter",
    "ChatFrame_OpenChat", "GuildInvite", "GetGuildRosterMOTD", "RaidNotice_AddMessage", "GetTradeSkillLine",
    "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillItemLink", "GetCraftDisplaySkillLine", "GetNumCrafts",
    "GetCraftInfo", "GetCraftItemLink" }) do
  _G[name] = nil
end
