local _, STEP = ...

local NativeOptions = {
    initialized = false,
}
STEP.NativeOptions = NativeOptions

function NativeOptions:Initialize()
    if self.initialized then
        return true
    end
    if not UIParent or not STEP.OptionsControls then
        return false
    end

    local panel = CreateFrame("Frame", "STEPNativeOptionsPanel")
    panel.name = "STEP"
    self.panel = panel
    STEP.OptionsControls:BuildSurface(panel, "Native")

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.category = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    self.initialized = true
    return true
end

function NativeOptions:Open()
    if not self:Initialize() then
        return false
    end
    STEP.OptionsControls:RefreshAll()
    if Settings and Settings.OpenToCategory and self.category then
        Settings.OpenToCategory(self.category.ID or self.category)
    elseif InterfaceOptionsFrame_OpenToCategory and self.panel then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
    return true
end
