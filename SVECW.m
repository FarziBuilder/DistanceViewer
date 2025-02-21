%% Define file path and cutoff time
filePath = "SVECW.tlog";
cutoffTime = datetime(2018, 05, 18, 18, 0, 0);  % Change to your desired cutoff

%% Create the mavlinktlog object (uses common.xml by default)
tlogReader = mavlinktlog(filePath);

%% Retrieve list of available message topics
% The AvailableTopics property is a table; here we assume it has a column named "MessageName"
topicsTable = tlogReader.AvailableTopics;

%% Initialize a structure to hold filtered messages for each topic
filteredMessages = struct();

%% Loop through each topic, read messages, and filter by cutoff time
for i = 1:height(topicsTable)
    % Get the message name (adjust the column name if your table differs)
    msgName = topicsTable.MessageName{i};
    
    % Read all messages for the current message type
    msgData = readmsg(tlogReader, "MessageName", msgName);
    
    % Check if the returned data has a timetable of messages
    if isfield(msgData, 'Messages') && istimetable(msgData.Messages)
        % Filter out messages with timestamps after the cutoff time.
        % This assumes the timetable has a 'Time' column.
        validIdx = msgData.Messages.Time <= cutoffTime;
        msgData.Messages = msgData.Messages(validIdx, :);
    end
    
    % Store the filtered data in the structure using the message name as a field
    filteredMessages.(msgName) = msgData;
end

%% Optional: Save the filtered messages to a new MAT file
save('filteredTlog.mat', 'filteredMessages');

%% Display summary of filtered messages
disp('Filtered MAVLink TLOG messages (only entries before cutoff):');
disp(filteredMessages);
