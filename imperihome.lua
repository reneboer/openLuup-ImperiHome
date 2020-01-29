#!/usr/bin/env wsapi.cgi

module(..., package.seeall)

local _log

--[[
Version 1.6 29 January 2020
Author Rene Boer

Standard Vera Device types in ISS we can handle right now

Cat/Sub cat	Device type string		Description
		DevCamera 			MJPEG IP Camera 
		DevCO2 				CO2 sensor 
4/5		DevCO2Alert 		CO2 Alert sensor 
2		DevDimmer 			Dimmable light 
4/0,1	DevDoor				Door / window security sensor 
21		DevElectricity		Electricity consumption sensor 
4/2		DevFlood 			Flood security sensor 
12		DevGenericSensor	Generic sensor (any value) 
16		DevHygrometry		Hygro sensor 
		DevLock 			Door lock 
18		DevLuminosity		Luminance sensor 
4/3		DevMotion 			Motion security sensor 
		DevMultiSwitch		Multiple choice actuator 
		DevNoise 			Noise sensor 
		DevPlayer 			Audio/Video player 
		DevPlaylist			Audio/Video playlist 
		DevPressure			Pressure sensor 
		DevRain 			Rain sensor 
		DevRGBLight			RGB(W) Light (dimmable) 
Yes		DevScene 			Scene (launchable) 
8/0,1	DevShutter 			Shutter actuator 
4/4		DevSmoke 			Smoke security sensor 
3		DevSwitch 			Standard on/off switch 
17		DevTemperature		Temperature sensor 
		DevTempHygro		Temperature and Hygrometer combined sensor 
5/1		DevThermostat		HVAC
5/2		DevThermostat		Heater 
28		DevUV				UV sensor 
		DevWind				Wind sensor 

These standards can be overruled based on the device schema. Currently supported:
- Smart Meter Gas readings
- Harmony Hub
- VW CarNet
- TeslaCar
- My House Control

Scenes are supported.

]]
local luup = require "openLuup.luup"  -- Gives all Vera luup functionality
local json = require "openLuup.json"

local includeVeraBridge = false	-- When set to false the devices and scenes created via a VeraBridge will not be included.

-- SIDs for devices we support
local SIDS = {
    HA = "urn:micasaverde-com:serviceId:HomeAutomationGateway1",
    HAD = "urn:micasaverde-com:serviceId:HaDevice1",
    Switch = "urn:upnp-org:serviceId:SwitchPower1",
    Dimmer = "urn:upnp-org:serviceId:Dimming1",
	Color = "urn:micasaverde-com:serviceId:Color1",
    Sensor = "urn:micasaverde-com:serviceId:SecuritySensor1",
    Energy = "urn:micasaverde-com:serviceId:EnergyMetering1",
    Light = "urn:micasaverde-com:serviceId:LightSensor1",
    Temp = "urn:upnp-org:serviceId:TemperatureSensor1",
    Humidity = "urn:micasaverde-com:serviceId:HumiditySensor1",
    Cover = "urn:upnp-org:serviceId:WindowCovering1",
	Generic = "urn:micasaverde-com:serviceId:GenericSensor1",
	DoorLock = "urn:micasaverde-com:serviceId:DoorLock1",
	WindowCovering = "urn:upnp-org:serviceId:WindowCovering1",
	HVAC_UOM1 = "urn:upnp-org:serviceId:HVAC_UserOperatingMode1",
	HVAC_FM = "urn:upnp-org:serviceId:HVAC_FanOperatingMode1",
	HVAC_TEMP = "urn:upnp-org:serviceId:TemperatureSetpoint1",
	HVAC_TEMP_H = "urn:upnp-org:serviceId:TemperatureSetpoint1_Heat",
	HVAC_TEMP_C = "urn:upnp-org:serviceId:TemperatureSetpoint1_Cool",
	Harmony = "urn:rboer-com:serviceId:Harmony1",
	HarmonyDev = "urn:rboer-com:serviceId:HarmonyDevice1",
	SM_Gas = "urn:rboer-com:serviceId:SmartMeterGAS1",
	CarNet = "urn:rboer-com:serviceId:CarNet1",
	TeslaCar = "urn:rboer-com:serviceId:TeslaCar1",
	House = "urn:rboer-com:serviceId:HouseDevice1",
	ALTUI = "urn:upnp-org:serviceId:altui1",
	MSwitch = "urn:dcineco-com:serviceId:MSwitch1"
}
local SCHEMAS = {
	BinaryLight = "urn:schemas-upnp-org:device:BinaryLight:1",
	GenericSensor = "urn:schemas-micasaverde-com:device:GenericSensor:1",
	DoorSensor = "urn:schemas-micasaverde-com:device:DoorSensor:1",
	SmokeSensor = "urn:schemas-micasaverde-com:device:SmokeSensor:1",
	FloodSensor = "urn:schemas-micasaverde-com:device:FloodSensor:1",
	MotionSensor = "urn:schemas-micasaverde-com:device:MotionSensor:1",
	TempLeakSensor = "urn:schemas-micasaverde-com:device:TempLeakSensor:1",
	HumiditySensor = "urn:schemas-micasaverde-com:device:HumiditySensor:1",
	LightSensor = "urn:schemas-micasaverde-com:device:LightSensor:1",
	TemperatureSensor = "urn:schemas-micasaverde-com:device:TemperatureSensor:1",
	PowerMeter = "urn:schemas-micasaverde-com:device:PowerMeter:1",
	DoorLock = "urn:schemas-micasaverde-com:device:DoorLock:1",
	DimmableLight = "urn:schemas-upnp-org:device:DimmableLight:1",
	DimmableRGBLight = "urn:schemas-upnp-org:device:DimmableRGBLight:1",
	Heater = "urn:schemas-upnp-org:device:Heater:1",
	WindowCovering = "urn:schemas-micasaverde-com:device:WindowCovering:1",
	Harmony = "urn:schemas-rboer-com:device:Harmony(%d*):1",
	HarmonyDev = "urn:schemas-rboer-com:device:HarmonyDevice(%d*)_(%d*):1",
	SM_Gas = "urn:schemas-rboer-com:device:SmartMeterGAS:1",
	CarNet = "urn:schemas-rboer-com:device:CarNet:1",
	TeslaCar = "urn:schemas-rboer-com:device:TeslaCar:1",
	House = "urn:schemas-rboer-com:device:HouseDevice:1",
	MSwitch = "xxxurn:schemas-dcineco-com:device:MSwitch(%d*):1"
}

-- Return an ISS parameter object
local function buildDeviceParameter(k,v,attr)
	local p = {}
	p.key = (k or 'Value')
	p.value = (v or 'N/A')
	if attr then 
		for ak, av in pairs(attr) do
			if ak and av then p[ak] = av end
		end
	end
	return p
end
-- Return an ISS parameters object
local function buildDeviceParamtersObject(id, params)
	local p_t = {}
	for key, prm_t in pairs(params) do
		local val
		local attr
		if prm_t then
			if type(prm_t) == "string" then
				val = prm_t
			elseif type(prm_t) == "function" then 
				val, attr = prm_t(id)
			else	
				val = luup.variable_get(prm_t[1], prm_t[2], id)
				if #prm_t == 3 then attr = prm_t[3] end
			end	
			if val and val ~= "" then
				p_t[#p_t+1] = buildDeviceParameter(key, val, attr)
			end    
		end    
	end    
	return p_t
end
-- Return the minimum ISS device header
local function buildDeviceDescription(id,nm,rm,tp,par)
	local d = {}
	d.id = (id.."" or "Missing")
	d.name = (nm or 'No name')
	d.room = (tostring(rm) or 'No room')
	d.type = (tp or 'DevGenericSensor')
	if par then d.params = buildDeviceParamtersObject(id, par) end
	return d
end

-- Convert RGB color string to 8 byte hex
local function ColorToHex(color)
	local hex = "00000000"
	for part in string.gmatch(color, "([^,]+)") do
		pos = part:sub(1,1)
		if pos == "2" then
			hex = hex:sub(1,2) .. string.format("%02X",part:sub(3)) .. hex:sub(5)
		elseif pos == "3" then
			hex = hex:sub(1,4) .. string.format("%02X",part:sub(3)) .. hex:sub(7)
		elseif pos == "4" then
			hex = hex:sub(1,6) .. string.format("%02X",part:sub(3))
		end    
	end
	return hex
end

-- Sub-device build functions. They must return a table of sub devices build of the main device
-- Action is optional parameter used to pull any actions when called.
local function subdev_CarNet(id,dev, action)
	local devices = {}
	-- No actions for Car Device, all are sensors
	if (action) then
		return nil
	end
	local rm = dev.room_num
	local desc = dev.description
	-- Add a Generic sensor for the battery percentage
	local val = luup.variable_get(SIDS.HAD, "BatteryLevel", id) or 10
	devices[#devices+1] = buildDeviceDescription(id, desc.."-BatPerc", rm, "DevGenericSensor", { Value = { SIDS.HAD, "BatteryLevel", { unit = "%" }}})
	devices[#devices].id = id.."_1"

	-- Add a Generic sensor for the range
	devices[#devices+1] = buildDeviceDescription(id, desc.."-Range", rm, "DevGenericSensor", { Value = { SIDS.CarNet, "ElectricRange", { unit = "km" }}})
	devices[#devices].id = id.."_2"
	-- Add a Generic sensor for the location
	if luup.variable_get(SIDS.CarNet, "LocationHome", id) == "1" then 
		val = "At home" 
	else
		local lat = luup.variable_get(SIDS.CarNet, "Latitude", id)
		local lng = luup.variable_get(SIDS.CarNet, "Longitude", id)
		lat = tonumber(lat) or 0
		lng = tonumber(lng) or 0 
		lat = math.floor(lat * 10000) / 10000
		lng = math.floor(lng * 10000) / 10000
		val = lat.." "..lng
	end	
	devices[#devices+1] = buildDeviceDescription(id, desc.."-Location", rm, "DevGenericSensor", { Value = val })
	devices[#devices].id = id.."_3"
	-- Add a Generic sensor for the doors and windows
	val = "Closed & Locked"
	local drs = luup.variable_get(SIDS.CarNet, "DoorsStatus", id)
	local lcks = luup.variable_get(SIDS.CarNet, "LocksStatus", id)
	local wnds = luup.variable_get(SIDS.CarNet, "WindowsStatus", id)
	local srf = luup.variable_get(SIDS.CarNet, "SunroofStatus", id)
	if drs ~= "Closed" then	
		val = "Doors open"
	elseif lcks ~= "Locked" then
		val = "Doors unlocked"
	elseif srf ~= "Closed" then
		val = "Sunroof open"
	elseif wnds ~= "Closed" then
		val = "Windows open"
	end
	devices[#devices+1] = buildDeviceDescription(id, desc.."-Doors", rm, "DevGenericSensor", { Value = val })
	devices[#devices].id = id.."_4"
	-- Add a Generic sensor for the last update
	local ts = luup.variable_get(SIDS.CarNet, "LastCarMessageTimestamp", id)
	devices[#devices+1] = buildDeviceDescription(id, desc.."-Refresh", rm, "DevGenericSensor", { Value = os.date("%H:%M %d/%m/%y" ,ts) })
	devices[#devices].id = id.."_5"
	-- Add a Generic sensor for remaining charge or climate time
	val = "N/A"
	if luup.variable_get(SIDS.CarNet, "ChargeStatus", id) == "1" then
		val = luup.variable_get(SIDS.CarNet, "RemainingChargeTime", id)
	elseif luup.variable_get(SIDS.CarNet, "ClimateStatus", id) == "1" then
		val = luup.variable_get(SIDS.CarNet, "ClimateRemainingTime", id)
	end	
	devices[#devices+1] = buildDeviceDescription(id, desc.."-TimeRemaining", rm, "DevGenericSensor", { Value = val })
	devices[#devices].id = id.."_6"
	return devices
end

local function subdev_TeslaCar(id,dev, action)
	local devices = {}
	-- No actions for Car Device, all are sensors
	if (action) then
		return nil
	end
	local rm = dev.room_num
	local desc = dev.description
	-- Add a Generic sensor for the battery percentage
	local val = luup.variable_get(SIDS.HAD, "BatteryLevel", id) or 10
	devices[#devices+1] = buildDeviceDescription(id, desc.."-BatPerc", rm, "DevGenericSensor", { Value = { SIDS.HAD, "BatteryLevel", { unit = "%" }}})
	devices[#devices].id = id.."_1"

	-- Add a Generic sensor for the range
	devices[#devices+1] = buildDeviceDescription(id, desc.."-Range", rm, "DevGenericSensor", { Value = { SIDS.TeslaCar, "BatteryRange", { unit = "km" }}})
	devices[#devices].id = id.."_2"
	-- Add a Generic sensor for the location
	if luup.variable_get(SIDS.TeslaCar, "LocationHome", id) == "1" then 
		val = "At home" 
	else
		local lat = luup.variable_get(SIDS.TeslaCar, "Latitude", id)
		local lng = luup.variable_get(SIDS.TeslaCar, "Longitude", id)
		lat = tonumber(lat) or 0
		lng = tonumber(lng) or 0 
		lat = math.floor(lat * 10000) / 10000
		lng = math.floor(lng * 10000) / 10000
		val = lat.." "..lng
	end	
	devices[#devices+1] = buildDeviceDescription(id, desc.."-Location", rm, "DevGenericSensor", { Value = val })
	devices[#devices].id = id.."_3"
	-- Add a Generic sensor for the doors and windows
	val = "Closed & Locked"
	local drs = luup.variable_get(SIDS.TeslaCar, "DoorsMessage", id)
	local lcks = luup.variable_get(SIDS.TeslaCar, "LockedStatus", id)
	local wnds = luup.variable_get(SIDS.TeslaCar, "WindowsMessage", id)
	local srf = luup.variable_get(SIDS.TeslaCar, "SunroofStatus", id)
	if drs ~= "Closed" then	
		val = "Doors open"
	elseif lcks ~= "1" then
		val = "Doors unlocked"
	elseif srf ~= "0" then
		val = "Sunroof open"
	elseif wnds ~= "Closed" then
		val = "Windows open"
	end
	devices[#devices+1] = buildDeviceDescription(id, desc.."-Doors", rm, "DevGenericSensor", { Value = val })
	devices[#devices].id = id.."_4"
	-- Add a Generic sensor for the last update
	local ts = luup.variable_get(SIDS.TeslaCar, "LastCarMessageTimestamp", id)
	devices[#devices+1] = buildDeviceDescription(id, desc.."-Refresh", rm, "DevGenericSensor", { Value = os.date("%H:%M %d/%m/%y" ,ts) })
	devices[#devices].id = id.."_5"
	-- Add a Generic sensor for remaining charge or climate time
	val = "N/A"
	if luup.variable_get(SIDS.TeslaCar, "ChargeStatus", id) == "1" then
		val = luup.variable_get(SIDS.TeslaCar, "RemainingChargeTime", id)
	elseif luup.variable_get(SIDS.TeslaCar, "ClimateStatus", id) == "1" then
		val = luup.variable_get(SIDS.TeslaCar, "ClimateMessage", id)
	end	
	devices[#devices+1] = buildDeviceDescription(id, desc.."-TimeRemaining", rm, "DevGenericSensor", { Value = val })
	devices[#devices].id = id.."_6"
	return devices
end

local function subdev_HouseDevice(id, dev, action)
	-- Make sure actions and devices will have the same child ID
	if action then
		local a_t = {}
		local pid,cid = id:match("(%d-)_(%d+)")
		if pid and cid and action == "setStatus" then
			local action = ""
			if cid == "1" then 
				action = "SetTempOverrideControl"
			elseif cid == "2" then 
				action = "SetCarChargeControl"
			elseif cid == "3" then 
				action = "SetZonneschermControl"
			elseif cid == "4" then 
				action = "SetOfficeThermostatsControl"
			else
				return nil
			end	
			a_t[1] = SIDS.House
			a_t[2] = action
			a_t[3] = "newTargetValue"
		end
		return a_t				
	else
		local devices = {}
		local rm = dev.room_num
		local desc = dev.description
	
		devices[#devices+1] = buildDeviceDescription(id, desc.."-OTG", rm, "DevSwitch", { Status = { SIDS.House, "TempOverrideControl" }})
		devices[#devices].id = id.."_1"
		devices[#devices+1] = buildDeviceDescription(id, desc.."-Car", rm, "DevSwitch", { Status = { SIDS.House, "CarChargeControl" }})
		devices[#devices].id = id.."_2"
		devices[#devices+1] = buildDeviceDescription(id, desc.."-Sunscreen", rm, "DevSwitch", { Status = { SIDS.House, "ZonneschermControl" }})
		devices[#devices].id = id.."_3"
		devices[#devices+1] = buildDeviceDescription(id, desc.."-OfficeWarm", rm, "DevSwitch", { Status = { SIDS.House, "OfficeThermostatsControl" }})
		devices[#devices].id = id.."_4"
		return devices
	end	
end

--[[Some special devices we do at schema level
	Schema definition four parts:
		the Vera device Schema (aka json device_type)
		use_match if the schema is to be found using a pattern rather than exact match.
		the ISS device type
		an array of the ISS device parameters for the /devices query
		an array of the ISS device actions.
	The parameters and actions arrays can have a fixed string value, a Vera SID and parameter to use for luup.get_value, or a function definition to get the value.
]]
local schemaMap = {}
-- Add a definition to the devMap table
local function devSchema_Insert(idx, mtch, typ, par, act, sub_dev)
	schemaMap[idx] = {}
	schemaMap[idx].use_match = mtch
	schemaMap[idx].type = typ
	if par then schemaMap[idx].params = par end
	if act then schemaMap[idx].actions = act end
	if sub_dev then schemaMap[idx].subdevices = sub_dev end
end

-- Some shared paramters and action definitions.
local sensParams = { Armed = { SIDS.Sensor, "Armed" }, Tripped = { SIDS.Sensor, "Tripped"},	lasttrip = { SIDS.Sensor, "LastTrip"}, armable = "1" }
local sensActions = { ["setArmed"] = { SIDS.Sensor, "SetArmed", "newArmedValue" } }			

-- Add standard schema's
devSchema_Insert(SCHEMAS.DoorLock, false, "DevLock", 
								{ Status = { SIDS.DoorLock, "Status" }
								}, 
								{ ["setStatus"] = { SIDS.DoorLock, "SetTarget", "newTargetValue" } 
								})
devSchema_Insert(SCHEMAS.DimmableRGBLight, false, "DevRGBLight", 
								{ Status = { SIDS.Switch, "Status" }, 
								  Level = { SIDS.Dimmer, "LoadLevelStatus" }, 
								  Energy = { SIDS.Energy, "Watts"},
								  color = function(id)
										local col = luup.variable_get(SIDS.Color, "CurrentColor", id)
										return ColorToHex(col)
									end, 
								  dimmable = "1"
								  }, 
								{ ["setLevel"] = { SIDS.Dimmer, "SetLoadLevelTarget", "newLoadlevelTarget" },
								  ["setStatus"] = { SIDS.Switch, "SetTarget", "newTarget" },
								  ["setColor"] = function(id,param)
										local a_t = {}
										local param = param or ""
										-- color comes in a HEX AARRGGBB, convert to Vera standard RRR,GGG,BBB
										if string.len(param) == 8 then
											local newtg = string.format("%d,%d,%d",tonumber(param:sub(3,4),16),tonumber(param:sub(5,6),16),tonumber(param:sub(7),16))
											a_t[1] = SIDS.Color
											a_t[2] = "SetColorRGB"
											a_t[3] = "newColorRGBTarget"
											a_t[4] = newtg
										end
										return a_t
									end
								})

-- Add scheme level control for the SmartMeter plugin Gas flow meter readings
devSchema_Insert(SCHEMAS.SM_Gas, false, "DevGenericSensor", 
		{ Value = { SIDS.SM_Gas, "Flow", { unit = "l/h" } }, defaultIcon = "https://raw.githubusercontent.com/reneboer/openLuup-ImperiHome/master/gas.png"}
		)
-- Add Schema level control for my House Control Plugin
devSchema_Insert(SCHEMAS.House, false, "DevMultiSwitch", 
				{ Value = function(id)
						local house_mode = tonumber((luup.attr_get("Mode",0)),10)
						if house_mode == 1 then
							return "Home"
						elseif house_mode == 2 then	
							return "Away"
						elseif house_mode == 3 then	
							return "Night"
						elseif house_mode == 4 then	
							return "Vacation"
						end
						return house_mode
					end,
					Choices = function(id)
						return "Home,Away,Night,Vacation"
					end,
					defaultIcon = "https://raw.githubusercontent.com/reneboer/openLuup-ImperiHome/master/House1.png" 
				},
				{ ["setChoice"] = function(id, param)
						local a_t = {}
						local param = param or ""
						if param == "Home" then
							param = "1"
						elseif param == "Away" then
							param = "2"
						elseif param == "Night" then
							param = "3"
						elseif param == "Vacation" then
							param = "4"
						end
						if param ~= "" then
							a_t[1] = SIDS.HA
							a_t[2] = "SetHouseMode"
							a_t[3] = "Mode"
							a_t[4] = param
						end
						return a_t
					end
				},
				function(id, dev, action)
					return subdev_HouseDevice(id, dev, action)
				end
			)
-- Add Schema level control for the CarNet Plugin
devSchema_Insert(SCHEMAS.CarNet, false, "DevMultiSwitch", 
				{ Value = function(id)
						local stat = luup.variable_get(SIDS.ALTUI, "DisplayLine2", id)
						if stat == "" then
							if luup.variable_get(SIDS.CarNet, "PowerSupplyConnected", id) == "1" then
								stat = "Ready for Activities"
							elseif luup.variable_get(SIDS.CarNet, "PowerPlugState", id) == "1" then
								if luup.variable_get(SIDS.CarNet, "PowerPlugLockState", id) == "1" then
									stat = "Cabled, but no power"
								else
									stat = "Cabled, but not locked!!!!"
								end
							end
							if stat == "" then
								stat = luup.variable_get(SIDS.CarNet, "CarName", id)
							end	
						end
						return stat
					end,
				Choices = function(id)
						return "Start Charging,Stop Charging,Start Climate,Stop Climate,Start WindowMelt,Stop WindowMelt,Refresh"
					end,
				defaultIcon = "https://raw.githubusercontent.com/reneboer/openLuup-CarNet/master/icons/CarNet.png" 
				},
				{ ["setChoice"] = function(id, param)
						local a_t = {}
						local actID = ""
						local param = param or ""
						if param ~= "" then
							if param == "Start Charging" then
								actID = "startCharge"
							elseif param == "Stop Charging" then
								actID = "stopCharge"
							elseif param == "Start Climate" then
								actID = "startClimate"
							elseif param == "Stop Climate" then
								actID = "stopClimate"
							elseif param == "Start WindowMelt" then
								actID = "startWindowMelt"
							elseif param == "Stop WindowMelt" then
								actID = "stopWindowMelt"
							elseif param == "Refresh" then
								actID = "Poll"
							end	
							if actID ~= "" then 
								a_t[1] = SIDS.CarNet
								a_t[2] = actID
							end
						end	
						return a_t
					end 
				},
				function(id, dev, action)
					return subdev_CarNet(id, dev, action)
				end
			)
-- Add Schema level control for the TeslaCar Plugin
devSchema_Insert(SCHEMAS.TeslaCar, false, "DevMultiSwitch", 
				{ Value = function(id)
						local stat = luup.variable_get(SIDS.ALTUI, "DisplayLine2", id)
						if stat == "" then
							if luup.variable_get(SIDS.TeslaCar, "PowerSupplyConnected", id) == "1" then
								if luup.variable_get(SIDS.TeslaCar, "PowerPlugState", id) == "1" then
									stat = "Ready for charing"
								else
									stat = "Cable but no power"
								end
							else
								-- stat = "Not connected"
							end
							if stat == "" then
								stat = luup.variable_get(SIDS.TeslaCar, "CarName", id)
							end	
						end
						return stat
					end,
				Choices = function(id)
						return "Open Charge Port,Start Charging,Stop Charging,Start Climate,Stop Climate,Refresh,Honk Horn,Flash Lights,Unlock Trunk,Unlock Frunk"
					end,
				defaultIcon = "https://raw.githubusercontent.com/reneboer/vera-TeslaCar/master/icons/TeslaCar.png" 
				},
				{ ["setChoice"] = function(id, param)
						local a_t = {}
						local actID = ""
						local param = param or ""
						if param ~= "" then
							if param == "Start Charging" then
								actID = "startCharge"
							elseif param == "Stop Charging" then
								actID = "stopCharge"
							elseif param == "Start Climate" then
								actID = "startClimate"
							elseif param == "Stop Climate" then
								actID = "stopClimate"
							elseif param == "Open Charge Port" then
								actID = "openChargePort"
							elseif param == "Honk Horn" then
								actID = "honkHorn"
							elseif param == "Flash Lights" then
								actID = "flashLights"
							elseif param == "Unlock Frunk" then
								actID = "unlockFrunk"
							elseif param == "Unlock Trunk" then
								actID = "unlockTrunk"
							elseif param == "Refresh" then
								actID = "Poll"
							end	
							if actID ~= "" then 
								a_t[1] = SIDS.TeslaCar
								a_t[2] = actID
							end
						end	
						return a_t
					end 
				},
				function(id, dev, action)
					return subdev_TeslaCar(id, dev, action)
				end
			)
-- Add Schema level control for the Harmony Hub Plugin
devSchema_Insert(SCHEMAS.Harmony, true, "DevMultiSwitch", 
				{ 	Value = function(id)
						local curActID = luup.variable_get(SIDS.Harmony, "CurrentActivityID", id)
						for bn = 1,25 do
							local actID = luup.variable_get(SIDS.Harmony, "ActivityID"..bn, id)
							if actID ~= "" and actID == curActID then 
								local actDesc = luup.variable_get(SIDS.Harmony, "ActivityDesc"..bn, id)
								return actDesc 
							end	
						end
						return ""
					end,
					Choices = function(id)
						local choices = ""
						for bn = 1,25 do
							local actDesc = luup.variable_get(SIDS.Harmony, "ActivityDesc"..bn, id)
							if actDesc and actDesc ~= "" then
								choices = choices ..actDesc .. ","
							end    
						end
						if choices ~= "" then choices = choices:sub(1, -2) end	
						return choices
					end,
				  defaultIcon = "https://raw.githubusercontent.com/reneboer/vera-Harmony-Hub/master/icons/Harmony.png" },
				{ ["setChoice"] = function(id, param)
					local a_t = {}
					local param = param or ""
					if param ~= "" then
						for bn = 1,25 do
							local actDesc = luup.variable_get(SIDS.Harmony, "ActivityDesc"..bn, id)
							if actDesc == param then 
								local actID = luup.variable_get(SIDS.Harmony, "ActivityID"..bn, id)
								a_t[1] = SIDS.Harmony
								a_t[2] = "StartActivity"
								a_t[3] = "newActivityID"
								a_t[4] = actID
								return a_t
							end	
						end
					end	
					return a_t
				end }
			)
devSchema_Insert(SCHEMAS.HarmonyDev, true, "DevMultiSwitch", 
				{ Choices = function(id)
						local choices = ""
						for bn = 1,25 do
							local actDesc = luup.variable_get(SIDS.HarmonyDev, "CommandDesc"..bn, id)
							if actDesc and actDesc ~= "" then choices = choices ..actDesc .. "," end    
						end
						if choices ~= "" then choices = choices:sub(1, -2) end	
						return choices
					end,
					defaultIcon = "https://raw.githubusercontent.com/reneboer/vera-Harmony-Hub/master/icons/Harmony.png" },
				{ ["setChoice"] = function(id, param)
					local a_t = {}
					local param = param or ""
					if param ~= "" then
						for bn = 1,25 do
							local actDesc = luup.variable_get(SIDS.HarmonyDev, "CommandDesc"..bn, id)
							if actDesc == param then 
								local actID = luup.variable_get(SIDS.HarmonyDev, "Command"..bn, id)
								a_t[1] = SIDS.HarmonyDev
								a_t[2] = "SendDeviceCommand"
								a_t[3] = "Command"
								a_t[4] = actID
								return a_t
							end	
						end
					end	
					return a_t
				end} 
	)
devSchema_Insert(SCHEMAS.MSwitch, true, "DevMultiSwitch", {}, {})

--[[Mapping between ImperiHome ISS and Vera device category and subcategory_num
	Map definition has four parts:
		the Vera device category and sub_category. Concatenated to c_s
		the ISS device type
		an array of the ISS device paramters for the /devices query
		an array of the ISS device actions.
	The paramerts and actions arrays can have a fixed string value, a Vera SID and paramter to use for luup.get_value, or a function definition to get the value.
]]
local devMap = {}
-- Add a definition to the devMap table
local function devMap_Insert(cat, sub_cat, typ, par, act)
    if type(cat) == "number" and type(sub_cat) == "number" then
        local idx = cat.."_"..sub_cat
        devMap[idx] = {}
        devMap[idx].type = typ
        if par then devMap[idx].params = par end
        if act then devMap[idx].actions = act end
    end
end 
-- Fill mapping table
devMap_Insert(2,0, "DevDimmer", { Status = { SIDS.Switch, "Status" }, Level = { SIDS.Dimmer, "LoadLevelStatus" }, Energy = { SIDS.Energy, "Watts"}},
								{ ["setLevel"] = { SIDS.Dimmer, "SetLoadLevelTarget", "newLoadlevelTarget" },
								  ["setStatus"] = { SIDS.Switch, "SetTarget", "newTarget" }
								})
devMap_Insert(3,0, "DevSwitch", { Status = { SIDS.Switch, "Status" }, Energy = { SIDS.Energy, "Watts"}},
								{ ["setStatus"] = { SIDS.Switch, "SetTarget", "newTarget" }} )
devMap_Insert(4,0, "DevDoor", sensParams,sensActions)
devMap_Insert(4,1, "DevDoor", sensParams,sensActions)
devMap_Insert(4,2, "DevFlood", sensParams,sensActions)-- Heeft ook een CurrentTemperature value, dus eigenlijk twee sensors in ISS.
devMap_Insert(4,3, "DevMotion", sensParams,sensActions)
devMap_Insert(4,4, "DevSmoke", sensParams,sensActions)
devMap_Insert(4,5, "DevCO2Alert", sensParams,sensActions)
devMap_Insert(5,1, "DevThermostat", { curtemp = { SIDS.Temp, "CurrentTemperature" },
									  cursetpoint = { SIDS.HVAC_TEMP, "CurrentSetpoint"},
									  availablemodes = function(id) 	
													local cmd = luup.variable_get(SIDS.HVAC_UOM1, "ModeStatus", id)
													if cmd ~= nil then 
														return "Off,Heat" 
													else 
														return nil 
													end
												end, 
									  curmode = function(id) 	
													local cmd = luup.variable_get( SIDS.HVAC_UOM1, "ModeStatus", id)
													if cmd == "Off" then 
														return cmd
													elseif cmd == "HeatOn" then 
														return "Heat"
													else 
														return nil
													end
												end,
									  availableenergymodes = function(id) 	
													local cmd = luup.variable_get( SIDS.HVAC_UOM1, "EnergyModeStatus", id)
													if cmd ~= nil then 
														return "Normal,Eco" 
													else 
														return nil 
													end
												end, 
									  curenergymode = function(id) 	
													local cmd = luup.variable_get( SIDS.HVAC_UOM1, "EnergyModeStatus", id)
													if cmd == "Normal" then 
														return cmd
													elseif cmd == "EnergySavingsMode" then 
														return "Eco"
													else 
														return nil
													end
												end,
									},
								{ ["setSetPoint"] = { SIDS.HVAC_TEMP, "SetCurrentSetpoint", "NewCurrentSetpoint" },
								  ["setMode"] = function(id,param)
													local a_t = {}
													a_t[1] = SIDS.HVAC_UOM1
													a_t[2] = "SetModeTarget"
													a_t[3] = "NewModeTarget"
													if param == "Heat" then 
														a_t[4] = "HeatOn"
													else 
														a_t[4] = "Off"
													end
													return a_t
												end,
								  ["setEnergyMode"] = function(id,param)
													local a_t = {}
													a_t[1] = SIDS.HVAC_UOM1
													a_t[2] = "SetEnergyModeTarget"
													a_t[3] = "NewModeTarget"
													if param == "Eco" then 
														a_t[4] = "EnergySavingsMode"
													else 
														a_t[4] = "Normal"
													end
													return a_t
												end,
								} )
devMap_Insert(5,2, "DevThermostat", { curtemp = { SIDS.Temp, "CurrentTemperature" },
									  cursetpoint = { SIDS.HVAC_TEMP_H, "CurrentSetpoint"},
									  cursetpoint1 = { SIDS.HVAC_TEMP_C, "CurrentSetpoint"},
									  availablemodes = "Off,Cool,Heat,Auto", 
									  curmode = function(id) 	
													local cmd = luup.variable_get( SIDS.HVAC_UOM1, "ModeStatus", id)
													if cmd == "Off" then 
														return cmd
													elseif cmd == "CoolOn" then 
														return "Cool"
													elseif cmd == "HeatOn" then 
														return "Heat"
													elseif cmd == "AutoChangeOver" then 
														return "Auto"
													else
														return nil
													end
												end,
									  availablefanmodes = function(id) 	
													local cmd = luup.variable_get( SIDS.HVAC_FM, "Mode", id)
													if cmd ~= nil then 
														return "On,Auto,Cycle" 
													else 
														return nil 
													end
												end,  
									  curfanmode = function(id) 	
													local cmd = luup.variable_get( SIDS.HVAC_FM, "Mode", id)
													if cmd == "ContinuousOn" then 
														return "On"
													elseif cmd == "Auto" then 
														return cmd
													elseif cmd == "PeriodicOn" then 
														return "Cycle"
													else 
														return nil
													end
												end,
									  availableenergymodes = function(id) 	
													local cmd = luup.variable_get( SIDS.HVAC_UOM1, "EnergyModeStatus", id)
													if cmd ~= nil then 
														return "Normal,Eco" 
													else 
														return nil 
													end
												end, 
									  curenergymode = function(id) 	
													local cmd = luup.variable_get( SIDS.HVAC_UOM1, "EnergyModeStatus", id)
													if cmd == "Normal" then 
														return cmd
													elseif cmd == "EnergySavingsMode" then 
														return "Eco"
													else 
														return nil
													end
												end,
									},
								{ ["setSetPoint"] = { SIDS.HVAC_TEMP, "SetCurrentSetpoint", "NewCurrentSetpoint" },
								  ["setMode"] = function(id,param)
													local a_t = {}
													a_t[1] = SIDS.HVAC_UOM1
													a_t[2] = "SetModeTarget"
													a_t[3] = "NewModeTarget"
													if param == "Heat" then 
														a_t[4] = "HeatOn"
													elseif param == "Cool" then 
														a_t[4] = "CoolOn"
													elseif param == "Heat" then 
														a_t[4] = "HeatOn"
													elseif param == "Auto" then a_t[4] = "AutoChangeOver"
													else 
														a_t[4] = "Off"
													end
													return a_t
												end,
								  ["setEnergyMode"] = function(id,param)
													local a_t = {}
													a_t[1] = SIDS.HVAC_UOM1
													a_t[2] = "SetEnergyModeTarget"
													a_t[3] = "NewModeTarget"
													if param == "Eco" then 
														a_t[4] = "EnergySavingsMode"
													else 
														a_t[4] = "Normal"
													end
													return a_t
												end,
								  ["setFanMode"] = function(id,param)
													local a_t = {}
													a_t[1] = SIDS.HVAC_FM
													a_t[2] = "SetMode"
													a_t[3] = "NewMode"
													if param == "On" then 
														a_t[4] = "ContinuousOn"
													elseif param == "Cycle" then 
														a_t[4] = "PeriodicOn"
													else 
														a_t[4] = "Auto"
													end
													return a_t
												end
								} )
devMap_Insert(8,0, "DevShutter", { Level = { SIDS.Dimmer, "LoadLevelStatus" }, stopable = "1", pulsable = "1"}, 
								{ ["setLevel"] = { SIDS.Dimmer, "SetLoadLevelTarget", "newLoadlevelTarget" }, 
								  ["stopShutter"] = { SIDS.WindowCovering, "Stop", "action" },
								  ["pulseShutter"] = function(id, param)
														local a_t = {}
														a_t[1] = SIDS.WindowCovering
														a_t[3] = "action"
														if param == "up" then
															a_t[2] = "Up"
														else
															a_t[2] = "Down"
														end
														a_t[4] = a_t[2]
														return a_t
													 end
								} )  
devMap_Insert(8,1, "DevShutter", { Level = { SIDS.Dimmer, "LoadLevelStatus" }, stopable = "1", pulsable = "1"}, 
								{ ["setLevel"] = { SIDS.Dimmer, "SetLoadLevelTarget", "newLoadlevelTarget" }, 
								  ["stopShutter"] = { SIDS.WindowCovering, "Stop", "action" },
								  ["pulseShutter"] = function(id, param)
														local a_t = {}
														a_t[1] = SIDS.WindowCovering
														a_t[3] = "action"
														if param == "up" then
															a_t[2] = "Up"
														else
															a_t[2] = "Down"
														end
														a_t[4] = a_t[2]
														return a_t
													 end
								} )  
devMap_Insert(12,0, "DevGenericSensor", { Value = { SIDS.Generic, "CurrentLevel" }})
devMap_Insert(16,0, "DevHygrometry", { Value = { SIDS.Humidity, "CurrentLevel" }})
devMap_Insert(17,0, "DevTemperature", {	Value = { SIDS.Temp, "CurrentTemperature" }})
devMap_Insert(18,0, "DevLuminosity", { Value = { SIDS.Light, "CurrentLevel" }})
devMap_Insert(21,0, "DevElectricity", {	ConsoTotal = { SIDS.Energy, "KWH" }, Watts = { SIDS.Energy, "Watts"}})
devMap_Insert(28,0, "DevUV", { Value = { SIDS.Light, "CurrentLevel" }})


-- Get information on the openLuup system
function ISS_GetSystem()
	local res = {}
	res.id = tostring(luup.pk_accesspoint)
	res.apiversion = 1
--	res.success = true
	return res
end

-- Get the rooms details
function ISS_GetRooms()
	local rid = 2
	local res = {}
	res.rooms = {}
	local rm = {}
	rm.id = "0"
	rm.name = "No Room"
	res.rooms[1] = rm
	for rn, name in pairs(luup.rooms) do
		-- Ignore the VeraBride created rooms
		if includeVeraBridge or string.sub(name,1, 5) ~= "MiOS-" then
			local rm = {}
			rm.id = tostring(rn)
			rm.name = name
			res.rooms[rid] = rm
			rid = rid + 1
		end	
	end
--	res.success = true
	return res
end
-- Search the schemaMap table for the matching schema. Allows for devices like Harmony Hub and MultiSwitch
-- If no match, look in the devMap for supported Category/sub-category
local function findDefinition(dev)
	local schema = dev.device_type
	-- First try simple map without pattern match
	local issType = schemaMap[schema]
	if issType then return true, issType end
	-- See if we need pattern match
    for sk, issType in pairs(schemaMap) do
		if issType.use_match then
			local m,_= sk:gsub("%-", "%%%-")
			local mtch = schema:match(m)
			if (mtch ~= nil) then return true, issType end
		end	
    end
	-- Next use default based on the device category and sub-category
	issType = devMap[dev.category_num..'_'..(dev.subcategory_num or 0)]
	if not issType then issType = devMap[dev.category_num..'_0'] end
	if (issType ~= nil) then return true, issType end
    return false, nil
end

function ISS_GetDevices()
	local devices = {}
	for id, dev in pairs(luup.devices) do
		-- Ignore hidden or invisible devices and those created by VeraBridge unless we want them included.
		local isDisabled = luup.attr_get("disabled", id)
		if not (dev.hidden or dev.invisible or isDisabled == 1 or (id >= 10000 and not includeVeraBridge)) then
			-- See if we know how to handle.
			local fnd, issType = findDefinition(dev)
			-- If found, build the ISS device definition
			if fnd then
				local res, d = pcall(buildDeviceDescription, id, dev.description, dev.room_num, issType.type, issType.params)
				if res then devices[#devices+1] = d	end	
				if issType.subdevices then
					local res, sd = pcall(issType.subdevices, id, dev)
					if res and sd then
						for k,d in pairs(sd) do
							devices[#devices+1] = d
						end
					end
				end
			end	
		end
	end
	-- Add scenes with a prefix to avoid clash with device numbers
	for id, scn in pairs(luup.scenes) do
		-- Ignore the scenes created by VeraBridge
	    if (tonumber(id) < 10000 or includeVeraBridge) then
			local res, d = pcall(buildDeviceDescription, "Scn"..id, scn.description, scn.room_num, "DevScene")
			if res then devices[#devices+1] = d	end	
		end	
	end
	local res = {}
	res.devices = devices
	return res
end

function ISS_SendCommand(devid, action, param)
	local res = {}
	res.success = false
	res.errormsg="not yet implemented"
	if not (devid or action) then
		res.errormsg="missing device and/or action"
		return res
	end	
	if action == "launchScene" then
		-- Action is for a scene
		local id = tonumber(devid:sub(4)) or 0
		luup.call_action(SIDS.HA,"RunScene",{ SceneNum = tostring(id) },0)
		res.success = true
		res.errormsg=""
	else
		-- Check on _ for sub device. Action will be on main device ID	
		local id, cid = devid:match("(%d-)_(%d+)")
		if id then 
			id = tonumber(id) or 0 
		else	
			id = tonumber(devid) or 0 
		end
		local dev = luup.devices[id]
		if dev then
			-- See if we know how to handle.
			local fnd, issType = findDefinition(dev)
			-- If found, build the ISS device definition
			if fnd then
				local act_t = nil
				-- See if we need to call for subdevice handler
				if cid and issType.subdevices then
					local res, sd = pcall(issType.subdevices, devid, dev, action)
					if res then act_t = sd end
				else
					act_t = issType.actions[action]
				end
				if act_t then
					if type(act_t) == "function" then
						act_t = act_t(id, param)
					else
						act_t[4] = tostring(param) or ""
					end	
					if (act_t[1]) then
						local prm = {}
						if act_t[3] and (act_t[4] ~= "") then prm[act_t[3]] = act_t[4] end
						if act_t[1] == SIDS.HA then
							-- Its an action for the HomeAutomationGateway device (0)
							luup.call_action(act_t[1],act_t[2],prm,0)
						else
							luup.call_action(act_t[1],act_t[2],prm,id)
						end	
						res.success = true
						res.errormsg=""
					else
						res.errormsg="Device action "..action.." paramter(s) not supported." 
					end
				else	
					res.errormsg="Device action "..action.." not supported." 
				end
			else	
				res.errormsg="Device type "..devid.." not supported." 
			end
		else	
			res.errormsg="DeviceID "..devid.." not found." 
		end
	end	
	return res
end

function ISS_SendGraph(devid, param, startdate, enddate)
	local res = {}
	res.errormsg="not yet implemented"
	return res
end


-- WSAPI return function
function run(wsapi_env)
	_log = function (...) wsapi_env.error:write(...) end      -- set up the log output, note colon syntax
  
	local headers = {["content-type"] = "text/plain"}
	local status, return_content, issRes, pcstat
	-- Find right function to ISS API. Format is query=/.... E.g query=/rooms
	local _, func_st = string.find(wsapi_env.QUERY_STRING, "query=", 1, true)
	if func_st then
		local func = string.sub(wsapi_env.QUERY_STRING, 8)
		if func == "system" then
			pcstat, issRes = pcall(ISS_GetSystem)
		elseif func == "rooms" then
			pcstat, issRes = pcall(ISS_GetRooms)
		elseif func == "devices" then
			pcstat, issRes = pcall(ISS_GetDevices)
		else
			local devid, act_par = func:match("devices/([^/]*)/action/(.*)")
			local action, param = nil, nil
			if act_par then
				action, param = act_par:match("(%w+)/(.*)")
			end
			if action == nil then action = act_par end
			if param then param = param:gsub("%%20"," ") end  -- Paramters can have spaces that come as %20 on request.
			if devid and action then
				pcstat, issRes = pcall(ISS_SendCommand, devid, action, param)
			else
				local devid, param, startdate, enddate = func:match("devices/(%d+)/(%w+)/histo/(%d+)/(%d+)")
				if devid and param then
					pcstat, issRes = pcall(ISS_SendGraph, devid, param, startdate, enddate)
				else	
					status, return_content = 404, "failed: unknown query "..(func or "???")
				end
			end      
		end
		if pcstat then
			if issRes then 
				local body = json.encode(issRes)
				headers["content-type"] = "application/json"
				headers["content-length"] = string.len(body)
				status, return_content = 200, body
			else
				status, return_content = 404, "failed: "..(issRes.errormsg or "unknown")
			end
		else		
			status, return_content = 404, "failed: "..(issRes or "unknown")
		end
	else	
		status, return_content = 404, "unknown paramter: "..(func or "--empty--")
	end
  
	local function iterator ()     -- one-shot iterator, returns content, then nil
		local x = return_content
		return_content = nil 
		return x
	end

	return status, headers, iterator
end

