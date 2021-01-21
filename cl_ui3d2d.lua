
ui3d2d = ui3d2d or {}

do --Input handling
    local getRenderTarget, cursorVisible = render.GetRenderTarget, vgui.CursorVisible

    local inputCount = 0

    hook.Add("KeyPress", "ui3d2d.inputHandler", function(ply, key)
        if key ~= IN_USE and key ~= IN_ATTACK then return end
        inputCount = inputCount + 1
    end)

    hook.Add("KeyRelease", "ui3d2d.inputHandler", function(ply, key)
        if key ~= IN_USE and key ~= IN_ATTACK then return end
        inputCount = inputCount - 1
    end)

    do
        local inputEnabled, isPressing, isPressed

        hook.Add("PreRender", "ui3d2d.inputHandler", function() --Check the input state before rendering UIs
            if getRenderTarget() then inputEnabled = false return end
            if cursorVisible() then inputEnabled = false return end

            inputEnabled = true

            local wasPressing = isPressing
            isPressing = inputCount > 0
            isPressed = not wasPressing and isPressing
        end)

        function ui3d2d.isPressing() --Returns true if an input is being held
            return inputEnabled and isPressing
        end

        function ui3d2d.isPressed() --Returns true if an input was pressed this frame
            return inputEnabled and isPressed
        end
    end
end

do --Rendering context creation and mouse position getters
    local localPlayer

    hook.Add("PreRender", "ui3d2d.getLocalPlayer", function() --Keep getting the local player until it's available
        localPlayer = LocalPlayer()
        if IsValid(localPlayer) then hook.Remove("PreRender", "ui3d2d.getLocalPlayer") end
    end)

    local traceLine = util.TraceLine

    local baseQuery = {filter = {}}

    local function isObstructed(eyePos, hitPos, ignoredEntity) --Check if the cursor trace is obstructed by another ent
        local query = baseQuery
        query.start = eyePos
        query.endpos = hitPos
        query.filter[1] = localPlayer
        query.filter[2] = ignoredEntity

        return traceLine(query).Hit
    end

    local mouseX, mouseY

    do
        local start3d2d = cam.Start3D2D
        local isCursorVisible, isHoveringWorld = vgui.CursorVisible, vgui.IsHoveringWorld
        local screenToVector, mousePos = gui.ScreenToVector, gui.MousePos
        local intersectRayWithPlane = util.IntersectRayWithPlane

        local isRendering

        function ui3d2d.startDraw(pos, angles, scale, ignoredEntity) --Starts a new 3d2d ui rendering context
            if isRendering then print("[ui3d2d] Attempted to draw a new 3d2d ui without ending the previous one.") return end

            local eyePos = localPlayer:EyePos()
            local eyePosToUi = pos - eyePos

            do --Only draw the UI if the player is in front of it
                local normal = angles:Up()
                local dot = eyePosToUi:Dot(normal)

                if dot >= 0 then return end
            end

            isRendering = true
            mouseX, mouseY = nil, nil

            start3d2d(pos, angles, scale)

            local cursorVisible, hoveringWorld = isCursorVisible(), isHoveringWorld()
            if not hoveringWorld and cursorVisible then return true end

            local eyeNormal
            do
                if cursorVisible and hoveringWorld then
                    eyeNormal = screenToVector(mousePos())
                else
                    eyeNormal = localPlayer:GetEyeTrace().Normal
                end
            end

            local hitPos = intersectRayWithPlane(eyePos, eyeNormal, pos, angles:Up())
            if not hitPos then return true end

            if isObstructed(eyePos, hitPos, ignoredEntity) then return true end

            do
                local diff = pos - hitPos
                mouseX = diff:Dot(-angles:Forward()) / scale
                mouseY = diff:Dot(-angles:Right()) / scale
            end

            return true
        end

        local end3d2d = cam.End3D2D

        function ui3d2d.endDraw() --Safely ends the 3d2d ui rendering context
            if not isRendering then print("[ui3d2d] Attempted to end a non-existant 3d2d ui rendering context.") return end
            isRendering = false
            end3d2d()
        end
    end

    function ui3d2d.getCursorPos() --Returns the current 3d2d cursor position
        return mouseX, mouseY
    end

    function ui3d2d.isHovering(x, y, w, h) --Returns whether the cursor is within a specified area
        local mx, my = mouseX, mouseY
        return mx and my and mx >= x and mx <= (x + w) and my >= y and my <= (y + h)
    end
end

hook.Run("ui3d2d.fullyLoaded")