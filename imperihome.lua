#!/usr/bin/env wsapi.cgi

module(..., package.seeall)

--[[
Device types in ISS we can read

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

Curently some special handling for the Harmony Hub as MultySwitch device
]]
local userdata = require "openLuup.userdata"
local luup = require "openLuup.luup"  -- Gives all Vera luup functionality
local json = require "openLuup.json"


-- SIDs for devices we support
local sidMap = {
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
	Harmony = "urn:rboer-com:serviceId:Harmony1",
	HarmonyDev = "urn:rboer-com:serviceId:HarmonyDevice1",
	SM_Gas = "urn:rboer-com:serviceId:SmartMeterGAS1",
	MSwitch = "urn:dcineco-com:serviceId:MSwitch1"
}
-- Some special devices we do at schema level
local schemaMap = {
	SM_Gas = "urn:schemas-rboer-com:device:SmartMeterGAS:1",
	Harmony = "urn:schemas-rboer-com:device:Harmony",
	HarmonyDev = "urn:schemas-rboer-com:device:HarmonyDevice",
	MSwitch = "urn:schemas-dcineco-com:device:MSwitch"
}
-- The index number is the Vera Luup Device Category
local devMap = {
    ["2_0"] = { type = "DevDimmer", 
			params = { 
				Status = { sidMap.Switch, "Status" }, 
				Level = { sidMap.Dimmer, "LoadLevelStatus" }, 
				Energy = { sidMap.Energy, "Watts"}
			},
			actions = {
				["setLevel"] = { sidMap.Dimmer, "SetLoadLevelTarget", "newLoadlevelTarget" }
			}
		  },
	["3_0"] = { type = "DevSwitch", 
			params = { 
				Status = { sidMap.Switch, "Status" }, 
				Energy = { sidMap.Energy, "Watts"}
			},
			actions = {
				["setStatus"] = { sidMap.Switch, "SetTarget", "newTarget" }
			}
		   },
	["4_0"] = { type = "DevDoor", 
			params = { 
				Armed = { sidMap.Sensor, "Armed" }, 
				Tripped = { sidMap.Sensor, "Tripped"},
				lasttrip = { sidMap.Sensor, "LastTrip"},
				armable = "1"
			},
			actions = {
				["setArmed"] = { sidMap.Sensor, "SetArmed", "newArmedValue" }
			}
		   },
	["4_1"] = { type = "DevDoor", 
			params = { 
				Armed = { sidMap.Sensor, "Armed" }, 
				Tripped = { sidMap.Sensor, "Tripped"},
				lasttrip = { sidMap.Sensor, "LastTrip"},
				armable = "1"
			},
			actions = {
				["setArmed"] = { sidMap.Sensor, "SetArmed", "newArmedValue" }
			}
		   },
	["4_2"] = { type = "DevFlood", 
			params = { 
				Armed = { sidMap.Sensor, "Armed" }, 
				Tripped = { sidMap.Sensor, "Tripped"},
				lasttrip = { sidMap.Sensor, "LastTrip"},
				armable = "1"
			},
			actions = {
				["setArmed"] = { sidMap.Sensor, "SetArmed", "newArmedValue" }
			}
		   },
	["4_3"] = { type = "DevMotion", 
			params = { 
				Armed = { sidMap.Sensor, "Armed" }, 
				Tripped = { sidMap.Sensor, "Tripped"},
				lasttrip = { sidMap.Sensor, "LastTrip"},
				armable = "1"
			},
			actions = {
				["setArmed"] = { sidMap.Sensor, "SetArmed", "newArmedValue" }
			}
		   },
	["4_4"] = { type = "DevSmoke", 
			params = { 
				Armed = { sidMap.Sensor, "Armed" }, 
				Tripped = { sidMap.Sensor, "Tripped"},
				lasttrip = { sidMap.Sensor, "LastTrip"},
				armable = "1"
			},
			actions = {
				["setArmed"] = { sidMap.Sensor, "SetArmed", "newArmedValue" }
			}
		   },
	["4_5"] = { type = "DevCO2Alert", 
			params = { 
				Armed = { sidMap.Sensor, "Armed" }, 
				Tripped = { sidMap.Sensor, "Tripped"},
				lasttrip = { sidMap.Sensor, "LastTrip"},
				armable = "1"
			},
			actions = {
				["setArmed"] = { sidMap.Sensor, "SetArmed", "newArmedValue" }
			}
		   },
	["12_0"] = { type = "DevGenericSensor", 
			params = { 
				Value = { sidMap.Generic, "CurrentLevel" }
			}
		   },
	["16_0"] = { type = "DevHygrometry", 
			params = { 
				Value = { sidMap.Humidity, "CurrentLevel" }
			}
		   },
	["17_0"] = { type = "DevTemperature", 
			params = { 
				Value = { sidMap.Temp, "CurrentTemperature" }
			}
		   },
	["18_0"] = { type = "DevLuminosity", 
			params = { 
				Value = { sidMap.Light, "CurrentLevel" }
			}
		   },
	["21_0"] = { type = "DevElectricity", 
			params = { 
				ConsoTotal = { sidMap.Energy, "KWH" }, 
				Watts = { sidMap.Energy, "Watts"}
			}
		   },
	["28_0"] = { type = "DevUV", 
			params = { 
				Value = { sidMap.Light, "CurrentLevel" }
			}
		   }
}

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
local function buildDeviceDescription(id,nm,rm,tp)
	local d = {}
	d.id = tostring(id)
	d.name = nm
	d.room = tostring(rm)
	d.type = tp
	return d
end
local function buildDeviceParameter(k,v)
	p = {}
	p.key = k
	p.value = v
	return p
end
function ISS_GetDevices()
	local did = 1
	local res = {}
	res.devices = {}
	for id, dev in pairs(luup.devices) do
		-- Ignore hidden or invisible devices and those created by VeraBridge.
		if not (dev.hidden or dev.invisible or id >= 10000) then
			-- For special types we want to map based on schema
			if string.sub(dev.device_type, 1, string.len(schemaMap.HarmonyDev)) == schemaMap.HarmonyDev then
--[[  Not yet supported, but catch here else it matches with schemaMap.Harmony
				local d = buildDeviceDescription(id, dev.description, dev.room_num, "DevMultiSwitch")
				d.params = {}
				local choices = ""
				for bn = 1,25 do
					local actDesc = luup.variable_get(sidMap.HarmonyDev, "CommandDesc"..bn, id)
					local actID = luup.variable_get(sidMap.HarmonyDev, "CommandID"..bn, id)
					if actDesc and actDesc ~= "" then
						choices = choices ..actDesc .. ","
					end    
				end
				if choices ~= "" then
					d.params[1] = buildDeviceParameter("Choices", choices)
				end	
				res.devices[did] = d
				did = did + 1
]]				
			elseif string.sub(dev.device_type, 1, string.len(schemaMap.Harmony)) == schemaMap.Harmony then
				local d = buildDeviceDescription(id, dev.description, dev.room_num, "DevMultiSwitch")
				d.params = {}
				local curActDesc = ""
				local choices = ""
				local curActID = luup.variable_get(sidMap.Harmony, "CurrentActivityID", id)
				for bn = 1,25 do
					local actDesc = luup.variable_get(sidMap.Harmony, "ActivityDesc"..bn, id)
					local actID = luup.variable_get(sidMap.Harmony, "ActivityID"..bn, id)
					if actDesc and actDesc ~= "" then
						choices = choices ..actDesc .. ","
						if actID == curActID then curActDesc = actDesc end
					end    
				end
				d.params[1] = buildDeviceParameter("defaultIcon", "https://raw.githubusercontent.com/reneboer/vera-Harmony-Hub/master/icons/Harmony.png")
				if curActDesc ~= "" then
					d.params[2] = buildDeviceParameter("Value", curActDesc)
				end	
				if choices ~= "" then
					d.params[3] = buildDeviceParameter("Choices", choices)
				end	
				res.devices[did] = d
				did = did + 1
			elseif dev.device_type == schemaMap.SM_Gas then
				local d = buildDeviceDescription(id, dev.description, dev.room_num, "DevGenericSensor")
				d.params = {}
				d.params[1] = buildDeviceParameter("defaultIcon", "https://raw.githubusercontent.com/reneboer/openLuup-ImperiHome/master/gas.png")
				d.params[2] = buildDeviceParameter("Value", luup.variable_get(sidMap.SM_Gas, "Flow", id))
				d.params[3] = buildDeviceParameter("unit", "l/h")
				res.devices[did] = d
				did = did + 1
			else
				local issType = devMap[dev.category_num..'_'..dev.subcategory_num]
				if not issType then issType = devMap[dev.category_num..'_0'] end
				if issType then
					local d = buildDeviceDescription(id, dev.description, dev.room_num, issType.type)
					d.params = {}
					local pid = 1
					for key, prm_t in pairs(issType.params) do
						local val
						if type(prm_t) == "string" then
							val = prm_t
						else
							val = luup.variable_get(prm_t[1], prm_t[2], id)
						end	
						if val and val ~= "" then
							d.params[pid] = buildDeviceParameter(key, val)
							pid = pid + 1
						end    
					end    
					res.devices[did] = d
					did = did + 1
				end
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
		local issType = devMap[dev.category_num..'_'..dev.subcategory_num]
		if not issType then issType = devMap[dev.category_num..'_0'] end
		if issType then
			local act_t = issType.actions[action]
			if act_t then
				local prm = {}
				if param and act_t[3] then prm[act_t[3]] = tostring(param) end
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
_log(wsapi_env.QUERY_STRING)	
	local _, func_st = string.find(wsapi_env.QUERY_STRING, "query=", 1, true)
	if func_st then
		local func = string.sub(wsapi_env.QUERY_STRING, 8)
_log(func)	
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
