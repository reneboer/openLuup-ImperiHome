#!/usr/bin/env wsapi.cgi

module(..., package.seeall)

--[[
Standard Vera Device types in ISS we can handle right now

Cat/Sub cat	Device type string		Description
			DevCamera 				MJPEG IP Camera 
4/5			DevCO2 					CO2 sensor 
			DevCO2Alert 			CO2 Alert sensor 
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
			DevScene 				Scene (launchable) 
			DevShutter 				Shutter actuator 
4/4			DevSmoke 				Smoke security sensor 
3			DevSwitch 				Standard on/off switch 
17			DevTemperature 			Temperature sensor 
			DevTempHygro 			Temperature and Hygrometry combined sensor 
			DevThermostat 			Thermostat 
28			DevUV 					UV sensor 
			DevWind 				Wind sensor 

These standards can be overruled based on the device schema.

]]
local luup = require "openLuup.luup"  -- Gives all Vera luup functionality
local json = require "openLuup.json"


-- SIDs for devices we support
local SIDS = {
    HA = "urn:micasaverde-com:serviceId:HaDevice1",
    Switch = "urn:upnp-org:serviceId:SwitchPower1",
    Dimmer = "urn:upnp-org:serviceId:Dimming1",
    Sensor = "urn:micasaverde-com:serviceId:SecuritySensor1",
    Energy = "urn:micasaverde-com:serviceId:EnergyMetering1",
    Light = "urn:schemas-micasaverde-com:service:LightSensor:1",
    Temp = "urn:upnp-org:serviceId:TemperatureSensor1",
    Humidity = "urn:micasaverde-com:serviceId:HumiditySensor1",
    Cover = "urn:upnp-org:serviceId:WindowCovering1",
	Generic = "urn:micasaverde-com:serviceId:GenericSensor1",
	DoorLock = "urn:micasaverde-com:serviceId:DoorLock1",
	WindowCovering = "urn:upnp-org:serviceId:WindowCovering1",
	Harmony = "urn:rboer-com:serviceId:Harmony1",
	HarmonyDev = "urn:rboer-com:serviceId:HarmonyDevice1",
	SM_Gas = "urn:rboer-com:serviceId:SmartMeterGAS1",
	MSwitch = "urn:dcineco-com:serviceId:MSwitch1"
}
local SCHEMAS = {
	Harmony = "urn:schemas-rboer-com:device:Harmony(%d*):1",
	HarmonyDev = "urn:schemas-rboer-com:device:HarmonyDevice(%d*)_(%d*):1",
	SM_Gas = "urn:schemas-rboer-com:device:SmartMeterGAS:1",
	MSwitch = "xxxurn:schemas-dcineco-com:device:MSwitch(%d*):1"
}
-- Return the minimum ISS device header
local function buildDeviceDescription(id,nm,rm,tp)
	local d = {}
	d.id = tostring(id)
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
	-- See if we are passed a function to use
	if type(params) == "function" then return params(id) end
	-- No, then build from object
	local p_t = {}
	local pid = 1
	for key, prm_t in pairs(params) do
		local val
		if type(prm_t) == "string" then
			val = prm_t
		else
			val = luup.variable_get(prm_t[1], prm_t[2], id)
		end	
		if val and val ~= "" then
			p_t[pid] = buildDeviceParameter(key, val)
			pid = pid + 1
		end    
	end    
	return p_t
end
-- Some special devices we do at schema level
local schemaMap = {}
-- Add a definition to the devMap table
local function devSchema_Insert(idx, typ, par, act)
	schemaMap[idx] = {}
	schemaMap[idx].type = typ
	if par then schemaMap[idx].params = par end
	if act then schemaMap[idx].actions = act end
end    
-- Add scheme level control for the SmartMeter plugin Gas flow meter readings
devSchema_Insert(SCHEMAS.SM_Gas, "DevGenericSensor", 
				 { Value = { SIDS.SM_Gas, "Flow" }, defaultIcon = "https://raw.githubusercontent.com/reneboer/openLuup-ImperiHome/master/gas.png", unit = "l/h"})
-- Add Schema level control for the Harmony Hub Plugin
devSchema_Insert(SCHEMAS.Harmony, "DevMultiSwitch",  
				function(id)
					local p_t = {}
					local curActDesc = ""
					local choices = ""
					local curActID = luup.variable_get(SIDS.Harmony, "CurrentActivityID", id)
					for bn = 1,25 do
						local actDesc = luup.variable_get(SIDS.Harmony, "ActivityDesc"..bn, id)
						local actID = luup.variable_get(SIDS.Harmony, "ActivityID"..bn, id)
						if actDesc and actDesc ~= "" then
							choices = choices ..actDesc .. ","
							if actID == curActID then curActDesc = actDesc end
						end    
					end
					p_t[1] = buildDeviceParameter("defaultIcon", "https://raw.githubusercontent.com/reneboer/vera-Harmony-Hub/master/icons/Harmony.png")
					if curActDesc ~= "" then p_t[2] = buildDeviceParameter("Value", curActDesc) end	
					if choices ~= "" then p_t[3] = buildDeviceParameter("Choices", choices:sub(1, -2)) end	
					return p_t
				end,
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
							end	
						end
					end	
					return a_t
				end }
	)
devSchema_Insert(SCHEMAS.HarmonyDev, "DevMultiSwitch", 
				function(id)
					local p_t = {}
					local choices = ""
					for bn = 1,25 do
						local actDesc = luup.variable_get(SIDS.HarmonyDev, "CommandDesc"..bn, id)
						local actID = luup.variable_get(SIDS.HarmonyDev, "CommandID"..bn, id)
						if actDesc and actDesc ~= "" then choices = choices ..actDesc .. "," end    
					end
					p_t[1] = buildDeviceParameter("defaultIcon", "https://raw.githubusercontent.com/reneboer/vera-Harmony-Hub/master/icons/Harmony.png")
					if choices ~= "" then p_t[2] = buildDeviceParameter("Choices", choices:sub(1, -2)) end	
					return p_t
				end,
				{ ["setChoice"] = function(id, param)
					local a_t = {}
					local param = param or ""
					if param ~= "" then
						for bn = 1,25 do
							local actDesc = luup.variable_get(SIDS.HarmonyDev, "CommandDesc"..bn, id)
							if actDesc == param then 
								local actID = luup.variable_get(SIDS.HarmonyDev, "CommandID"..bn, id)
								a_t[1] = SIDS.HarmonyDev
								a_t[2] = "SendDeviceCommand"
								a_t[3] = "Command"
								a_t[4] = actID
							end	
						end
					end	
					return a_t
				end} 
	)
devSchema_Insert(SCHEMAS.MSwitch,"DevMultiSwitch", {}, {})

-- mapping between ImperiHome ISS and Vera device category and subcategory_num
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
-- Some common paramters definitions
local sensParams = { Armed = { SIDS.Sensor, "Armed" }, Tripped = { SIDS.Sensor, "Tripped"},	lasttrip = { SIDS.Sensor, "LastTrip"}, armable = "1" }
-- Some common paramters definitions
local sensActions = { ["setArmed"] = { SIDS.Sensor, "SetArmed", "newArmedValue" }	}			
-- Fill mapping table
devMap_Insert(2,0, "DevDimmer", { Status = { SIDS.Switch, "Status" }, Level = { SIDS.Dimmer, "LoadLevelStatus" }, Energy = { SIDS.Energy, "Watts"}},
								{ ["setLevel"] = { SIDS.Dimmer, "SetLoadLevelTarget", "newLoadlevelTarget" },
								  ["setStatus"] = { SIDS.Switch, "SetTarget", "newTarget" }
								})
devMap_Insert(3,0, "DevSwitch", { Status = { SIDS.Switch, "Status" }, Energy = { SIDS.Energy, "Watts"}},
								{ ["setStatus"] = { SIDS.Switch, "SetTarget", "newTarget" }} )
devMap_Insert(4,0, "DevDoor", sensParams,sensActions)
devMap_Insert(4,1, "DevDoor", sensParams,sensActions)
devMap_Insert(4,2, "DevFlood", sensParams,sensActions)
devMap_Insert(4,3, "DevMotion", sensParams,sensActions)
devMap_Insert(4,3, "DevSmoke", sensParams,sensActions)
devMap_Insert(4,3, "DevCO2Alert", sensParams,sensActions)
devMap_Insert(7,0, "DevLock", { Status = { SIDS.DoorLock, "Status" }}, { ["setStatus"] = { SIDS.DoorLock, "SetTarget", "newTargetValue" }} )
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
	res.success = true
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
		if string.sub(name,1, 5) ~= "MiOS-" then
			local rm = {}
			rm.id = tostring(rn)
			rm.name = name
			res.rooms[rid] = rm
			rid = rid + 1
		end	
	end
	res.success = true
	return res
end
-- Search the schemaMap table for the matching schema. Allows for devices like Harmony Hub and MultiSwitch
local function findSchema(schema)
    for sk, dev in pairs(schemaMap) do
        local m,_= sk:gsub("%-", "%%%-")
        local mtch = schema:match(m)
        if (mtch ~= nil) then return true, dev end
    end
    return false
end
function ISS_GetDevices()
	local did = 1
	local res = {}
	res.devices = {}
	for id, dev in pairs(luup.devices) do
		-- Ignore hidden or invisible devices and those created by VeraBridge.
		if not (dev.hidden or dev.invisible or id >= 10000) then
			-- For special types we want to map based on schema
			local fnd, issType = findSchema(dev.device_type)
			if not fnd then
				issType = devMap[dev.category_num..'_'..dev.subcategory_num]
				if not issType then issType = devMap[dev.category_num..'_0'] end
			end	
			if issType then
				local d = buildDeviceDescription(id, dev.description, dev.room_num, issType.type)
				d.params = buildDeviceParamtersObject(id, issType.params)
				res.devices[did] = d
				did = did + 1
			end	
		end
	end
	res.success = true
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
	local dev = luup.devices[id]
	if dev then
		local fnd, issType = findSchema(dev.device_type)
		if not fnd then
			issType = devMap[dev.category_num..'_'..dev.subcategory_num]
			if not issType then issType = devMap[dev.category_num..'_0'] end
		end	
		if issType then
			local act_t = issType.actions[action]
			if act_t then
				if type(act_t) == "function" then
					act_t = act_t(id, param, issType)
				else
					act_t[4] = tostring(param) or ""
				end	
				local prm = {}
				if act_t[3] and (act_t[4] ~= "") then prm[act_t[3]] = act_t[4] end
				luup.call_action(act_t[1],act_t[2],prm,id)
				res.success = true
				res.errormsg=""
			end
		end
	else	
		res.errormsg="DeviceID "..devid.." not found." 
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
  
	local headers = {["Content-Type"] = "text/plain"}
	local status, return_content, issRes, pcstat
	-- Find right function to ISS API
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
			local devid, action, param = func:match("devices/(%d+)/action/(%w+)/(.*)")
			if devid and action then
				pcstat, issRes = pcall(ISS_SendCommand, devid, action, param)
			else
				local devid, param, startdate, enddate = func:match("devices/(%d+)/(%w+)/histo/(%d+)/(%d+)")
				if devid and param then
					pcstat, issRes = pcall(ISS_SendGraph, devid, param, startdate, enddate)
				end
			end      
		end
		if pcstat then
			if issRes.success then 
				local body = json.encode(issRes)
				headers["Content-Type"] = "application/json"
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
