ESX = nil
local pos_before_assist,assisting,assist_target,last_assist,IsFirstSpawn = nil, false, nil, nil, true

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
	SetNuiFocus(false, false)
end)

function GetIndexedPlayerList()
	local players = {}
	for k,v in ipairs(GetActivePlayers()) do
		players[tostring(GetPlayerServerId(v))]=GetPlayerName(v)..(v==PlayerId() and " (self)" or "")
	end
	return json.encode(players)
end

RegisterNUICallback("ban", function(data,cb)
	if not data.target or not data.reason then return end
	ESX.TriggerServerCallback("el_bwh:ban",function(success,reason)
		if success then ESX.ShowNotification("~g~Successfully banned player") else ESX.ShowNotification(reason) end -- dont ask why i did it this way, im a bit retarded
	end, data.target, data.reason, data.length, data.offline)
end)

RegisterNUICallback("warn", function(data,cb)
	if not data.target or not data.message then return end
	ESX.TriggerServerCallback("el_bwh:warn",function(success)
		if success then ESX.ShowNotification("~g~Successfully warned player") else ESX.ShowNotification("~r~Something went wrong") end
	end, data.target, data.message, data.anon)
end)

RegisterNUICallback("unban", function(data,cb)
	if not data.id then return end
	ESX.TriggerServerCallback("el_bwh:unban",function(success)
		if success then ESX.ShowNotification("~g~Successfully unbanned player") else ESX.ShowNotification("~r~Something went wrong") end
	end, data.id)
end)

RegisterNUICallback("getListData", function(data,cb)
	if not data.list or not data.page then cb(nil); return end
	ESX.TriggerServerCallback("el_bwh:getListData",function(data)
		cb(data)
	end, data.list, data.page)
end)

RegisterNUICallback("hidecursor", function(data,cb)
	SetNuiFocus(false, false)
end)

AddEventHandler("playerSpawned", function(spawn)
    if IsFirstSpawn and Config.backup_kick_method then
        TriggerServerEvent("el_bwh:backupcheck")
        IsFirstSpawn = false
    end
end)

RegisterNetEvent("el_bwh:gotBanned")
AddEventHandler("el_bwh:gotBanned",function(rsn)
	Citizen.CreateThread(function()
		local scaleform = RequestScaleformMovie("mp_big_message_freemode")
		while not HasScaleformMovieLoaded(scaleform) do Citizen.Wait(0) end
		BeginScaleformMovieMethod(scaleform, "SHOW_SHARD_WASTED_MP_MESSAGE")
		PushScaleformMovieMethodParameterString("~r~BANEADO(A)")
		PushScaleformMovieMethodParameterString(rsn)
		PushScaleformMovieMethodParameterInt(5)
		EndScaleformMovieMethod()
		PlaySoundFrontend(-1, "LOSER", "HUD_AWARDS")
		ClearDrawOrigin()
		ESX.UI.HUD.SetDisplay(0)
		while true do
			Citizen.Wait(0)
			DisableAllControlActions(0)
			DisableFrontendThisFrame()
			local ped = GetPlayerPed(-1)
			ESX.UI.Menu.CloseAll()
			SetEntityCoords(ped, 0, 0, 0, 0, 0, 0, false)
			FreezeEntityPosition(ped, true)
			DrawRect(0.0,0.0,2.0,2.0,0,0,0,255)
			DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
		end
		SetScaleformMovieAsNoLongerNeeded(scaleform)
	end)
end)

RegisterNetEvent("el_bwh:receiveWarn")
AddEventHandler("el_bwh:receiveWarn",function(sender,message)
	TriggerEvent("chat:addMessage",{color={255,255,0},multiline=true,args={"BWH  ","Has recibido una advertencia"..(sender~="" and " de "..sender or "").."!\n-> "..message}})
	Citizen.CreateThread(function()
		local scaleform = RequestScaleformMovie("mp_big_message_freemode")
		while not HasScaleformMovieLoaded(scaleform) do Citizen.Wait(0) end
		BeginScaleformMovieMethod(scaleform, "SHOW_SHARD_WASTED_MP_MESSAGE")
		PushScaleformMovieMethodParameterString("~y~AVISO")
		PushScaleformMovieMethodParameterString(message)
		PushScaleformMovieMethodParameterInt(5)
		EndScaleformMovieMethod()
		PlaySoundFrontend(-1, "LOSER", "HUD_AWARDS")
		local drawing = true
		Citizen.SetTimeout((Config.warning_screentime * 1000),function() drawing = false end)
		while drawing do
			Citizen.Wait(0)
			DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
		end
		SetScaleformMovieAsNoLongerNeeded(scaleform)
	end)
end)

RegisterNetEvent("el_bwh:requestedAssist")
AddEventHandler("el_bwh:requestedAssist",function(t)
	SendNUIMessage({show=true,window="assistreq",data=Config.popassistformat:format(GetPlayerName(GetPlayerFromServerId(t)),t)})
	last_assist=t
end)

RegisterNetEvent("el_bwh:acceptedAssist")
AddEventHandler("el_bwh:acceptedAssist",function(t)
	if assisting then return end
	local target = GetPlayerFromServerId(t)
	if target then
		local ped = GetPlayerPed(-1)
		pos_before_assist = GetEntityCoords(ped)
		assisting = true
		assist_target = t
		--ESX.Game.Teleport(ped,GetEntityCoords(GetPlayerPed(target))+vector3(0,0.5,0))

		local Pos = GetEntityCoords(GetPlayerPed(target))

		SetEntityCoords(ped, Pos.x, Pos.y, Pos.z, false, false, false, true)

	end
end)

RegisterNetEvent("el_bwh:assistDone")
AddEventHandler("el_bwh:assistDone",function()
	if assisting then
		assisting = false
		if pos_before_assist~=nil then ESX.Game.Teleport(GetPlayerPed(-1),pos_before_assist+vector3(0,0.5,0)); pos_before_assist = nil end
		assist_target = nil
	end
end)

RegisterNetEvent("el_bwh:hideAssistPopup")
AddEventHandler("el_bwh:hideAssistPopup",function(t)
	SendNUIMessage({hide=true})
	last_assist=nil
end)

RegisterNetEvent("el_bwh:showWindow")
AddEventHandler("el_bwh:showWindow",function(win)
	if win=="ban" or win=="warn" then
		SendNUIMessage({show=true,window=win,players=GetIndexedPlayerList()})
	elseif win=="banlist" or win=="warnlist" then
		SendNUIMessage({loading=true,window=win})
		ESX.TriggerServerCallback(win=="banlist" and "el_bwh:getBanList" or "el_bwh:getWarnList",function(list,pages)
			SendNUIMessage({show=true,window=win,list=list,pages=pages})
		end)
	end
	SetNuiFocus(true, true)
end)

RegisterCommand("asistesconder",function(a,b,c)
	TriggerEvent("el_bwh:hideAssistPopup")
end, false)

if Config.assist_keys.enable then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(0)
			if IsControlJustPressed(0, Config.assist_keys.accept) then
				if not NetworkIsPlayerActive(GetPlayerFromServerId(last_assist)) then
					last_assist = nil
				else
					TriggerServerEvent("el_bwh:acceptAssistKey",last_assist)
				end
			end
			if IsControlJustPressed(0, Config.assist_keys.decline) then
				TriggerEvent("el_bwh:hideAssistPopup")
			end
		end
	end)
end

Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/asistesconder', 'Esconder aviso de asistencia',{})
    TriggerEvent('chat:addSuggestion', '/asistencia', 'Solicitar ayuda del staff',{{name="Razón", help="¿En qué necesitas ayuda?"}})
    TriggerEvent('chat:addSuggestion', '/asistcancelar', 'Cancelar tu pedido de asistencia',{})
    TriggerEvent('chat:addSuggestion', '/asistfinalizar', 'Finalizar asistencia y regresar',{})
    TriggerEvent('chat:addSuggestion', '/asistaceptar', 'Acceptar asistencia', {{name="ID", help="ID del jugador"}})
end)