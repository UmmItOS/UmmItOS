-- Only applies when the plugin is loaded (hyprpm); otherwise it is skipped.
local vkfix = hl.plugin.csgo_vulkan_fix
if vkfix ~= nil then
    -- initial_class, not a regex
    vkfix.vkfix_app({ app = "cs2", w = 1920, h = 1200 })
    hl.config({
        plugin = {
            csgo_vulkan_fix = {
                -- A select few apps might be wonky with this.
                fix_mouse = true,
            },
        },
    })
end
