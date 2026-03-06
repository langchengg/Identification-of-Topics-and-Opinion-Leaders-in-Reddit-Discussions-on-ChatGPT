clc;
clear;
close all

% Read the CSV file containing Reddit comments
inputFilename = 'updated_chatgpt_reddit_comments.csv'; % Update with your actual filename
commentsTable = readtable(inputFilename);

% Extract comment_id and comment_parent_id columns
commentIds = commentsTable.comment_id;
parentCommentIds = commentsTable.comment_parent_id;

% Collect all unique node identifiers
uniqueNodeIds = unique([commentIds; parentCommentIds]);

% Create a list of edges (source, target)
% Each edge connects a child comment to its parent comment
childCommentIds = commentIds;
parentNodeIds = parentCommentIds;

% Create a directed graph representing comment thread structure
commentThreadGraph = digraph(childCommentIds, parentNodeIds, [], uniqueNodeIds, 'OmitSelfLoops');

% Plot the comment thread graph using force-directed layout
figure;
graphPlot = plot(commentThreadGraph, 'Layout', 'force');
axis off;

% Adjust figure size for better visualization
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0, 0.04, 1, 0.96]);

% Save the figure as a PNG file: saveas(gcf, 'CommentThreadGraph.png');

