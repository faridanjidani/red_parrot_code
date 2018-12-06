motor_pin = 1 --changed
touch_pin1 = 2 --changedgpio4 
touch_pin2 = 3 -- changedgpio0->io3
touch_pin3 = 6
VR_in_progress_flag = 0
ack_flag = 0
EVR_com_flag = 0
head_sensor_status = 1
tummy_sensor_status = 1
back_sensor_status = 1
log_vals = {}; --tbhv
uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1);
startb = 0x7e 	-- no change 
VER = 0xff		-- no change
Len = 0x06 		-- no change (always 6)
CMD = 0x00		-- command
Feedback = 0x00	-- enable feedback or not

endb = 0xef		-- no change

gpio.mode(touch_pin1, gpio.INT,gpio.PULLUP)
gpio.mode(touch_pin2, gpio.INT,gpio.PULLUP)
gpio.mode(touch_pin3, gpio.INT,gpio.PULLUP)
gpio.mode(motor_pin, gpio.OUTPUT)
gpio.write(motor_pin, gpio.LOW)

servo_pin = 8 --this is GPIO2
gpio.mode(servo_pin,gpio.OUTPUT)
gpio.write(servo_pin,gpio.LOW)
function move_parrot(value)
    gpio.write(servo_pin, gpio.LOW)
    count = 0
    tmr.alarm(1, 20, tmr.ALARM_AUTO, function() -- 50Hz 
        gpio.write(servo_pin, gpio.HIGH)
        tmr.delay(value)
        gpio.write(servo_pin, gpio.LOW)
        count = count + 1
        if count == 10 then
            tmr.stop(1)
            tmr.unregister(1)
        end
    end)
end
move_parrot(1000)
function create_log_file()
    file.remove("log.txt");
    file.open("log.txt", "w+")
    for i = 1, 4 do
        file.writeline('0')
    end
    file.close()
end


function create_msgList_file()
    file.remove("msgList.txt");
    file.open("msgList.txt", "w+")
    for i = 1, 3 do
        file.writeline('1')
    end
    for i = 4, 14 do
        file.writeline('0')
    end
    for i = 15, 32 do
        file.writeline('1')
    end
    file.close()
end

function create_log_file()
    file.remove("log.txt");
    file.open("log.txt", "w+")
    for i = 1, 4 do
        file.writeline('0')
    end
    file.close()
end


function read_log_from_file(vals)
    if not file.open("log.txt", "r") then
        create_log_file()
    end

	file.open("log.txt", "r")
    for i = 1, 4 do
        vals[i] = tonumber((string.gsub(file.readline(), "\n", "")), 10)
    end
    file.close()
end
read_log_from_file(log_vals)
function write_log_to_file(vals)
    file.open("log.txt", "w+")
    for i = 1, 4 do
        file.writeline(vals[i])
    end
    file.close()
end
function inc_log(vals, idx)
	vals[idx] = vals[idx] + 1
	vals[4] = vals[4] + 1
	write_log_to_file(vals)
end


gpio.trig(touch_pin1, "down" ,function() if(tummy_sensor_status == 1) then inc_log(log_vals, 3) vibrate() end end)
gpio.trig(touch_pin2, "down" ,function() if(back_sensor_status == 1)  then inc_log(log_vals, 2) vibrate() end end)
gpio.trig(touch_pin3, "down" ,function() if(head_sensor_status == 1)  then inc_log(log_vals, 1) vibrate() end end)
wifi.setmode(wifi.SOFTAP)
cfg={}
cfg.ssid="ESP-parrot"
cfg.pwd="12345678"
wifi.ap.config(cfg)
cfg = {ip="192.168.1.1", netmask="255.255.255.0", gateway="192.168.1.1"}
wifi.ap.setip(cfg)
wifi.sleeptype(wifi.NONE_SLEEP)
wifi.setphymode(wifi.PHYMODE_G)
print("create wifi")

function vibrate()
    gpio.write(motor_pin, gpio.HIGH)
	tmr.delay(500000)
	gpio.write(motor_pin, gpio.LOW)
	--tmr.alarm(1, 500, tmr.ALARM_SINGLE, function() gpio.write(motor_pin, gpio.LOW) end)
	
end

function json_encoder(keys, values)
    pairs = {}
    n = table.getn(keys)
    for i = 1, n do
        pairs[keys[i]] = values[i]
    end
    
    ok, json = pcall(sjson.encode, pairs)
    if ok then
      return json
    else
      return nil
    end
end  

headers = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n";
msg_list_keys = {"key_0", "key_1", "key_2", "key_3", "key_4", "key_5", "key_6", "key_7", "key_8", "key_9", "key_10",
				"key_11", "key_12", "key_13", "key_14", "key_15", "key_16", "key_17", "key_18", "key_19", "key_20",
				"key_21", "key_22", "key_23", "key_24", "key_25", "key_26", "key_27", "key_28", "key_29", "key_30", "key_31"};
msg_list_vals = {};

function read_table_from_file(vals)
    if not file.open("msgList.txt", "r") then
        create_msgList_file()
    end

	file.open("msgList.txt", "r")
    for i = 1, 32 do
        vals[i] = tonumber((string.gsub(file.readline(), "\n", "")), 10)
    end
    file.close()
end

read_table_from_file(msg_list_vals)

function write_table_to_file(vals)
    file.open("msgList.txt", "w+")
    for i = 1, 32 do
        file.writeline(vals[i])
    end
    file.close()
end



function ply(InCMD,par1,par2)
	CMD = InCMD
	--If user pass parameters then replace default values
	if par1 ~=nil then
		para1 = par1
	end 
	if par2 ~=nil then
		para2 = par2
	end 
	result = -(VER+Len+CMD+Feedback+para1+para2) -- used for checksum
	output = string.format("%x", result * 256) 
	checksumpart1=("0x"..string.sub(output,3,4))
	checksumpart2=("0x"..string.sub(output,5,6))
	uart.write(0,tonumber(startb))	--Send the command to dfplayer module
	uart.write(0,tonumber(VER))
	uart.write(0,tonumber(Len))
	uart.write(0,tonumber(CMD))
	uart.write(0,tonumber(Feedback))
	uart.write(0,tonumber(para1))
	uart.write(0,tonumber(para2))
	uart.write(0,tonumber(checksumpart1))
	uart.write(0,tonumber(checksumpart2))
	uart.write(0,tonumber(endb))

end


tmr.register(0, 5000, tmr.ALARM_AUTO, function() voice_rec_request() end)
srv=net.createServer(net.TCP, 10)
print("server created")
srv:listen(80,function(conn)
print("connected")
conn:on("receive", function(client,request)
    local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
    if(method == nil)then 
        _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP"); 
    end
    local _GET = {}
    if (vars ~= nil)then 
        for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do 
            _GET[k] = v 
        end 
    end
	print(_GET)
	if(_GET.pin == "statusQuery") then
		temp_key = {"key_0", "key_1", "key_2", "key_3"}
		print("statusQuery1")
        temp_val = {head_sensor_status, back_sensor_status, tummy_sensor_status , volumenumber}
        client:send(headers..json_encoder(temp_key, temp_val))
	elseif(_GET.pin == "syncQuery") then
		temp_key = {"key_0", "key_1", "key_2", "key_3"}
        temp_val = {log_vals[1], log_vals[2], log_vals[3], log_vals[4]}
        client:send(headers..json_encoder(temp_key, temp_val))
	elseif(_GET.pin == "rstLog") then
        log_vals = {0, 0, 0, 0}
        write_log_to_file(log_vals)
    elseif(_GET.pin == "msgQuery") then
		client:send(headers..json_encoder(msg_list_keys, msg_list_vals));
		
    elseif(string.find(_GET.pin, "playMsg") ~= nil) then -- playback
		local uart_cmd = "p@" .. string.char(tonumber(string.sub(_GET.pin, 8)) + 65) .. "A"
        uart.write(0, uart_cmd)
	elseif(string.find(_GET.pin, "eMsg") ~= nil) then -- erase
		local uart_cmd = "e@" .. string.char(tonumber(string.sub(_GET.pin, 5)) + 65)
		idx = tonumber(string.sub(_GET.pin, 5)) + 1
		msg_list_vals[idx] = 0 -- editing msg table
		write_table_to_file(msg_list_vals) -- saving file
		client:send(headers..json_encoder(msg_list_keys, msg_list_vals))
		uart.write(0, uart_cmd)
	elseif(string.find(_GET.pin, "rMsg") ~= nil) then -- record
		local uart_cmd = "r@" .. string.char(tonumber(string.sub(_GET.pin, 5)) + 65) .. "IA"
		uart.write(0, uart_cmd)
	elseif(string.find(_GET.pin, "stopMsg") ~= nil) then -- stop and save	
		idx = tonumber(string.sub(_GET.pin, 8)) + 1
		msg_list_vals[idx] = 1 -- editing msg table
		write_table_to_file(msg_list_vals) -- saving file
		client:send(headers..json_encoder(msg_list_keys, msg_list_vals));
		uart.write(0, "b")
          
    elseif(_GET.pin == "VR") then
          voice_rec_request();
    elseif(_GET.pin == "SAVR0") then --Stop Auto VR
        tmr.stop(0)
    elseif(_GET.pin == "SAVR1") then --Start Auto VR
        tmr.start(0)
    elseif(_GET.pin == "EVR") then
        if(EVR_com_flag == 0) then
            EVR_com_flag = 1
            establish_evr_com()
        end
    elseif(_GET.pin == "SL") then
        uart.write(0, "x")
    elseif(_GET.pin == "SHES1") then
		head_sensor_status = 1
    elseif(_GET.pin == "SHES0") then
        head_sensor_status = 0
    elseif(_GET.pin == "SBAS1") then
        back_sensor_status = 1 
    elseif(_GET.pin == "SBAS0") then
        back_sensor_status = 0
    elseif(_GET.pin == "STUS1") then
        tummy_sensor_status = 1
    elseif(_GET.pin == "STUS0") then
        tummy_sensor_status = 0
		
		
    elseif(_GET.pin == "Track") then
		para1 = 0x00	-- command parameter 1 ***check it
		para2 = 0x00	-- command parameter 2
		command = _GET.command
		par1 =_GET.par1
		par2 = _GET.par2
		ply(command, par1, par2);
		print(command)
		print(par1)
		print(par2)
		move_parrot(1500)
        tmr.alarm(3, 1000, 0, function()
            move_parrot(1000)
        end)
		
		
	elseif(_GET.pin == "motorstart")then
		gpio.write(motor_pin, gpio.HIGH)
		tmr.delay(500000)
		gpio.write(motor_pin, gpio.LOW)
	end	
	
	
    client:close();
end)
end)
EVR_com_flag = 1
--establish_evr_com()
