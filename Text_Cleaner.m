clc;
clear;
close all;

% Read the Excel file
filename = 'chatgpt-reddit-comments.csv'; % Update with your actual filename
data = readtable(filename);

% Add serial number column
data.Properties.VariableNames{1} = 'serial_number';
data.serial_number = (1:height(data))';

% Process comment_parent_id to remove any "xx_" prefix where x is any character
% Use vectorized regexprep on the entire column at once for improved performance
data.comment_parent_id = regexprep(data.comment_parent_id, '^[a-zA-Z0-9]{2}_', '');

% Write the updated data to a new CSV file
writetable(data, 'updated_chatgpt_reddit_comments.csv');

disp('Processing complete. Updated data saved to updated_chatgpt_reddit_comments.csv');