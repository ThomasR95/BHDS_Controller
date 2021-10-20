xinput = require ('lua-xinput')

-- ADJUST THESE VALUES IF NECESSARY

-- The deadzone (ineffective range) for the controller analog sticks
-- Higher values mean you have to move the stick more to start moving
-- Range 0.0 - 1.0, recommended 0.2
viewDeadZone = 0.2
moveDeadZone = 0.5

-- The multiplier for the view (right) analog stick movement speed
-- Higher values mean you turn faster
-- Any value. Recommended 400
lookSpeed=400

-- The power of the right analog stick.
-- Higher power means smaller stick adjustments will have less effect on the view movement.
-- Odd numbers 1 - 7. Recommended 3. Even numbers will break view movement.
viewCurve=3

-- DO NOT MODIFY ANYTHING BELOW THIS POINT


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

clicktimeout = 0
jumpCounter = 0

heroPosX = 24.0
heroPosY = 168.0
heroClick = 0

-- memory location for the flag telling us whether we are in the game or not
-- this seems to stay put at this address
locInGameFlag = 0x020E4098
ingame = 1

locPlayerDataPtr = 0x020E40F0
playerDataLookOffset = 0x00000454
locXAxisValue=0
locYAxisValue=0

hackBtnCounter = 16
hackFrameCounter = 0
doingHackInput = 0

function DEC_HEX(IN)
    local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
    while IN>0 do
        I=I+1
        IN,D=math.floor(IN/B),math.mod(IN,B)+1
        OUT=string.sub(K,D,D)..OUT
    end
    return OUT
end

while true do

	ingame = memory.readbyte(locInGameFlag)
	if ingame == 0 then
		-- Forget location of look axis values, as they may change
		locXAxisValue=0
		locYAxisValue=0
	elseif locXAxisValue == 0 then
		-- Use the pointer to the Player Data location to find the location of the axis values
		playerDataPtr = memory.readdword(locPlayerDataPtr)
		locXAxisValue = playerDataPtr + playerDataLookOffset
		locYAxisValue = locXAxisValue + 0x00000002
	end

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
			-- Directly translate some buttons from the controller to the emulator
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
    
	if ingame == 1 then
		-- View with Right Stick
		
--old button method
		--if (rStickX > deadZone) then
			--joypadInput.A = true
		--elseif (rStickX < 0-deadZone) then
			--joypadInput.Y = true
		--end
		--if (rStickY > deadZone*2) then
			--joypadInput.X = true
		--elseif (rStickY < 0-deadZone*2) then
			--joypadInput.B = true
		--end
-------------------
		
		local xAxis = memory.readword(locXAxisValue)
		local yAxis = memory.readword(locYAxisValue)
		
		local moveMagnitude = math.sqrt(rStickX*rStickX + rStickY*rStickY)
		
		local xVel = math.pow(rStickX, viewCurve)*lookSpeed
		local yVel = math.pow(rStickY, viewCurve)*lookSpeed
		
		if (moveMagnitude > viewDeadZone) then
			xAxis = xAxis - xVel
			yAxis = yAxis - yVel
		end
		
		-- Wrap the axis values
		if xAxis < 0 then
			xAxis = xAxis + 65535
		elseif xAxis > 65535 then
			xAxis = xAxis - 65535
		end
		
		if yAxis < 0 then
			yAxis = yAxis + 65535
		elseif yAxis > 65535 then
			yAxis = yAxis - 65535
		end
		
		memory.writeword(locXAxisValue, xAxis)
		memory.writeword(locYAxisValue, yAxis)
		
		-- for debugging
		--gui.text(0,16,"data: " .. DEC_HEX(playerDataPtr) )
		--gui.text(0,0,"X: " .. DEC_HEX(locXAxisValue) .. ": " .. xAxis)
		--gui.text(0,8,"Y: " .. DEC_HEX(locYAxisValue) .. ": " .. yAxis)
		
		--gui.text(0,0,"X: " .. xVel )
		--gui.text(0,8,"Y: " .. yVel )
		--gui.text(0,16,"mag: " .. moveMagnitude )

	end

    -- Movement with Left Stick
    if (lStickX > moveDeadZone) then
        joypadInput.right = true
    elseif (lStickX < 0-moveDeadZone) then
        joypadInput.left = true
    end

    if (lStickY > moveDeadZone) then
        joypadInput.up = true
    elseif (lStickY < 0-moveDeadZone) then
        joypadInput.down = true
    end

    -- Fire with RT
    if (rTrig > 0.2) then
        joypadInput.L = true
    end

    -- Action with LT
    if (lTrig > 0.2) then
        joypadInput.R = true
    end
	
	-- hacks for modding
	-- local keys = input.get()
	-- if keys.A == true then
		-- doingHackInput = 1
	-- end
	-- if doingHackInput == 1 then
		-- if hackFrameCounter % 20 == 0 then
			-- joypadInput.A = true;
			-- hackBtnCounter = hackBtnCounter - 1
		-- end
		-- hackFrameCounter = hackFrameCounter + 1
	-- end
	-- if hackBtnCounter <= 0 then
		-- hackBtnCounter = 16
		-- doingHackInput = 0
		-- hackFrameCounter = 0
	-- end
	
    
    -- Submit the input to the emulator
    joypad.set(joypadInput)

	if ingame == 1 then
        stylus.set(stylusInput)

		-- Draw an indicator for where the simulated stylus is
		if stylusInput.touch or clicktimeout > 0 then 
			gui.box(stylusInput.x-3, stylusInput.y-3, stylusInput.x+3, stylusInput.y+3, 0xffff00ff) 
		end
	end
	
	if clicktimeout > 0 then clicktimeout = clicktimeout - 1 end

	emu.frameadvance()
end
