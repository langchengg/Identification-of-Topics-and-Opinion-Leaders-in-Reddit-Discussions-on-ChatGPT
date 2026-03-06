clc;
clear;
close all;

% Read the CSV file containing Reddit comments
inputFilename = 'chatgpt-reddit-comments.csv'; % Update with your actual filename
commentsTable = readtable(inputFilename);

% Add serial number column for unique identification
commentsTable.Properties.VariableNames{1} = 'serial_number';
commentsTable.serial_number = (1:height(commentsTable))';

% Process comment_parent_id to remove any "xx_" prefix where x is any character
% Use vectorized regexprep on the entire column at once for improved performance
commentsTable.comment_parent_id = regexprep(commentsTable.comment_parent_id, '^[a-zA-Z0-9]{2}_', '');

% Write the cleaned data to a new CSV file
outputFilename = 'updated_chatgpt_reddit_comments.csv';
writetable(commentsTable, outputFilename);

disp('Processing complete. Updated data saved to updated_chatgpt_reddit_comments.csv');