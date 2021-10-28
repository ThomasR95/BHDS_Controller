xinput = require ('lua-xinput')

-- ADJUST THESE VALUES IF NECESSARY

-- The deadzone (ineffective range) for the controller analog sticks
-- Higher values mean you have to move the stick more to start moving
-- Range 0.0 - 1.0, recommended 0.2
viewDeadZone = 0.2

-- The multiplier for the view (right) analog stick movement speed
-- Higher values mean you turn faster
-- Any value. Recommended 350
lookSpeed=350

-- The rate at which the player's view movement speed will accelerate, 
-- whilst the RStick is held at full tilt
-- Any value, recommended 0.02
rStickFullLockAcceleration = 0.02
-- The threshold value which will be considered "full tilt" for the analog stick
-- Range 0.0 - 1.0, recommended 0.95
rStickFullLockThreshold = 0.95


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

-- memory locations for the player data
-- This location is constant, and its value points close to the actual location of the player data which moves
locPlayerDataPtr = 0x020E40F0
-- The offset of the player's X view axis value, from the aforementioned pointer
playerDataLookOffset = 0x00000454
locXAxisValue=0
locYAxisValue=0

-- The closest location in memory to playerDataPtr, which has a unique value for each character
-- Numbers don't match as one might think:
-- 0=gray, 1=Kongu, 2=Nuparu, 3=Jaller, 4=Matoro, 5=Hewkii, 6=Hahli
locToaSelected = 0x020E3627
toaSelected = 0
toaSelectIdx = 0
lastToaSelected = 0
selectOrder = {0, 3, 2, 6, 1, 5, 4}
selectCoords = {}
for c=1,7 do selectCoords[c] = {} end
selectCoords[1][1] = 26; selectCoords[1][2] = 24
selectCoords[2][1] = 60; selectCoords[2][2] = 15
selectCoords[3][1] = 94; selectCoords[3][2] = 13
selectCoords[4][1] = 126; selectCoords[4][2] = 13
selectCoords[5][1] = 162; selectCoords[5][2] = 13
selectCoords[6][1] = 196; selectCoords[6][2] = 15
selectCoords[7][1] = 230; selectCoords[7][2] = 21

scopeZoomed = false
leftTrigHeldLastFrame = false
scopeZoomTimeout = 50
scopeBtnTimeout = 0
frozenLTrigVal = 0

-- for player movement hacks, unused/unfinished
playerDataPosOffset = 0x000000D8
moveDeadZone = 0.4
locPosXValue = 0
locPosYValue = 0

playerDataInputOffset = 0x000004C4
inputFlagLoc = 0
inputFlagU=256
inputFlagD=1792
inputFlagL=1024
inputFlagR=1280
moveSpeed=5000
-- 

hackBtnCounter = 16
hackFrameCounter = 0
doingHackInput = 0

rStickFullLockTime = 0

enableNoClip = true
enableHackWithAKey = false
showDebugText = 0

-- This is a function that helps print the decimal values as hexadecimals
function DEC_HEX(IN)
    local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
    while IN>0 do
        I=I+1
        IN,D=math.floor(IN/B),math.mod(IN,B)+1
        OUT=string.sub(K,D,D)..OUT
    end
    return OUT
end

-- Modifies the player's position values directly, ignoring physics
function noclip_rightStick()
	gui.text(0,2,"NOCLIP ENABLED (rStick)")
	gui.text(0,26,"V to disable")
	playerXPos = 1.0 * memory.readdword(locPosXValue)
	playerYPos = 1.0 * memory.readdword(locPosYValue)

	-- make these into signed values in the dumbest hackiest way possible
	if(playerXPos > 0x8000000) then playerXPos = (playerXPos - 0xffffffff) - 1 end
	if(playerYPos > 0x8000000) then playerYPos = (playerYPos - 0xffffffff) - 1 end
	gui.text(0,10,"xPos: " .. playerXPos )
	gui.text(0,18,"yPos: " .. playerYPos )

    -- Movement with Left Stick
    if (math.abs(lStickX) > moveDeadZone) then
		memory.writedword(locPosXValue, playerXPos+lStickX*moveSpeed);
    end

    if (math.abs(lStickY) > moveDeadZone) then
		memory.writedword(locPosYValue, playerYPos+lStickY*moveSpeed);
    end
end

function doHackInput()
	-- hacks for modding
	local keys = input.get()
	if keys.A == true then
		doingHackInput = 1
		memory.writeword(locXAxisValue, 0)
	end
	if doingHackInput == 1 and ingame == 1 then
		if hackFrameCounter % 20 == 0 then
			joypadInput.right = true;
			gui.text(0,0,"hack" )
			hackBtnCounter = hackBtnCounter - 1
		end
		hackFrameCounter = hackFrameCounter + 1
	end
	if hackBtnCounter <= 0 then
		hackBtnCounter = 16
		doingHackInput = 0
		hackFrameCounter = 0
	end
end

-- Main loop ----------------------------------------------------------------------------------------------------------
while true do

	ingame = memory.readbyte(locInGameFlag)
	if ingame == 0 then
		-- Forget location of look axis values, as they may change
		locXAxisValue=0
		locYAxisValue=0
		locPosXValue = 0
		locPosYValue = 0
	elseif locXAxisValue == 0 then
		-- Use the pointer to the Player Data location to find the location of the axis values
		playerDataPtr = memory.readdword(locPlayerDataPtr)
		--playerData2Ptr = memory.readdword(locPlayerData2Ptr)
		locXAxisValue = playerDataPtr + playerDataLookOffset
		locYAxisValue = locXAxisValue + 0x00000002
		inputFlagLoc = playerDataPtr + playerDataInputOffset
		locPosXValue = playerDataPtr + playerDataPosOffset
		locPosYValue = locPosXValue + 8
		
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
        btns = xinput_data[2]

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
		-- Check what character we have selected
		toaSelected = memory.readbyte(locToaSelected)
		if not (toaSelected == lastToaSelected) then
			scopeZoomed = false
			scopeZoomTimeout = 0
		end
		lastToaSelected = toaSelected
		for i=1,7 do
			if selectOrder[i] == toaSelected then
				toaSelectIdx = i
			end
		end

		-- in a level, use the DPad to select toa
		joypadInput.right = false
        joypadInput.left = false
        joypadInput.down = false
        joypadInput.up = false
		
		toaSelectChanged = false
		if btns.dpadLeft then
			toaSelectIdx = toaSelectIdx - 1
			if toaSelectIdx < 1 then toaSelectIdx = 7 end
			toaSelectChanged = true
		elseif btns.dpadRight then
			toaSelectIdx = toaSelectIdx + 1
			if toaSelectIdx > 7 then toaSelectIdx = 1 end
			toaSelectChanged = true
		end
			
		if toaSelectChanged then
			stylusInput.touch = true
			stylusInput.x = selectCoords[toaSelectIdx][1]
			stylusInput.y = selectCoords[toaSelectIdx][2]
		end
		
	
		-- View with Right Stick
		
		local xAxis = memory.readword(locXAxisValue)
		local yAxis = memory.readword(locYAxisValue)
		
		local moveMagnitude = math.sqrt(rStickX*rStickX + rStickY*rStickY)
		
		local actualLookSpeed = lookSpeed
		
		if moveMagnitude > rStickFullLockThreshold then
			rStickFullLockTime = rStickFullLockTime + 1
		else
			rStickFullLockTime = 0
		end
		
		if rStickFullLockTime > 0 then
			actualLookSpeed = actualLookSpeed * (1.0+math.min(rStickFullLockTime*rStickFullLockAcceleration, 1.5))
		end
		
		if scopeZoomed then
			actualLookSpeed = actualLookSpeed * 0.3
		end
		
		local xVel = math.pow(rStickX, viewCurve)*actualLookSpeed
		local yVel = math.pow(rStickY, viewCurve)*actualLookSpeed
		
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
		
		--local  inputFlag = memory.readbyte(inputFlagLoc+0x1)
		
		-- for debugging
		if showDebugText == 1 then
			gui.text(0,2,"data: " .. DEC_HEX(playerDataPtr) )
			gui.text(0,10,"toa: " .. toaSelected .. " idx: " .. toaSelectIdx)
			gui.text(0,18,"scope: " .. tostring(scopeZoomed) )
		elseif showDebugText == 2 then
			gui.text(0,2,"X: " .. DEC_HEX(locXAxisValue) .. ": " .. xAxis)
			gui.text(0,10,"Y: " .. DEC_HEX(locYAxisValue) .. ": " .. yAxis)
		elseif showDebugText == 3 then
			gui.text(0,2,"mag: " .. moveMagnitude )
			gui.text(0,10,"lookspeed: " .. actualLookSpeed )
		end
	end

    -- Movement with Left Stick
	if not enableNoClip then
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
	end

    -- Fire with RT
    if (rTrig > 0.2) then
        joypadInput.L = true
    end

	-- Freeze the LTrigger value to allow time for the scope animation
	if scopeZoomTimeout > 0 then
		scopeZoomTimeout = scopeZoomTimeout - 1
		lTrig = frozenLTrigVal
	end

    -- Action with LT
    if (lTrig > 0.2) then
		if toaSelected == 4 then
		-- Special case for matoro's scope - hold to zoom
			if not leftTrigHeldLastFrame then
				scopeZoomed = not scopeZoomed
				joypadInput.R = true
				scopeBtnTimeout = 3
				scopeZoomTimeout = 50
				frozenLTrigVal = lTrig
			elseif scopeBtnTimeout > 0 then
				scopeBtnTimeout = scopeBtnTimeout - 1
				joypadInput.R = true
			else
				joypadInput.R = false
			end
		else
			joypadInput.R = true
		end
		leftTrigHeldLastFrame = true
	else	
		if toaSelected == 4 and leftTrigHeldLastFrame and scopeZoomed then
		-- Undo scope on release
			scopeZoomed = false
			joypadInput.R = true
			scopeBtnTimeout = -3
			scopeZoomTimeout = 50
			frozenLTrigVal = lTrig
		elseif scopeBtnTimeout < 0 then
			scopeBtnTimeout = scopeBtnTimeout + 1
			joypadInput.R = true
		end
		leftTrigHeldLastFrame = false
    end
	
	
	-- hacky bits
	if enableHackWithAKey then doHackInput() end
	if enableNoClip then noclip_rightStick() end
	keys = input.get()
	if clicktimeout == 0 then
	if keys.V then 
		enableNoClip = not enableNoClip
		clicktimeout = 10
	end
	if keys.D then 
		showDebugText = showDebugText + 1; if showDebugText > 3 then showDebugText = 0 end
		clicktimeout = 10
	end
	end
    
    -- Submit the input to the emulator
    joypad.set(joypadInput)

	if ingame == 1 then
		-- Draw an indicator for where the simulated stylus is
		if stylusInput.touch then 
			stylus.set(stylusInput)
			gui.box(stylusInput.x-3, stylusInput.y-3, stylusInput.x+3, stylusInput.y+3, 0xffff00ff) 
		end
	end
	
	if clicktimeout > 0 then clicktimeout = clicktimeout - 1 end

	emu.frameadvance()
end
