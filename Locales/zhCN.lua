--[[
================================================================================
  Chromatix (幻色龙) - Locales/zhCN.lua
  Simplified Chinese (简体中文) localization.
  Overrides enUS fallback keys for zhCN clients.

  Author : David W Zhang
  Version: 1.0.0
  License: MIT
  Repo   : https://github.com/davidchangok/Chromatix
================================================================================
--]]

local _, NS = ...

--- Simplified Chinese locale.
--- The third argument `false` (or omitted) marks it as a non-default override.
NS:RegisterLocale("zhCN", {

    --------------------------------------------------------------------
    -- General / Addon Info
    --------------------------------------------------------------------
    ["ADDON_LOADED"]            = "幻色龙 v%s 已加载。输入 /chromatix 查看帮助。",
    ["ADDON_DESCRIPTION"]       = "根据当前专精自动切换装备套装。\n输入 /chromatix 或 /ctx 查看命令列表。",

    --------------------------------------------------------------------
    -- Slash Commands
    --------------------------------------------------------------------
    ["CMD_HELP_HEADER"]         = "幻色龙 — 可用命令：",
    ["CMD_HELP_CONFIG"]         = "/chromatix config — 打开设置面板。",
    ["CMD_HELP_STATUS"]         = "/chromatix status — 显示当前专精及关联套装。",
    ["CMD_HELP_SWAP"]           = "/chromatix swap — 手动触发当前专精的装备切换。",
    ["CMD_HELP_DEBUG"]          = "/chromatix debug — 切换调试模式。",
    ["CMD_HELP_RESET"]          = "/chromatix reset — 重置当前角色设置。",
    ["CMD_HELP_SAVE"]           = "/chromatix save — 将当前装备保存到当前专精对应的套装中。",
    ["CMD_UNKNOWN"]             = "未知命令：%s。输入 /chromatix 查看帮助。",

    --------------------------------------------------------------------
    -- Spec Manager
    --------------------------------------------------------------------
    ["SPEC_DETECTED"]           = "检测到专精：%s（ID：%d）。",
    ["SPEC_CHANGED"]            = "专精已切换为：%s。",
    ["SPEC_NONE"]               = "当前没有激活的专精。",
    ["SPEC_QUERY_FAILED"]       = "查询专精信息失败。",

    --------------------------------------------------------------------
    -- Equipment Manager
    --------------------------------------------------------------------
    ["EQUIP_SET_FOUND"]         = "找到装备套装：\"%s\"，正在装备...",
    ["EQUIP_SET_EQUIPPED"]      = "装备套装 \"%s\" 已成功装备。",
    ["EQUIP_SET_NOT_FOUND"]     = "未找到专精 %s 对应的装备套装。",
    ["EQUIP_SET_CREATED"]       = "已创建新装备套装 \"%s\"，图标：%s。",
    ["EQUIP_SET_CREATE_FAILED"] = "创建装备套装 \"%s\" 失败。",
    ["EQUIP_SET_ALREADY_EXISTS"]= "装备套装 \"%s\" 已存在。",
    ["EQUIP_SET_SAVED"]         = "装备套装 \"%s\" 已更新。",
    ["EQUIP_COMBAT_DEFERRED"]   = "战斗中 — 装备切换已延迟至战斗结束。",
    ["EQUIP_COMBAT_RESUMED"]    = "战斗结束 — 正在执行延迟的装备切换。",
    ["EQUIP_MAX_SETS"]          = "装备套装数量已达上限，无法创建新套装。",

    --------------------------------------------------------------------
    -- UI Hook (Equipment Flyout Button)
    --------------------------------------------------------------------
    ["UI_NEW_SPEC_SET"]         = "新的天赋方案",
    ["UI_NEW_SPEC_SET_TOOLTIP"] = "根据当前专精名称创建一个新的装备套装。",
    ["UI_BUTTON_CLICK_COMBAT"]  = "战斗中无法创建装备套装。",

    --------------------------------------------------------------------
    -- Options Panel
    --------------------------------------------------------------------
    ["OPTIONS_TITLE"]           = "幻色龙 设置",
    ["OPTIONS_NAMING_MODE"]     = "套装命名方式",
    ["OPTIONS_NAMING_DESC"]     = "选择装备套装名称使用英文专精名（如\"Retribution\"）还是本地化专精名（如\"惩戒\"）。",
    ["OPTIONS_AUTO_SWAP"]       = "自动切换装备",
    ["OPTIONS_AUTO_SWAP_DESC"]  = "切换专精时自动装备关联的套装。",
    ["OPTIONS_NAMING_ENGLISH"]  = "英文",
    ["OPTIONS_NAMING_LOCALIZED"]= "本地化名称",
    ["OPTIONS_DEBUG_MODE"]      = "调试模式",
    ["OPTIONS_DEBUG_DESC"]      = "在聊天窗口中显示详细的调试信息。",
    ["OPTIONS_RESET_DONE"]      = "当前角色的设置已重置。",

    --------------------------------------------------------------------
    -- Status Messages
    --------------------------------------------------------------------
    ["STATUS_HEADER"]           = "幻色龙 — 当前状态：",
    ["STATUS_SPEC"]             = "当前专精：%s（索引：%d，ID：%d）",
    ["STATUS_LINKED_SET"]       = "关联装备套装：\"%s\"",
    ["STATUS_NO_LINK"]          = "当前专精未关联任何装备套装。",
    ["STATUS_NAMING_MODE"]      = "命名方式：%s",
    ["STATUS_DEBUG"]            = "调试模式：%s",
    ["STATUS_ON"]               = "开启",
    ["STATUS_OFF"]              = "关闭",

    --------------------------------------------------------------------
    -- Error / Warning Messages
    --------------------------------------------------------------------
    ["ERR_NO_SPEC"]             = "无法确定当前专精。",
    ["ERR_EQUIPMENT_API"]       = "装备套装API返回了意外的结果。",
    ["ERR_PROTECTED_ACTION"]    = "操作被阻止：战斗锁定期间调用了受保护的函数。",
    ["ERR_INVALID_ARG"]         = "传递给 %s 的参数无效。",
    ["ERR_MODULE_NOT_FOUND"]    = "未找到模块 \"%s\"。",

}, false) -- false = non-default override locale