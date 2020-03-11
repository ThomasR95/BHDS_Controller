xinput = require ('lua-xinput')

-- Xinput state
-- 1 - ms since start?
-- 2 - list of buttons:
--      dpadUp
--      dpadLeft
--      leftShoulder
--      b
--      leftThumb
--      dpadDown
--      dpadRight
--      back
--      y
--      rightThumb
--      rightShoulder
--      start
--      unknown
--      x
--      a
-- 3 - LT axis
-- 4 - RT axis
-- 5 - LS X
-- 6 - LS R
-- 7 - RS X
-- 8 - RS Y

-- the extent of the stick axis
extent = 32768.0

scrW = 256
scrH = 192
centreX = 127.0
centreY = 110.0
radius = 48

deadZone = 0.2
clicktimeout = 0
jumpCounter = 0

heroPosX = 24.0
heroPosY = 168.0
heroClick = 0

-- memory location for the flag telling us whether we are in the game or not
-- this seems to stay put at this address
locInGameFlag = 0x020E4098
ingame = 1

while true do

	ingame = memory.readbyte(locInGameFlag)

	-- Check joystick input from controller
    local xinput_data = {xinput.getState(0)}
    rTrigX = 0.0
    rTrigY = 0.0

	-- Get the input table
    local stylusInput = stylus.get()
    local joypadInput = joypad.get()

    -- Reset all the buttons because for some reason the state persists across frames
    joypadInput.A = false
    joypadInput.B = false
    joypadInput.X = false
    joypadInput.Y = false
    joypadInput.right = false
    joypadInput.left = false
    joypadInput.down = false
    joypadInput.up = false
    joypadInput.L = false
    joypadInput.R = false


	stylusInput.touch = false
    
    -- Check the input from the xbox controller
    if xinput_data then
        local btns = xinput_data[2]

        if btns then
            joypadInput.A = btns.b
            joypadInput.B = btns.a
            joypadInput.X = btns.y
            joypadInput.Y = btns.x
            joypadInput.right = btns.dpadRight
            joypadInput.left = btns.dpadLeft
            joypadInput.down = btns.dpadDown
            joypadInput.up = btns.dpadUp
            joypadInput.start = btns.start
            joypadInput.select = btns.back

			if btns.rightThumb and jumpCounter <= 0 and clicktimeout <= 0 then
				clicktimeout = 30
				jumpCounter = 8
            end
            
			if btns.leftShoulder and clicktimeout <= 0 then
				clicktimeout = 10
				heroClick = 2
			end
        end

        lTrig = (xinput_data[3]/255)
        rTrig = (xinput_data[4]/255)

        lStickX = (xinput_data[5]/extent)
        lStickY = (xinput_data[6]/extent)

        rStickX = (xinput_data[7]/extent)
		rStickY = (xinput_data[8]/extent)
	end
	
	-- Simulate a double-tap for jumping
	if jumpCounter > 0 then 
		if (jumpCounter <= 6 and jumpCounter >= 5)
		or
		(jumpCounter <= 2 and jumpCounter >= 0) then
			stylusInput.touch = true
			stylusInput.x = centreX
			stylusInput.y = centreY
		else
			stylusInput.touch = false
		end
		jumpCounter = jumpCounter-1 

	-- Simulate tapping the hero mode button
	elseif heroClick > 0 then
		stylusInput.x = heroPosX
		stylusInput.y = heroPosY
		stylusInput.touch = true
		lastX = centreX
		lastY = centreY
		heroClick = heroClick - 1
    end
    
    -- View with Right Stick
    if (rStickX > deadZone) then
        joypadInput.A = true
    elseif (rStickX < 0-deadZone) then
        joypadInput.Y = true
    end

    if (rStickY > deadZone*2) then
        joypadInput.X = true
    elseif (rStickY < 0-deadZone*2) then
        joypadInput.B = true
    end

    -- Movement with Left Stick
    if (lStickX > deadZone) then
        joypadInput.right = true
    elseif (lStickX < 0-deadZone) then
        joypadInput.left = true
    end

    if (lStickY > deadZone) then
        joypadInput.up = true
    elseif (lStickY < 0-deadZone) then
        joypadInput.down = true
    end

    -- Fire with RT
    if (rTrig > deadZone) then
        joypadInput.L = true
    end

    -- Action with LT
    if (lTrig > deadZone) then
        joypadInput.R = true
    end
    
    -- Submit the input to the emulator
    joypad.set(joypadInput)

	if ingame == 1 then
        stylus.set(stylusInput)

		-- Draw an indicator for where the simulated stylus is
		if stylusInput.touch then 
			gui.pixel(stylusInput.x, stylusInput.y, "yellow") 
		end
	end
	
	if clicktimeout > 0 then clicktimeout = clicktimeout - 1 end

	emu.frameadvance()
end
