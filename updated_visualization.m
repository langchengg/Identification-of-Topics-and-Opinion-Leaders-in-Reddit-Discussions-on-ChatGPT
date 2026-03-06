clc;
clear;
close all

%% Read Data and Construct Graph
% Read the CSV file containing Reddit comments
inputFilename = 'updated_chatgpt_reddit_comments.csv';
commentsTable = readtable(inputFilename);

% Extract comment_id and comment_parent_id from the data table.
commentIds = commentsTable.comment_id;
parentCommentIds = commentsTable.comment_parent_id;

% Collect all unique node identifiers.
uniqueNodeIds = unique([commentIds; parentCommentIds]);

% Create a list of edges (source, target).
% Here, an edge goes from a comment (child) to its parent.
childCommentIds = commentIds;
parentNodeIds = parentCommentIds;

% Create a directed graph representing comment thread structure (omitting self loops)
commentThreadGraph = digraph(childCommentIds, parentNodeIds, [], uniqueNodeIds, 'OmitSelfLoops');

% Plot the graph using a force-directed layout.
figure;
graphPlot = plot(commentThreadGraph, 'Layout', 'force');
title('Comment Thread Graph');
axis off;

% Adjust figure size for better visualization.
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0, 0.04, 1, 0.96]);

% Store the graph and data table in the figure's UserData for callback access.
set(gcf, 'UserData', struct('commentThreadGraph', commentThreadGraph, 'commentsTable', commentsTable, 'graphPlotHandle', graphPlot));
%% Display Top Users Based on PageRank

% PageRank: finds nodes with high influence based on link structure.
pageRankScores = centrality(commentThreadGraph, 'pagerank');
% Store these measures in the Nodes table for later use.
commentThreadGraph.Nodes.PageRank = pageRankScores;
% Sort nodes by PageRank in descending order.
[sortedPageRankScores, sortedPageRankIndices] = sort(pageRankScores, 'descend');

% Set topUserCount ensuring it does not exceed the total number of nodes.
topUserCount = 5;
if topUserCount > numel(commentThreadGraph.Nodes.Name)
    topUserCount = numel(commentThreadGraph.Nodes.Name);
end

topUserIds = commentThreadGraph.Nodes.Name(sortedPageRankIndices(1:topUserCount));
topUserPageRankScores = sortedPageRankScores(1:topUserCount);

disp('Top users based on PageRank:');
for rankIndex = 1:topUserCount
    fprintf('%d. User: %s | PageRank Score: %.5f\n', rankIndex, topUserIds{rankIndex}, topUserPageRankScores(rankIndex));
end

% Highlight top users (by PageRank) in red.
highlight(graphPlot, topUserIds, 'NodeColor', 'r', 'MarkerSize', 7);
% Annotate top users with their rank number.
% Note: When many nodes are highlighted, overlapping text may occur.
% Use findnode for efficient node index lookup instead of find+strcmp
topUserNodeIndices = findnode(commentThreadGraph, topUserIds);
for rankIndex = 1:topUserCount
    nodeIndex = topUserNodeIndices(rankIndex);
    % Only annotate if the node coordinates exist (to avoid errors).
    if nodeIndex > 0
        text(graphPlot.XData(nodeIndex), graphPlot.YData(nodeIndex), num2str(rankIndex), ...
            'FontSize', 8, 'Color', 'k', 'FontWeight', 'bold');
    end
end
%% Attach Node Click Callback
% The ButtonDownFcn is set on the overall plot.
% When a click occurs, the callback will identify the nearest node based on the node coordinates.
set(graphPlot, 'ButtonDownFcn', @handleNodeClick);

%% Callback Function for Mouse Click on Graph Nodes
function handleNodeClick(~, eventData)
    % Retrieve the stored graph, data, and plot handle from the figure.
    figureData = get(gcf, 'UserData');
    commentThreadGraph = figureData.commentThreadGraph;
    commentsTable = figureData.commentsTable;
    graphPlotHandle = figureData.graphPlotHandle;
    
    % --- Determine the clicked node ---
    % Use the click location to find the nearest node marker.
    clickPoint = eventData.IntersectionPoint(1:2);
    distancesToNodes = sqrt((graphPlotHandle.XData - clickPoint(1)).^2 + (graphPlotHandle.YData - clickPoint(2)).^2);
    [minimumDistance, nearestNodeIndex] = min(distancesToNodes);
    
    % (Optional) Define a threshold; if the click is too far from any node, exit.
    clickDistanceThreshold = 0.05;
    if minimumDistance > clickDistanceThreshold
        disp('Click was not close enough to any node.');
        return;
    end
    
    % Identify the clicked node by its comment_id.
    clickedCommentId = commentThreadGraph.Nodes.Name{nearestNodeIndex};
    disp(['Clicked comment_id: ', clickedCommentId]);
    
    % Retrieve the corresponding serial_number from the data table.
    matchingRowIndex = strcmp(string(commentsTable.comment_id), string(clickedCommentId));
    if any(matchingRowIndex)
        disp(['Serial number for clicked comment: ', num2str(commentsTable.serial_number(matchingRowIndex))]);
    else
        disp('Clicked comment_id not found in data table.');
    end
    
    % --- Find descendant nodes based on the graph structure ---
    % Since edges in commentThreadGraph point from child to parent, reverse the edge directions
    % to get the "children" and further descendants.
    reversedGraph = flipedge(commentThreadGraph);
    descendantCommentIds = bfsearch(reversedGraph, clickedCommentId);
    % Exclude the clicked node itself.
    descendantCommentIds(strcmp(descendantCommentIds, clickedCommentId)) = [];
    disp('Connected comment_ids (descendants) under this node:');
    disp(descendantCommentIds);
    
    % --- Filter data and display comment details ---
    % Filter the data table to include rows for the clicked comment and its descendants.
    allRelatedCommentIds = [clickedCommentId; descendantCommentIds];
    matchingDataRows = ismember(string(commentsTable.comment_id), string(allRelatedCommentIds));
    filteredCommentsTable = commentsTable(matchingDataRows, :);
    
    % Display how many comments (documents) are used for the topic analysis.
    fprintf('Performing topic analysis on %d comments...\n', height(filteredCommentsTable));
    
    % Build a multi-line string with comment details.
    commentDetailsString = '';
    for commentIndex = 1:height(filteredCommentsTable)
        commentDetailsString = sprintf('%scomment_id: %s | serial_number: %s\nComment: %s\n\n', ...
            commentDetailsString, string(filteredCommentsTable.comment_id(commentIndex)), string(filteredCommentsTable.serial_number(commentIndex)), string(filteredCommentsTable.comment_body{commentIndex}));
    end
    
    % Display the comment details in a new figure with a scrollable text box.
    commentDetailsFigure = figure('Name', 'Comment Details', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
    % Create an editable uicontrol that allows scrolling.
    uicontrol('Parent', commentDetailsFigure, 'Style', 'edit', 'Max', 2, 'Min', 0, ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.05 0.05 0.9 0.9], ...
        'String', commentDetailsString, 'FontSize', 8);
    
    % --- Clean and tokenize the comment text ---
    % Convert comment_body to lowercase, remove punctuation, and remove stop words.
    tokenizedComments = tokenizedDocument(lower(filteredCommentsTable.comment_body));
    tokenizedComments = erasePunctuation(tokenizedComments);
    tokenizedComments = removeStopWords(tokenizedComments);
    
    % --- Build the TF-IDF matrix ---
    % Create a bag-of-words model.
    wordBagModel = bagOfWords(tokenizedComments);
    % Compute the TF-IDF matrix as a sparse matrix.
    tfidfMatrix = tfidf(wordBagModel);
    
    % --- Latent Semantic Analysis (LSA) and Word Cloud ---
    % Use singular value decomposition (SVD) to extract latent topics.
    [~, ~, rightSingularVectors] = svds(tfidfMatrix);
    
    % For demonstration, select the first latent topic (first column of rightSingularVectors).
    topicWeightVector = rightSingularVectors(:,1);
    vocabularyWords = wordBagModel.Vocabulary;
    
    % Sort words by the absolute value of their weight in descending order.
    [~, sortedWordIndices] = sort(abs(topicWeightVector), 'descend');
    topWordsCount = min(20, length(vocabularyWords));
    topTopicWords = vocabularyWords(sortedWordIndices(1:topWordsCount));
    topTopicWeights = topicWeightVector(sortedWordIndices(1:topWordsCount));
    
    % The wordcloud function requires non-negative sizes, so use absolute weights.
    figure;
    wordcloud(topTopicWords, abs(topTopicWeights));
    title(['Latent Semantic Topic for comment_id: ', clickedCommentId]);
    
    % Optionally, print out the top words and their weights to the command window.
    disp('Top words in the extracted topic:');
    for wordIndex = 1:topWordsCount
        fprintf('%s (weight: %.3f)\n', topTopicWords{wordIndex}, topTopicWeights(wordIndex));
    end
end
