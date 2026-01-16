---@diagnostic disable: need-check-nil

require 'orbis'

--#region tables

local settings = ac.storage {
    centerApp = true,

    orbisIndicator = true,
    lightsIndicator = true,
    arrowIndicator = false,

    fadeArrow = true,
    excludeAI = false,
    indicatorActiveRange = 30, --in meters
}

local colors = {
    userAccentColor = rgbm(),
    circleInner = rgbm(0.5, 0.6, 0.19, 0.9),
    circleFill = rgbm(0.26, 0.29, 0.12, 0.8),
    circleOuter = rgbm(0.36, 0.4, 0.22, 0.6),
    issueButton = {
        idle = rgbm(0.5, 0.2, 0.18, 1),
        hovered = rgbm(1, 0.3, 0.24, 1),
        active = rgbm(0.9, 0.38, 0.3, 1),
    },
}

local app = {
    scale = 1,
    images = {
        mirror = '.\\assets\\mirror.dds',
        lights = '.\\assets\\lights.dds',
        arrow = '.\\assets\\arrow.dds',
    },
}

--#endregion

local sim = ac.getSim()
local isOrbisNear = false
local isOnlineRace = sim.isOnlineRace
local trackFolderName = ac.getTrackID()

--#region helper functions

---Scales input value by the app scale.
---@param value number
---@return number @Scaled value.
local function scale(value)
    return math.floor(value * app.scale)
end

---@param text string @Text to be displayed in the tooltip.
---@param cursorType? ui.MouseCursor @Changes the mouse cursor to given cursorType.
local function tooltip(text, cursorType)
    if ui.itemHovered() then
        if cursorType then ui.setMouseCursor(cursorType) end
        ui.tooltip(vec2(7, 4), function() ui.text(text) end)
    end
end

---Converts degrees to radians.
---@param deg number
local function degToRad(deg)
    return deg * math.pi / 180
end

--#endregion

--#region logic functions

local appWindow = ac.accessAppWindow('IMGUI_LUA_NFS mirror_main')

local function centerApp()
    if not appWindow:valid() then return end

    local windowWidth = sim.windowWidth
    local center = (windowWidth - appWindow:size().x) / 2

    if appWindow:position().x ~= center and not ui.isMouseDragging(ui.MouseButton.Left, 0) then
        appWindow:move(vec2(center, appWindow:position().y))
    end
end

---Determines if the car is within 400m of any speedtraps.
local function updateOrbis()
    local orbis = getOrbisPositions()
    local carPos = ac.getCar(sim.focusedCar).position
    local dist = 500

    if string.match(trackFolderName, 'shuto_revival_project') then
        for i = 1, #orbis do
            if dist > math.sqrt((carPos.x - orbis[i].x) ^ 2 + (carPos.z - orbis[i].z) ^ 2) then
                dist = math.sqrt((carPos.x - orbis[i].x) ^ 2 + (carPos.z - orbis[i].z) ^ 2)
            end
        end
    end

    if dist <= 400 then
        isOrbisNear = true
    else
        isOrbisNear = false
    end
end

--#endregion

--#region drawing functions

local function drawMirror()
    local virtualMirrorPos = vec2(15, 15):scale(app.scale)
    local virtualMirrorSize = vec2(470, 140):scale(app.scale)
    local whitePoint = 1.3 - (sim.lightSuggestion * 0.5)

    ui.beginTonemapping()
    ui.drawVirtualMirror(virtualMirrorPos, virtualMirrorPos + virtualMirrorSize)
    ui.endTonemapping(1, whitePoint, true)

    local mirrorPos = vec2(0, 0)
    local mirrorSize = vec2(500, 193):scale(app.scale)

    ui.drawImage(app.images.mirror, mirrorPos, mirrorPos + mirrorSize, rgbm.colors.white)
end

local function drawRing()
    local center = vec2(250, 183):scale(app.scale)
    local arcStart, arcEnd = degToRad(180), degToRad(360)
    local radiusInner, radiusOuter = scale(16), scale(26)
    local segments = 22
    local arcThickness = scale(4)

    ui.pathArcTo(center, radiusInner, arcStart, arcEnd, 4)
    ui.pathFillConvex(colors.circleFill)

    ui.pathArcTo(center, radiusOuter, arcStart, arcEnd, segments)
    ui.pathStroke(colors.circleOuter, false, arcThickness)

    ui.pathArcTo(center, radiusInner, arcStart, arcEnd, segments)
    ui.pathStroke(colors.circleInner, false, arcThickness)
end

local function drawArrow() --FIXME: !?
    if not isOnlineRace then return end

    local nearestCar = ac.getCar.ordered(1) if nearestCar == nil then return end
    local isAI = nearestCar.isHidingLabels
    local inRange = nearestCar.distanceToCamera < settings.indicatorActiveRange
    local isorb = settings.orbisIndicator and isOrbisNear

    if settings.orbisIndicator and isOrbisNear then
        if sim.frame % 40 > 20 then
            ui.setCursor(vec2(-10, -60))
            ui.image(app.images.lights, vec2(520, 320), rgbm.colors.white)
        end
    end

    if inRange and not isorb and settings.lightsIndicator then
        if not isAI or (isAI and not settings.excludeAI) then
            ui.setCursor(vec2(-10, -60))
            ui.image(app.images.lights, vec2(520, 320), rgbm.colors.white)
        end
    end

    if inRange and not isorb and settings.arrowIndicator then
        if not isAI or (isAI and not settings.excludeAI) then
            local look_vec3 = ac.getCar.ordered(0).look
            local diff_vec3 = nearestCar.position - ac.getCar.ordered(0).position

            local look_vec2 = vec2(look_vec3.x, look_vec3.z)
            local diff_vec2 = vec2(diff_vec3.x, diff_vec3.z)
            local angle = math.deg(look_vec2:angle(diff_vec2))
            local cross = look_vec2.x * diff_vec2.y - look_vec2.y * diff_vec2.x

            if cross >= 0 then angle = -angle end
            angle = angle + 90

            local opacity = settings.fadeArrow and math.clamp(math.lerp(1, 0, (nearestCar.distanceToCamera - 15) / 15), 0, 1) or 1

            ui.beginRotation()
            ui.setCursor(vec2(212.5, 145))
            ui.image(app.images.arrow, vec2(75, 75), rgbm(1, 1, 1, opacity - 0.1))
            ui.endRotation(angle, vec2(0, 0))
        end
    end
end

--#endregion

--#region settings window

local manifest = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACAppsLua) .. '/nfs-mirror/manifest.ini', ac.INIFormat.Extended)
local appVersion = manifest:get('ABOUT', 'VERSION', 0.00)

function script.settings()
    --0.2.9-preview1
    if ac.getPatchVersionCode() >= 3425 then
        colors.userAccentColor = ac.getUI().accentColor
    end

    ui.tabBar('settings', function()
        ui.tabItem('App', function()
            app.scale = ui.slider('##', app.scale, 0.5, 1.5, 'App Scale: %.1f')
			if ui.itemHovered() and ui.mouseReleased(ui.MouseButton.Right) then app.scale = 1 end
			tooltip('Right-click to reset.', ui.MouseCursor.ResizeEW)

			if ui.checkbox('Force App to Center', settings.centerApp) then settings.centerApp = not settings.centerApp end

            if not isOnlineRace then
                ui.separator()

                ui.textDisabled('More options only avalible in online race.')
                return
            end

            ui.separator()
            ui.newLine(-12)

			if string.match(trackFolderName, 'shuto_revival_project') then
				if ui.checkbox('Speedtrap Warnings', settings.orbisIndicator) then settings.orbisIndicator = not settings.orbisIndicator end
                tooltip('Light indicator blinks when approaching a speedtrap.')
			end

            if ui.checkbox('Disable Indicators for Traffic Cars', settings.excludeAI) then settings.excludeAI = not settings.excludeAI end

            if ui.checkbox('Light Indicator', settings.lightsIndicator) then settings.lightsIndicator = not settings.lightsIndicator end

            if ui.checkbox('Arrow Indicator', settings.arrowIndicator) then settings.arrowIndicator = not settings.arrowIndicator end
            tooltip('Arrow that points in the direction of the nearest car relative to the camera.')

			if settings.arrowIndicator then
                ui.indent()

                if ui.checkbox('Arrow Fading', settings.fadeArrow) then settings.fadeArrow = not settings.fadeArrow end
                tooltip('Fades the arrow indicator in/out instead of appearing instantly.')

                ui.unindent()
            end

			if (settings.lightsIndicator or settings.arrowIndicator) then
                ui.indent()

				settings.indicatorActiveRange = ui.slider('##', settings.indicatorActiveRange, 5, 50, 'Activation Range: %.1fm')
                if ui.itemHovered() and ui.mouseReleased(ui.MouseButton.Right) then settings.indicatorActiveRange = 30 end
				tooltip('From how far away the indicators activate.\nRight-click to reset.', ui.MouseCursor.ResizeEW)

                ui.unindent()
			end
        end)

        ui.tabItem('About', function()
			ui.text('v' .. appVersion)

            ui.sameLine(0, 4)

            ui.text('– Licensed under the')

            ui.sameLine(0, 4)

            local licenseInfo = 'https://opensource.org/licenses/MIT'

            ui.textHyperlink('MIT License')
            if ui.itemHovered() and ui.mouseReleased(ui.MouseButton.Left) then os.openURL(licenseInfo, true) end

            ui.separator()
            ui.newLine(-5)

            ui.text('Encounter any bugs?')

            ui.pushStyleColor(ui.StyleColor.Button, colors.issueButton.idle)
            ui.pushStyleColor(ui.StyleColor.ButtonHovered, colors.issueButton.hovered)
            ui.pushStyleColor(ui.StyleColor.ButtonActive, colors.issueButton.active)

            local issueUrl = 'https://github.com/lint069/ac-nfs-mirror/issues/new' .. '?template=bug_report.yml'

            ui.setCursor(vec2(160, 85))
            if ui.button('Report Issue') then os.openURL(issueUrl, true) end
            tooltip('Requires a GitHub account.\nAlternatively, contact me on Discord: @wallpaperengineman', ui.MouseCursor.Hand)

            ui.popStyleColor(3)
        end)
    end)
end

--#endregion

function script.windowMain()
    updateOrbis()
    if settings.centerApp then centerApp() end

    drawMirror()
    drawRing()
    drawArrow()
    ui.setCursor(vec2(500, 193):scale(app.scale)) --temporary. AUTO_RESIZE is not working?
end
