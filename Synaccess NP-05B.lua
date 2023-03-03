local User             = "admin"
local Password         = "admin"
local Rly              = nil
local Reboot           = nil
local masterStatus     = nil
local masterOnOff      = NamedControl.GetPosition("masterOnOff")
local masterOnOffState = NamedControl.GetPosition("masterOnOff")
local IP               = NamedControl.GetText("IP")
local Connected        = false
local Rebooting        = false
local Sequencying      = false
local rebootCounter    = 0
local updateCounter    = 0
local powerCounter     = 0

NamedControl.SetText("User", "")
NamedControl.SetText("Password", "")
NamedControl.SetText("Error", "")
NamedControl.SetPosition("Connected", 0)
for i = 0, 6 do
    NamedControl.SetPosition("led" .. i, 0)
end

local ledStatus = {
    [0] = nil,
    [1] = nil,
    [2] = nil,
    [3] = nil,
    [4] = nil,
    [5] = nil,
    [6] = nil
}

local powerSequencedRlys = {}


function ConnectResponse(Table, ReturnCode, Data, Error, Headers)

    print(Data)
    print(Table)
    print(ReturnCode)
    print(Error)
    print(Headers)
    IsData(ReturnCode, Data, "Connect")
end

function Connect()

    if Device.Offline then
        HttpClient.Upload({
            Url = "http://" .. IP .. "/status.xml",
            --Headers = { ["Authorization"] = "Basic YWRtaW46YWRtaW4=\r\n", ["Credentials"] = User .. ":" .. Password },
            User = User,
            Password = Password,
            Data = "",
            Method = "GET",
            EventHandler = ConnectResponse
        })
    elseif not Device.Offline then
        HttpClient.Upload({
            Url = "http://" .. IP .. "/status.xml",
            Headers = { ["Authorization"] = "Basic YWRtaW46YWRtaW4=\r\n", ["Credentials"] = User .. ":" .. Password },
            -- User = User,
            -- Password = Password,
            Data = "",
            Method = "GET",
            EventHandler = ConnectResponse
        })
    end
end

function GetPassword()

    Password = NamedControl.GetText("Password")
    User = NamedControl.GetText("User")
    -- NamedControl.SetText("Password", "********")
    -- NamedControl.SetText("User", "********")
end

function RlyResponse(Table, ReturnCode, Data, Error, Headers)

    -- print(Data)
    -- print(Table)
    -- print(ReturnCode)
    -- print(Error)
    -- print(Headers)
    -- IsData(ReturnCode, Data)

    if ReturnCode == 200 then
        if ledStatus[Rly] == "1" then
            NamedControl.SetPosition("led" .. tostring(Rly), 0)
            Controls.Outputs[Rly + 1].Value = 0
            ledStatus[Rly] = "0"
        elseif ledStatus[Rly] == "0" then
            NamedControl.SetPosition("led" .. tostring(Rly), 1)
            Controls.Outputs[Rly + 1].Value = 1
            ledStatus[Rly] = "1"
        end
    end
end

function Setrly()

    if Device.Offline then
        HttpClient.Upload({
            Url = 'http://' .. IP .. '/cmd.cgi?rly=' .. Rly,
            -- Headers = { ["Authorization"] = "Basic YWRtaW46YWRtaW4=\r\n", ["Credentials"] = User .. ":" .. Password },
            User = User,
            Password = Password,
            Data = "",
            Method = "GET",
            EventHandler = RlyResponse
        })
    elseif not Device.Offline then
        HttpClient.Upload({
            Url = 'http://' .. IP .. '/cmd.cgi?rly=' .. Rly,
            Headers = { ["Authorization"] = "Basic YWRtaW46YWRtaW4=\r\n", ["Credentials"] = User .. ":" .. Password },
            -- User = User,
            -- Password = Password,
            Data = "",
            Method = "GET",
            EventHandler = RlyResponse
        })
    end
end

function RebootResponse(Table, ReturnCode, Data, Error, Headers)

    --print(Data)
    -- print(Table)
    -- print(ReturnCode)
    -- print(Error)
    -- print(Headers)
    -- IsData(ReturnCode, Data)

    if ReturnCode == 200 then
        NamedControl.SetPosition("led" .. tostring(Reboot), 0)
        ledStatus[Reboot] = "0"
        Rebooting = true
        rebootCounter = 0
    end
end

function Setreboot()

    if Device.Offline then
        HttpClient.Upload({
            Url = 'http://' .. IP .. '/cmd.cgi?rb=' .. Reboot,
            --Headers = { ["Authorization"] = "Basic YWRtaW46YWRtaW4=\r\n", ["Credentials"] = User .. ":" .. Password },
            User = User,
            Password = Password,
            Data = "",
            Method = "GET",
            EventHandler = RebootResponse
        })
    elseif not Device.Offline then
        HttpClient.Upload({
            Url = 'http://' .. IP .. '/cmd.cgi?rb=' .. Reboot,
            Headers = { ["Authorization"] = "Basic YWRtaW46YWRtaW4=\r\n", ["Credentials"] = User .. ":" .. Password },
            -- User = User,
            -- Password = Password,
            Data = "",
            Method = "GET",
            EventHandler = RebootResponse
        })
    end
end

function IsData(ReturnCode, Data, Connect)

    if ReturnCode == 401 then
        NamedControl.SetText("Error", Data)
        NamedControl.SetPosition("Connected", 0)
    elseif ReturnCode == 200 then
        NamedControl.SetText("Error", "")
    elseif ReturnCode == 0 then
        NamedControl.SetText("Error", "Timeout Error")
    elseif ReturnCode == 404 then
        NamedControl.SetText("Error", "404 Error")
    end

    if ReturnCode ~= 200 then
        NamedControl.SetPosition("Connected", 0)
    end

    if Connect == "Connect" and ReturnCode == 200 then

        Connected = true
        NamedControl.SetPosition("Connected", 1)
        if Data:match("<response>") then
            for i = 0, 6 do
                ledStatus[i] = string.match(Data, "%b<rly" .. i .. ">%d</rly" .. i .. ">")
                ledStatus[i] = string.gsub(ledStatus[i], "<rly" .. i .. ">", "")
                ledStatus[i] = string.gsub(ledStatus[i], "</rly" .. i .. ">", "")

                NamedControl.SetPosition("led" .. i, ledStatus[i])
                Controls.Outputs[i + 1].Value = ledStatus[i]
            end
        end
    end
end

function Powersequence()

    powerCounter = powerCounter + 1
    timeInterval = 4 * NamedControl.GetValue("seqTime")

    if powerCounter == timeInterval then
        for k, v in pairs(powerSequencedRlys) do
            if masterStatus == "Off" then
                if powerTableLength == k then
                    Rly = v - 1
                    Setrly()
                    powerSequencedRlys[k] = nil
                end
            end
            if masterStatus == "On" then
                if k == 1 then
                    Rly = v - 1
                    Setrly()
                    table.remove(powerSequencedRlys, 1)
                end
            end
        end
        powerCounter = 0
    end

    powerTableLength = #powerSequencedRlys
    if powerTableLength == 0 then
        Sequencying = false
    end

end

function TimerClick()

    IP = NamedControl.GetText("IP")

    if NamedControl.GetPosition("Connect") == 1 then
        Connect()
        NamedControl.SetPosition("Connect", 0)
    end

    if NamedControl.GetPosition("Enter") == 1 then
        GetPassword()
        NamedControl.SetPosition("Enter", 0)
    end
    if Connected then
        masterOnOff = NamedControl.GetPosition("masterOnOff")
        updateCounter = updateCounter + 1

        for i = 0, 6 do
            if NamedControl.GetPosition("rly" .. i) == 1 then
                Rly = i
                Setrly()
                NamedControl.SetPosition("rly" .. i, 0)
            end
            if NamedControl.GetPosition("reboot" .. i) == 1 then
                Reboot = i
                Setreboot()
                NamedControl.SetPosition("reboot" .. i, 0)
            end
        end
        if Rebooting then
            rebootCounter = rebootCounter + 1
            if rebootCounter == 16 then
                Connect()
                Rebooting = false
            end
        end
        if updateCounter == 30 then
            Connect()
            updateCounter = 0
        end
        if masterOnOffState ~= masterOnOff then
            for i = 0, 6 do
                if masterOnOff == 0 then
                    if ledStatus[i] == "1" and NamedControl.GetPosition("seq" .. i) == 1 then
                        table.insert(powerSequencedRlys, i + 1)
                        masterStatus = "Off"
                    end
                end
                if masterOnOff == 1 then
                    if ledStatus[i] == "0" and NamedControl.GetPosition("seq" .. i) == 1 then
                        table.insert(powerSequencedRlys, i + 1)
                        masterStatus = "On"
                    end
                end
            end
            Sequencying = true
            updateCounter = 0
            powerCounter = (4 * NamedControl.GetValue("seqTime")) - 1
            masterOnOffState = masterOnOff
            powerTableLength = #powerSequencedRlys
        end
        if Sequencying and powerTableLength ~= 0 then
            Powersequence()
        end
    end
end

MyTimer = Timer.New()
MyTimer.EventHandler = TimerClick
MyTimer:Start(.25)
