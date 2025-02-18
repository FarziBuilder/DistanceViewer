clear; clc;

%% 1. Create an ardupilotreader object for your log file
ardupilotObj = ardupilotreader("logs/hyd_26_flight.bin");  % Adjust the path as needed

%% 2. Read the AHR2 message (which holds the fused state data)
ahrsMsg = readMessages(ardupilotObj, 'MessageName', {'AHR2'});
ahrsData = ahrsMsg.MsgData{1,1};

disp('Available variables in AHR2:');
disp(ahrsData.Properties.VariableNames);

%% 3. Convert to a timetable if necessary and sort by time
% The first column 'TimeUS' represents time in microseconds.
if ~istimetable(ahrsData)
    ahrsData = table2timetable(ahrsData, 'RowTimes','TimeUS');
end
ahrsData = sortrows(ahrsData);

%% 4. Compute the altitude
% In this log, PD is the downward position.
% Altitude above the reference is given by -PD.
altitude2 = ahrsData.Alt;

%% 5. Convert TimeUS to seconds (if TimeUS is in microseconds)
%timeSec = double(ahrsData.TimeUS) / 1e6;

%% 6. Plot the altitude
figure('Name','Fused Altitude from AHR2');
plot(ahrsData.timestamp, altitude2, 'b.-');
grid on;
xlabel('Time (sec)');
ylabel('Altitude (units)');  % Verify the units (e.g., cm or m) based on your log
title('Fused Altitude Considered by the Plane (Altitude = -PD)');
