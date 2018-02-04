#!/usr/bin/env wsapi.cgi

module(..., package.seeall)

--[[
Version 0.8 4 February 2018
Author Rene Boer

Standard Vera Device types in ISS we can handle right now

Cat/Sub cat	Device type string		Description
			DevCamera 				MJPEG IP Camera 
			DevCO2 					CO2 sensor 
4/5			DevCO2Alert 			CO2 Alert sensor 
2			DevDimmer 				Dimmable light 
4/0,1		DevDoor 				Door / window security sensor 
21			DevElectricity 			Electricity consumption sensor 
4/2			DevFlood 				Flood security sensor 
12			DevGenericSensor 		Generic sensor (any value) 
16			DevHygrometry 			Hygro sensor 
			DevLock 				Door lock 
18			DevLuminosity 			Luminance sensor 
4/3			DevMotion 				Motion security sensor 
			DevMultiSwitch 			Multiple choice actuator 
			DevNoise 				Noise sensor 
			DevPlayer 				Audio/Video player 
			DevPlaylist 			Audio/Video playlist 
			DevPressure 			Pressure sensor 
			DevRain 				Rain sensor 
			DevRGBLight 			RGB(W) Light (dimmable) 
Yes			DevScene 				Scene (launchable) 
8/0,1		DevShutter 				Shutter actuator 
4/4			DevSmoke 				Smoke security sensor 
3			DevSwitch 				Standard on/off switch 
17			DevTemperature 			Temperature sensor 
			DevTempHygro 			Temperature and Hygrometer combined sensor 
5/1			DevThermostat 			HVAC
5/2			DevThermostat 			Heater 
28			DevUV 					UV sensor 
			DevWind 				Wind sensor 

These standards can be overruled based on the device schema. Currently supported:
- Smart Meter Gas readings
- Harmony Hub

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
	MSwitch = "xxxurn:schemas-dcineco-com:device:MSwitch(%d*):1"
}
-- Return the minimum ISS device header
local function buildDeviceDescription(id,nm,rm,tp)
	local d = {}
	d.id = (id.."" or "Missing")
	d.name = nm
	d.room = tostring(rm)
	d.type = tp
	return d
end
-- Return an ISS parameter object
local function buildDeviceParameter(k,v)
	local p = {}
	p.key = k
	p.value = v
	return p
end
-- Return an ISS paramters object
local function buildDeviceParamtersObject(id,params)
	local p_t = {}
	local pid = 1
	for key, prm_t in pairs(params) do
		local val
		if prm_t then
			if type(prm_t) == "string" then
				val = prm_t
			elseif type(prm_t) == "function" then 
				val = prm_t(id)
			else	
				val = luup.variable_get(prm_t[1], prm_t[2], id)
			end	
			if val and val ~= "" then
				p_t[pid] = buildDeviceParameter(key, val)
				pid = pid + 1
			end    
		end    
	end    
	return p_t
end
--[[Some special devices we do at schema level
	Schema definition four parts:
		the Vera device Schema (aka json device_type)
		the ISS device type
		an array of the ISS device paramters for the /devices query
		an array of the ISS device actions.
	The paramerts and actions arrays can have a fixed string value, a Vera SID and paramter to use for luup.get_value, or a function definition to get the value.
]]
local schemaMap = {}
-- Add a definition to the devMap table
local function devSchema_Insert(idx, mtch, typ, par, act)
	schemaMap[idx] = {}
	schemaMap[idx].use_match = mtch
	schemaMap[idx].type = typ
	if par then schemaMap[idx].params = par end
	if act then schemaMap[idx].actions = act end
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
								  color = { SIDS.Color, "CurrentColor" }, 
								  dimmable = "1"
								  }, 
								{ ["setLevel"] = { SIDS.Dimmer, "SetLoadLevelTarget", "newLoadlevelTarget" },
								  ["setStatus"] = { SIDS.Switch, "SetTarget", "newTarget" },
								  ["setColor"] = { SIDS.Color, "SetColorRGB", "newColorRGBTarget" }
								})

-- Add scheme level control for the SmartMeter plugin Gas flow meter readings
devSchema_Insert(SCHEMAS.SM_Gas, false, "DevGenericSensor", 
		{ Value = { SIDS.SM_Gas, "Flow" }, defaultIcon = "https://raw.githubusercontent.com/reneboer/openLuup-ImperiHome/master/gas.png", unit = "l/h"}
		)
-- Add Schema level control for the CarNet Plugin
devSchema_Insert(SCHEMAS.CarNet, true, "DevMultiSwitch", 
				{ Value = function(id)
						return "Bat. Lev : "..luup.variable_get(SIDS.HAD, "BatteryLevel", id) .."%"
					end,
				Choices = function(id)
						local choices = "Start Charging,Stop Charging,Start Climate,Stop Climate"
						return choices
					end,
				defaultIcon = "https://raw.githubusercontent.com/reneboer/openLuup-CarNet/master/icons/CarNet.png" },
				{ ["setChoice"] = function(id, param)
					local a_t = {}
					local actID = ""
					local param = param or ""
					if param ~= "" then
						if param == "Start+Charging" then
							actID = "startCharge"
						elseif param == "Stop+Charging" then
							actID = "stopCharge"
						elseif param == "Start+Climate" then
							actID = "startClimate"
						elseif param == "Stop+Climate" then
							actID = "stopClimate"
						end	
						if actID ~= "" then 
							a_t[1] = SIDS.CarNet
							a_t[2] = actID
						end
					end	
					return a_t
				end }
			)
-- Add Schema level control for the Harmony Hub Plugin
devSchema_Insert(SCHEMAS.Harmony, true, "DevMultiSwitch", 
				{ 	Value = function(id)
						local curActID = luup.variable_get(SIDS.Harmony, "CurrentActivityID", id)
						for bn = 1,25 do
							local actID = luup.variable_get(SIDS.Harmony, "ActivityID"..bn, id)
							local actDesc = luup.variable_get(SIDS.Harmony, "ActivityDesc"..bn, id)
							if actID == curActID then return actDesc end
						end
						--return ""
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
	local did = 1
	local res = {}
	res.devices = {}
	for id, dev in pairs(luup.devices) do
		-- Ignore hidden or invisible devices and those created by VeraBridge unless we want them included.
		local isDisabled = luup.attr_get("disabled", id)
		if not (dev.hidden or dev.invisible or isDisabled == 1 or (id >= 10000 and not includeVeraBridge)) then
			-- See if we know how to handle.
			local fnd, issType = findDefinition(dev)
			-- If found, build the ISS device definition
			if fnd then
				local d = buildDeviceDescription(id, dev.description, dev.room_num, issType.type)
				if issType.params then d.params = buildDeviceParamtersObject(id, issType.params) end
				res.devices[did] = d
				did = did + 1
			end	
		end
	end
	-- Add scenes
	for id, scn in pairs(luup.scenes) do
		-- Ignore the scenes created by VeraBridge
	    if (tonumber(id) < 10000 or includeVeraBridge) then
			local d = buildDeviceDescription("Scn"..id, scn.description, scn.room_num, "DevScene")
			res.devices[did] = d
			did = did + 1
		end	
	end
--	res.success = true
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
	local id = tonumber(devid) or 0
	if action == "launchScene" then
		-- Action is for a schene
		luup.call_action(SIDS.HA,"RunScene",{ SceneNum = tostring(id) },0)
		res.success = true
		res.errormsg=""
	else
		local dev = luup.devices[id]
		if dev then
			-- See if we know how to handle.
			local fnd, issType = findDefinition(dev)
			-- If found, build the ISS device definition
			if fnd then
				local act_t = issType.actions[action]
				if act_t then
					if type(act_t) == "function" then
						act_t = act_t(id, param)
					else
						act_t[4] = tostring(param) or ""
					end	
					if (act_t[1]) then
						local prm = {}
						if act_t[3] and (act_t[4] ~= "") then prm[act_t[3]] = act_t[4] end
						luup.call_action(act_t[1],act_t[2],prm,id)
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
	res.success = false
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
			local devid, act_par = func:match("devices/(%d+)/action/(.*)")
			local action, param = nil, nil
			if act_par then
				action, param = act_par:match("(%w+)/(.*)")
			end	
			if action == nil then action = act_par end
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

