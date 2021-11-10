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
locPlayerDataPtr2offset = 0x00000498
locPlayerDataPtr2 = 0
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
locPosZValue = 0

playerDataVelOffset = 0x00000074
playerDataMoveFlagOffset = 0x000000FC
xAngle = 0
locXVel = 0
locYVel = 0
locMoveFlag = 0
walkSpeed = 10240

-- fov offset from playerdataptr 2
fovDataOffset=0x00000390
locFOVData=0
fov=0
-- 

hackBtnCounter = 16
hackFrameCounter = 0
doingHackInput = 0

rStickFullLockTime = 0

enableNoClip = false
moveSpeed = 5000
enableHackWithAKey = false
showDebugText = 0

sprintFOV = false
playerMoving = false

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

function RotateVector(inX, inY, angle)
	local outX = math.cos(angle)*inX - math.sin(angle)*inY
	local outY = math.sin(angle)*inX + math.cos(angle)*inY
	local outPair = {0,0}
	outPair[1] = outX
	outPair[2] = outY
	return outPair
end

-- Modifies the player's position values directly, ignoring physics
function noclip_rightStick(joypadInput)

	joypadInput.A = false
    joypadInput.B = false
    joypadInput.X = false
    joypadInput.Y = false

	gui.text(0,2,"NOCLIP ENABLED (rStick) - V to disable")
	playerXPos = 1.0 * memory.readdword(locPosXValue)
	playerYPos = 1.0 * memory.readdword(locPosYValue)
	playerZPos = 1.0 * memory.readdword(locPosZValue)

	-- make these into signed values in the dumbest hackiest way possible
	if(playerXPos > 0x8000000) then playerXPos = (playerXPos - 0xffffffff) - 1 end
	if(playerYPos > 0x8000000) then playerYPos = (playerYPos - 0xffffffff) - 1 end
	if(playerZPos > 0x8000000) then playerZPos = (playerZPos - 0xffffffff) - 1 end

	gui.text(0,10,"xPos " .. DEC_HEX(locPosXValue)..": " .. playerXPos )
	gui.text(0,18,"yPos " .. DEC_HEX(locPosYValue)..": " .. playerYPos )
	gui.text(0,26,"zPos " .. DEC_HEX(locPosZValue)..": " .. playerZPos )
	gui.text(0,34,"FOV  " .. DEC_HEX(locFOVData)..": " .. fov )

	local xAxis = memory.readword(locXAxisValue)
	local yAxis = memory.readword(locYAxisValue)
	-- calculate this angle in radians for future use
	xAngle = ((2*math.pi) * xAxis) / 65535.0
		
	rotatedVel = RotateVector(math.pow(lStickX, viewCurve), math.pow(lStickY, viewCurve), xAngle)
	rotatedVel[1] = -rotatedVel[1] * walkSpeed;
	rotatedVel[2] = rotatedVel[2] * walkSpeed;

    -- Movement with Left Stick
    if (math.abs(lStickX) > moveDeadZone) or (math.abs(lStickY) > moveDeadZone) then
		memory.writedword(locPosXValue, playerXPos+rotatedVel[1]);
		memory.writedword(locPosYValue, playerYPos+rotatedVel[2]);
    end
	
	if btns.a then
		memory.writedword(locPosZValue, playerZPos+moveSpeed*0.4);
	end
	
	if btns.b then
		memory.writedword(locPosZValue, playerZPos-moveSpeed*0.4);
	end
	
	if math.abs(fov) > 65535/2 then 
		fov = -fov 
	end
	
	if btns.x then
		fov = fov + 100
	end
	
	if btns.y then
		fov = fov - 100
	end
	
	memory.writeword(locFOVData, fov)

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
		playerDataPtr2 = memory.readdword(playerDataPtr + locPlayerDataPtr2offset)
		locXAxisValue = playerDataPtr + playerDataLookOffset
		locYAxisValue = locXAxisValue + 0x00000002
		locPosXValue = playerDataPtr + playerDataPosOffset
		locPosZValue = locPosXValue + 4
		locPosYValue = locPosXValue + 8
		locXVel = playerDataPtr + playerDataVelOffset
		locYVel = locXVel + 8
		locMoveFlag = playerDataPtr + playerDataMoveFlagOffset
		locFOVData = playerDataPtr2 + fovDataOffset
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
    
	if ingame == 1 then ------------------------------------ BEGIN IN-GAME CONTROLS -------------------------
		-- Check what character we have selected
		toaSelected = memory.readbyte(locToaSelected)
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
		-- calculate this angle in radians for future use
		xAngle = ((2*math.pi) * xAxis) / 65535.0
		
		local lookMagnitude = math.sqrt(rStickX*rStickX + rStickY*rStickY)
		
		local actualLookSpeed = lookSpeed
		
		if lookMagnitude > rStickFullLockThreshold then
			rStickFullLockTime = rStickFullLockTime + 1
		else
			rStickFullLockTime = 0
		end
		
		if rStickFullLockTime > 0 then
			actualLookSpeed = actualLookSpeed * (1.0+math.min(rStickFullLockTime*rStickFullLockAcceleration, 1.5))
		end
		
		local fovScopeCheck = memory.readword(locFOVData)
		scopeZoomed = fovScopeCheck > 4000 and fovScopeCheck < 65535/2
		if scopeZoomed then
			actualLookSpeed = actualLookSpeed * 0.3
		end
		
		local xLookVel = math.pow(rStickX, viewCurve)*actualLookSpeed
		local yLookVel = math.pow(rStickY, viewCurve)*actualLookSpeed
		
		if (lookMagnitude > viewDeadZone) then
			xAxis = xAxis - xLookVel
			yAxis = yAxis - yLookVel
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
		if showDebugText == 1 then
			gui.text(0,2,"data: " .. DEC_HEX(playerDataPtr) )
			gui.text(0,10,"data2: " .. DEC_HEX(playerDataPtr2) )
			gui.text(0,18,"toa: " .. toaSelected .. " idx: " .. toaSelectIdx)
		elseif showDebugText == 2 then
			gui.text(0,2,"X: " .. DEC_HEX(locXAxisValue) .. ": " .. xAxis)
			gui.text(0,10,"Y: " .. DEC_HEX(locYAxisValue) .. ": " .. yAxis)
			gui.text(0,18,"scope: " .. tostring(scopeZoomed) .. " (" .. fov .. ")" )
		elseif showDebugText == 3 then
			gui.text(0,10,"lookspeed: " .. actualLookSpeed )
			gui.text(0,18,"vel - " .. DEC_HEX(locXVel) .. " : [" .. memory.readdword(locXVel) .. "," .. memory.readdword(locYVel) .. "]" )
		end
		
		
		sprintFOV = false
		playerMoving = false
		-- Movement with Left Stick
		if not enableNoClip then
		
			local moveMagnitude = math.sqrt(lStickX*lStickX + lStickY*lStickY)
			
			if moveMagnitude > moveDeadZone then
				playerMoving = true
				local speedMult = 1.2
				
				-- sprint with rightShoulder
				if btns.rightShoulder and lStickY > 0 then
					speedMult = 1.8
					
					local tempFOV = memory.readword(locFOVData)
					if not scopeZoomed then 
						sprintFOV = true 
					end
				end
				
				rotatedVel = RotateVector(math.pow(lStickX, viewCurve), math.pow(lStickY, viewCurve), xAngle)
				rotatedVel[1] = -rotatedVel[1] * walkSpeed * speedMult;
				rotatedVel[2] = rotatedVel[2] * walkSpeed * speedMult;
				--gui.text(0,2,"Stick tilt: [" .. lStickX .. "," .. lStickY )
				--gui.text(0,10,"forward angle: ".. xAngle )
				--gui.text(0,18,"Walk velocity: [" .. rotatedVel[1] .. "," .. rotatedVel[2] )
				
				if sprintFOV and fov > -1000 then
					fov = fov - 100
				end
			end	
		end
		
	else --------------------------------------- END IN-GAME CONTROLS ------------------------------------------------------------------------
	-- just translate left stick to dpad input
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

    -- Action with LT
	if (lTrig > 0.2) then
		joypadInput.R = true
		if toaSelected == 4 and not scopeZoomed then
			fov = 0
			memory.writeword(locFOVData, 0)
		end
	end
		
	-- hacky bits
	if enableHackWithAKey then doHackInput() end
	if enableNoClip and ingame == 1 then noclip_rightStick(joypadInput) end
	keys = input.get()
	if clicktimeout == 0 then
		if keys.V then 
			enableNoClip = not enableNoClip
			fov = memory.readword(locFOVData)
			if enableNoClip == false and fov > 65535/2 then
				memory.writeword(locFOVData, 1)
			end
			clicktimeout = 10
		end
		if keys.D then 
			showDebugText = showDebugText + 1; if showDebugText > 3 then showDebugText = 0 end
			clicktimeout = 10
		end
	end
	
	-- manually move fov back to 0 from negative otherwise the game loops it around the wrong way
	if (fov >= 35565 or fov < 1) and not sprintFOV then
		fov = fov + 100
	end
	if fov >= -100 and fov < 0 and ingame == 1 and not sprintFOV and not scopeZoomed then
		memory.writeword(locFOVData, 1)
		fov = 0
	end
    
	if clicktimeout > 0 then clicktimeout = clicktimeout - 1 end

    -- Submit the input to the emulator
    joypad.set(joypadInput)

	if ingame == 1 then
		
		-- Draw an indicator for where the simulated stylus is
		if stylusInput.touch then 
			stylus.set(stylusInput)
			gui.box(stylusInput.x-3, stylusInput.y-3, stylusInput.x+3, stylusInput.y+3, 0xffcc00ff) 
		end
	
		if fov < 0 then
			memory.writeword(locFOVData, fov)
		end
		
		if playerMoving and not enableNoClip then
			memory.writebyte(locMoveFlag, 1)
			memory.writedword(locXVel, rotatedVel[1])
			memory.writedword(locYVel, rotatedVel[2])
		end
	end
	
	emu.frameadvance()
end
