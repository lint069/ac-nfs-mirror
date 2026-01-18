---@diagnostic disable: need-check-nil

require 'orbis'

--#region tables

local settings = ac.storage {
    appScale = 1,
    centerApp = true,

    orbisIndicator = true,
    lightsIndicator = true,
    arrowIndicator = false,

    mirrorTransparent = false,
    fadeArrow = true,
    excludeAI = false,
    indicatorActiveRange = 30, --in meters
}

local app = {
    version = 0.00,
    images = {
        mirror = '.\\assets\\mirror.dds',
        lights = '.\\assets\\lights.dds',
        arrow = '.\\assets\\arrow.dds',
    },
}

local colors = {
    mirror = rgbm(1, 1, 1, 1),

    circleInner = rgbm(0.5, 0.6, 0.19, 0.9),
    circleFill = rgbm(0.26, 0.29, 0.12, 0.8),
    circleOuter = rgbm(0.36, 0.4, 0.22, 0.6),

    issueButton = {
        idle = rgbm(0.5, 0.2, 0.18, 1),
        hovered = rgbm(1, 0.3, 0.24, 1),
        active = rgbm(0.9, 0.38, 0.3, 1),
    },
}

--#endregion

local sim = ac.getSim()
local isOnlineRace = sim.isOnlineRace
local trackFolderName = ac.getTrackID()

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
        if not ui.isMouseDragging(ui.MouseButton.Left, 25) then
            ui.tooltip(vec2(7, 4), function() ui.text(tooltipText) end)
        end
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

---@return boolean @Returns true if the currently focused car is in the range of 400m of any orbis.
local function isOrbisInRange()
	if not string.match(trackFolderName, "shuto_revival_project") then
		return false
	end

	local orbisPos = getOrbisPositions()
	local carPos = ac.getCar(sim.focusedCar).position
	local dist = 500

	for i = 1, #orbisPos do
		if dist > math.sqrt((carPos.x - orbisPos[i].x) ^ 2 + (carPos.z - orbisPos[i].z) ^ 2) then
			dist = math.sqrt((carPos.x - orbisPos[i].x) ^ 2 + (carPos.z - orbisPos[i].z) ^ 2)
		end
	end

	if dist <= 400 then
		return true
	else
		return false
	end
end

--#endregion

--#region drawing functions

local function drawMirror()
    local virtualMirrorPos = vec2(15, 16):scale(settings.appScale)
    local virtualMirrorSize = vec2(471, 132):scale(settings.appScale)
    local whitePoint = 1.3 - (sim.lightSuggestion * 0.5)

    ui.beginTonemapping()
    ui.drawVirtualMirror(virtualMirrorPos, virtualMirrorPos + virtualMirrorSize)
    ui.endTonemapping(1, whitePoint, true) --FIXME: !?

    local mirrorPos = vec2(0, 0)
    local mirrorSize = vec2(500, 193):scale(settings.appScale)

    ui.drawImage(app.images.mirror, mirrorPos, mirrorPos + mirrorSize, colors.mirror)
end

local function drawRing()
    local center = vec2(250, 183):scale(settings.appScale)
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

local function drawLight()
    local lightPos = vec2(0, 0)
    local lightSize = vec2(500, 200)

    local blinkPeriod = 0.5 --seconds
    local onFraction = 0.5 --percent `1.0 = 100%`

    local nearestCar = ac.getCar.ordered(1)
    if nearestCar == nil then return end

    local nearestIsAI = nearestCar.isHidingLabels
    local inRange = nearestCar.distanceToCamera <= settings.indicatorActiveRange
    local orbisActive = settings.orbisIndicator and isOrbisInRange()

    if orbisActive and (sim.time % blinkPeriod) < (blinkPeriod * onFraction) then
        ui.drawImage(app.images.lights, lightPos, lightPos + lightSize, rgbm.colors.white)
    end

    if not inRange or orbisActive or (settings.excludeAI and nearestIsAI) then return end

	if settings.lightsIndicator then
		ui.drawImage(app.images.lights, lightPos, lightPos + lightSize, rgbm.colors.white)
	end
end

local function drawArrow()
    if not isOnlineRace then return end

    local nearestCar = ac.getCar.ordered(1)
    if nearestCar == nil then return end

    --[[ nearestCar.isRemote | nearestCar.isAIControlled ]]
    local nearestIsAI = nearestCar.isHidingLabels
    local inRange = nearestCar.distanceToCamera <= settings.indicatorActiveRange
    local orbisActive = settings.orbisIndicator and isOrbisInRange()

    local arrowPos = vec2(210, 145)
    local arrowSize = vec2(70, 70)

    if orbisActive or not inRange or (nearestIsAI and settings.excludeAI) then return end

    if settings.arrowIndicator then
        local look_vec3 = ac.getCar.ordered(0).look
        local diff_vec3 = nearestCar.position - ac.getCar.ordered(0).position

        local look_vec2 = vec2(look_vec3.x, look_vec3.z)
        local diff_vec2 = vec2(diff_vec3.x, diff_vec3.z)
        local angle = math.deg(look_vec2:angle(diff_vec2))
        local cross = look_vec2.x * diff_vec2.y - look_vec2.y * diff_vec2.x

        if cross >= 0 then angle = -angle end
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

            if ui.checkbox('Transparency', settings.mirrorTransparent) then settings.mirrorTransparent = not settings.mirrorTransparent end
            tooltip('Toggles mirror transparency.\nLimited to avoid exposing the ugly virtual mirror edges.')

            settings.appScale = ui.slider('##appScale', settings.appScale, 0.5, 1.5, 'App Scale: %.1f')
            if ui.itemHovered() then ui.setMouseCursor(ui.MouseCursor.ResizeEW) end
        end)

        ui.tabItem('Indicators', function()
            if not isOnlineRace then return end

            if string.match(trackFolderName, 'shuto_revival_project') then
				if ui.checkbox('Speed Camera Warnings', settings.orbisIndicator) then settings.orbisIndicator = not settings.orbisIndicator end
                tooltip('Light indicator blinks when approaching a speedtrap.')
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

                if ui.checkbox('Disable Indicators for Traffic Cars', settings.excludeAI) then settings.excludeAI = not settings.excludeAI end

				settings.indicatorActiveRange = ui.slider('##indicatorActiveRange', settings.indicatorActiveRange, 5, 50, 'Activation Range: %.0fm')
				tooltip('From how far away the indicators activate.\nNot including orbis warnings.', ui.MouseCursor.ResizeEW)

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

            ui.setCursor(vec2(143, 82))
            if ui.button('Report an issue') then os.openURL(issueUrl, true) end
            tooltip('Requires a GitHub account.\nAlternatively, you can contact me on Discord: @wallpaperengineman', ui.MouseCursor.Hand)

            ui.popStyleColor(3)
        end)
    end)
end

--#endregion

--#region main window

function script.windowMain()
    if settings.centerApp then centerApp() end

    colors.mirror:set(rgb(1, 1, 1), settings.mirrorTransparent and 0.8 or 1)

    local manifest = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACAppsLua) .. '/nfs-mirror/manifest.ini', ac.INIFormat.Extended)
    app.version = manifest:get('ABOUT', 'VERSION', 0.00)

    local size = vec2(500, 195):scale(settings.appScale)

    ui.childWindow('mirror', vec2(size.x, size.y), function()
        drawMirror()
        drawRing()
        drawArrow()
        drawLight()
    end)
end

--#endregion
