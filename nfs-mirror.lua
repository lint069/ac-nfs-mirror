---@diagnostic disable: need-check-nil, lowercase-global

require 'orbis'

--#region tables

local settings = ac.storage {
    appScale = 1,
    centerApp = true,
    SimplifiedComposition = false,

    orbisIndicator = true,
    lightsIndicator = true,
    arrowIndicator = false,

    mirrorOpacity = 1,
    fadeArrow = true,
    excludeAI = false,
    indicatorActiveRange = 30, --in meters
}

local app = {
    version = 0.00,
    images = {
        mirror = '.\\assets\\mirror.dds',
        lights = '.\\assets\\led.png',
        arrow = '.\\assets\\arrow.png',
    },
}

local colors = {
    mirror = rgbm(0, 0, 0, 1),
    led = rgbm(0.74, 0.93, 0.25, 1),
    ledWarn = rgbm(0.98, 0.66, 0.25, 1),
    circleInner = rgbm(0.5, 0.6, 0.19, 0.8),
    circleFill = rgbm(0.26, 0.29, 0.12, 0.5),
    circleOuter = rgbm(0.36, 0.4, 0.22, 0.5),
    issueButton = {
        idle = rgbm(0.5, 0.2, 0.18, 1),
        hovered = rgbm(1, 0.3, 0.24, 1),
        active = rgbm(0.9, 0.38, 0.3, 1),
    },
}

local blink = {
    timer = 0,
    period = 1.5, --seconds
    lastState = 0
}

--#endregion

local sim = ac.getSim()
local isOnlineRace = sim.isOnlineRace
local trackFolderName = ac.getTrackID()
local cspVersion = ac.getPatchVersionCode()

--#region helper functions

---Scales input value by the app scale.
---@param value number
---@return number @Scaled value.
local function scale(value)
    return math.floor(value * settings.appScale)
end

---@param tooltipText string @Text to be displayed in the tooltip.
---@param cursorType? ui.MouseCursor @Changes the mouse cursor to given cursorType.
local function tooltip(tooltipText, cursorType)
    if ui.itemHovered() then
        if cursorType then ui.setMouseCursor(cursorType) end
        ui.tooltip(vec2(7, 4), function() ui.text(tooltipText) end)
    end
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

---@return integer @0: not in range, 1: 400m, 2: 200m, 3: 50m
local function getOrbisState()
	if not string.match(trackFolderName, 'shuto.*revival_project') then
		return 0
	end

	local orbisPos = getOrbisPositions()
	local carPos = ac.getCar(sim.focusedCar).position
	local dist = 500

	for i = 1, #orbisPos do
		if dist > math.sqrt((carPos.x - orbisPos[i].x) ^ 2 + (carPos.z - orbisPos[i].z) ^ 2) then
			dist = math.sqrt((carPos.x - orbisPos[i].x) ^ 2 + (carPos.z - orbisPos[i].z) ^ 2)
		end
	end

	if dist < 50 then
		return 3
    elseif dist < 200 then
        return 2
    elseif dist < 400 then
        return 1
	else
		return 0
	end
end

local function updateColors()
	colors.mirror:set(rgb(1, 1, 1), settings.mirrorOpacity)

	if settings.orbisIndicator and getOrbisState() > 0 then
		colors.circleFill:set(rgbm(0.68, 0.46, 0.15, colors.circleFill.mult))
		colors.circleOuter:set(rgbm(0.48, 0.3, 0.1, colors.circleOuter.mult))
		colors.circleInner:set(rgbm(0.88, 0.6, 0.2, colors.circleInner.mult))
	else
		colors.circleFill:set(rgbm(0.26, 0.29, 0.12, 0.5))
		colors.circleOuter:set(rgbm(0.36, 0.4, 0.22, 0.5))
		colors.circleInner:set(rgbm(0.5, 0.6, 0.19, 0.8))
	end
end

--#endregion

--#region drawing functions

local function drawMirror()
    local virtualMirrorPos = vec2(15, 16):scale(settings.appScale)
    local virtualMirrorSize = vec2(471, 130):scale(settings.appScale)
    local whitePoint = 1.3 - (sim.lightSuggestion * 0.5) --this needs adjusting

    ui.beginTonemapping()
    ui.drawVirtualMirror(virtualMirrorPos, virtualMirrorPos + virtualMirrorSize)
    ui.endTonemapping(1, 0.8, true)

    local mirrorPos = vec2(0, 0)
    local mirrorSize = vec2(500, 190):scale(settings.appScale)

    ui.drawImage(app.images.mirror, mirrorPos, mirrorPos + mirrorSize, colors.mirror)
end

local function drawRing()
    local center = vec2(250, 180):scale(settings.appScale)
    local arcStart, arcEnd = math.rad(180), math.rad(360)
    local radiusInner, radiusOuter = scale(16), scale(26)
    local segments = 22
    local arcThickness = scale(4)

    --using 4 segments here for most likely an unnoticeable performance gain
    ui.pathArcTo(center, radiusInner, arcStart, arcEnd, 4)
    ui.pathFillConvex(colors.circleFill)

    ui.pathArcTo(center, radiusOuter, arcStart, arcEnd, segments)
    ui.pathStroke(colors.circleOuter, false, arcThickness)

    ui.pathArcTo(center, radiusInner, arcStart, arcEnd, segments)
    ui.pathStroke(colors.circleInner, false, arcThickness)
end

---@param dt number @Delta Time
local function drawWarning(dt)
    local lightPos = vec2(20, 135):scale(settings.appScale)
    local lightSize = vec2(459, 68):scale(settings.appScale)
    local orbisState = getOrbisState()
    local orbisActive = settings.orbisIndicator and orbisState > 0

	if orbisState ~= blink.lastState then
		blink.timer = 0
		blink.lastState = orbisState
	end

    if orbisState == 1 then
        blink.period = 1.5
    elseif orbisState == 2 then
        blink.period = 0.8
    elseif orbisState == 3 then
        blink.period = 0.25
    end

    blink.timer = blink.timer + dt

    if orbisActive and (blink.timer % blink.period) < (blink.period * 0.5) then
        ui.drawImage(app.images.lights, lightPos, lightPos + lightSize, colors.ledWarn)
    end
end

local function drawLight()
    local lightPos = vec2(20, 135):scale(settings.appScale)
    local lightSize = vec2(459, 68):scale(settings.appScale)

    local nearestCar = ac.getCar.ordered(1)
    if nearestCar == nil then return end

    local orbisActive = settings.orbisIndicator and getOrbisState() > 0
    local inRange = nearestCar.distanceToCamera <= settings.indicatorActiveRange

    if not inRange or orbisActive or (settings.excludeAI and nearestCar.isHidingLabels) then return end

	if settings.lightsIndicator then
		ui.drawImage(app.images.lights, lightPos, lightPos + lightSize, colors.led)
	end
end

local function drawArrow()
    local playerCar = ac.getCar.ordered(0)
    local nearestCar = ac.getCar.ordered(1)
    if nearestCar == nil then return end

    local inRange = nearestCar.distanceToCamera <= settings.indicatorActiveRange
    local orbisActive = settings.orbisIndicator and getOrbisState() > 0

    local arrowPos = vec2(223, 152):scale(settings.appScale)
    local arrowSize = vec2(55, 55):scale(settings.appScale)

    if not inRange or orbisActive or (settings.excludeAI and nearestCar.isHidingLabels) then return end

    if settings.arrowIndicator then
        local lookVec3 = playerCar.look
        local diffVec3 = nearestCar.position - playerCar.position

        local lookVec2 = vec2(lookVec3.x, lookVec3.z)
        local diffVec2 = vec2(diffVec3.x, diffVec3.z)

        local angle = math.deg(lookVec2:angle(diffVec2))
        local cross = lookVec2.x * diffVec2.y - lookVec2.y * diffVec2.x

        if cross >= 0 then
            angle = -angle
        end

        angle = angle + 90

        local startFade = settings.indicatorActiveRange / 2
        local fadeLength = settings.indicatorActiveRange - startFade
        local opacity = settings.fadeArrow and math.lerp(1, 0, math.clamp((nearestCar.distanceToCamera - startFade) / fadeLength, 0, 1)) or 1

        ui.beginRotation()
        ui.drawImage(app.images.arrow, arrowPos, arrowPos + arrowSize, rgbm(1, 1, 1, opacity - 0.1))
        ui.endRotation(angle)
    end
end

--#endregion

--#region settings window

function script.settings()
    ui.tabBar('settings', function()
        ui.tabItem('App', function()
			if ui.checkbox('Force App to Center', settings.centerApp) then settings.centerApp = not settings.centerApp end

            --0.3.0-preview110
            if cspVersion >= 3637 then
                if ui.checkbox('Disable ImGui Frost Effect', settings.SimplifiedComposition) then settings.SimplifiedComposition = not settings.SimplifiedComposition end
            end

            settings.mirrorOpacity = ui.slider('##mirrorOpacity', settings.mirrorOpacity, 0.75, 1, string.format('Opacity: %.0f%%%%', settings.mirrorOpacity * 100))
            if ui.itemHovered() then ui.setMouseCursor(ui.MouseCursor.ResizeEW) end

            settings.appScale = ui.slider('##appScale', settings.appScale, 0.5, 1.5, 'App Scale: %.1f')
            if ui.itemHovered() then ui.setMouseCursor(ui.MouseCursor.ResizeEW) end
        end)

        ui.tabItem('Indicators', function()
            if string.match(trackFolderName, 'shuto_revival_project') then
				if ui.checkbox('Speed Camera Warnings', settings.orbisIndicator) then settings.orbisIndicator = not settings.orbisIndicator end
                tooltip('Light indicator blinks when approaching a speedtrap.\nDisables every other indicator when active.')
			end

            if ui.checkbox('Light Indicator', settings.lightsIndicator) then settings.lightsIndicator = not settings.lightsIndicator end
            tooltip('Lights up when within the activation range of a car.')

            if ui.checkbox('Arrow Indicator', settings.arrowIndicator) then settings.arrowIndicator = not settings.arrowIndicator end
            tooltip('Points toward the nearest car relative to the camera.')

			if (settings.lightsIndicator or settings.arrowIndicator) then
                ui.indent()

                if settings.arrowIndicator then
                    if ui.checkbox('Fade Arrow', settings.fadeArrow) then settings.fadeArrow = not settings.fadeArrow end
                    tooltip('Fades the arrow indicator in/out.')
                end

                if isOnlineRace then
                    if ui.checkbox('Disable Indicators for Traffic Cars', settings.excludeAI) then settings.excludeAI = not settings.excludeAI end
                end

				settings.indicatorActiveRange = ui.slider('##indicatorActiveRange', settings.indicatorActiveRange, 5, 50, 'Activation Range: %.0fm')
                tooltip('From how far away the indicators activate.', ui.MouseCursor.ResizeEW)

                ui.unindent()
			end
        end)

        ui.tabItem('About', function()
			ui.text('v' .. app.version)

            ui.sameLine(0, 4)

            ui.text('– Licensed under')

            ui.sameLine(0, 4)

            local licenseInfoURL = 'https://opensource.org/licenses/MIT'

            ui.textHyperlink('The MIT License')
            if ui.itemHovered() and ui.mouseReleased(ui.MouseButton.Left) then os.openURL(licenseInfoURL, true) end
            if ui.mouseDelta():length() < 0.1 then tooltip(licenseInfoURL) end

            ui.separator()
            ui.newLine(-7)

            ui.text('Encountering a bug?')

            ui.pushStyleColor(ui.StyleColor.Button, colors.issueButton.idle)
            ui.pushStyleColor(ui.StyleColor.ButtonHovered, colors.issueButton.hovered)
            ui.pushStyleColor(ui.StyleColor.ButtonActive, colors.issueButton.active)

            local issueUrl = 'https://github.com/lint069/ac-nfs-mirror/issues/new' .. '?template=bug_report.yml'

            ui.setCursor(vec2(145, 82))
            if ui.button('Report an issue') then os.openURL(issueUrl, true) end
            tooltip('Requires a GitHub account.\nAlternatively, you can contact me on Discord: @wallpaperengineman', ui.MouseCursor.Hand)

            ui.popStyleColor(3)
        end)
    end)
end

--#endregion

--#region script init

function script.init()
    local manifest = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACAppsLua) .. '/nfs-mirror/manifest.ini', ac.INIFormat.Extended)
    app.version = manifest:get('ABOUT', 'VERSION', 0.00)
end

--#endregion

--#region main window

function script.windowMain(dt)
    updateColors()

    if settings.SimplifiedComposition then ui.forceSimplifiedComposition(true) end
    if settings.centerApp then centerApp() end

    local size = vec2(500, 211):scale(settings.appScale)

    ui.childWindow('mirror', vec2(size.x, size.y), function()
        drawMirror()
        drawRing()
        drawArrow()
        drawLight()
        drawWarning(dt)
    end)
end

--#endregion
