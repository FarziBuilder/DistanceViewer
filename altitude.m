% Example: Plot the Altitude from ArduPilot BIN log
clear; clc;

% 1) Read the Flight Log Data
bin = ardupilotreader('logs/flight5.bin');  % <-- change path accordingly

% 2) Extract GPS Messages (the altitude is typically in the GPS message, 
%    but could also be in BARO message or elsewhere, depending on your log)
gpsMsg = readMessages(bin, 'MessageName', {'GPS'});

% 3) Extract the GPS data (assumed to be in the first element of MsgData).
gpsData = gpsMsg.MsgData{1,1};

figure;
plot(gpsData.timestamp, gpsData.Alt);
xlabel('Time (duration)');
ylabel('Altitude (m)');   % Adjust if your data is in centimeters
title('Altitude from GPS Data');
grid on;
