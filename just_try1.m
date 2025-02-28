% Clear workspace
clear; clc;

% Define input and output file names
input_logfile = 'SVECW.tlog';  % Replace with your actual .tlog file path
output_logfile = 'filtered_SVECW.tlog'; % Output file after filtering

% Load the MAVLink log file
mavlog = mavlinktlog(input_logfile);

% Extract timestamps from messages
timestamps = [mavlog.messages.timestamp]; % Get all timestamps

% Define cutoff timestamp (Replace with desired timestamp)
cutoff_time = 1.5e9; % Example: 1.5 billion seconds (modify as needed)

% Filter messages before or at the cutoff timestamp
filtered_messages = mavlog.messages(timestamps <= cutoff_time);

% Check if there are messages left after filtering
if isempty(filtered_messages)
    error('No messages remain after filtering. Adjust the cutoff time.');
end

% Create a new MAVLink log object with filtered messages
filtered_mavlog = mavlinktlog();
filtered_mavlog.messages = filtered_messages;

% Save the filtered log to a new .tlog file
try
    save(output_logfile, 'filtered_mavlog');
    fprintf('Filtered log saved as %s\n', output_logfile);
catch
    error('Error saving the filtered log file.');
end

disp('Filtering complete.');
