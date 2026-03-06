clc;
clear;
close all

%% Read Data and Construct Graph
% Read the CSV file (update the filename as needed)
filename = 'updated_chatgpt_reddit_comments.csv';
data = readtable(filename);

% Extract comment_id and comment_parent_id from the data table.
comment_ids  = data.comment_id;
parent_ids   = data.comment_parent_id;

% Collect all unique node names.
all_nodes = unique([comment_ids; parent_ids]);

% Create a list of edges (source, target).
% Here, an edge goes from a comment (child) to its parent.
sources = comment_ids;
targets = parent_ids;

% Create a directed graph (omitting self loops)
G = digraph(sources, targets, [], all_nodes, 'OmitSelfLoops');

% Plot the graph using a force-directed layout.
figure;
p = plot(G, 'Layout', 'force');
title('Comment Thread Graph');
axis off;

% Adjust figure size if needed.
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0, 0.04, 1, 0.96]);

% Store the graph and data table in the figure's UserData for callback access.
set(gcf, 'UserData', struct('G', G, 'data', data, 'plotHandle', p));
%% Display Top Users Based on PageRank

% PageRank: finds nodes with high influence based on link structure.
pr_scores = centrality(G, 'pagerank');
% Store these measures in the Nodes table for later use.
G.Nodes.PageRank = pr_scores;
% Sort nodes by PageRank in descending order.
[sortedPR, idxPR] = sort(pr_scores, 'descend');

% Set N ensuring it does not exceed the total number of nodes.
N = 5;
if N > numel(G.Nodes.Name)
    N = numel(G.Nodes.Name);
end

topUsers = G.Nodes.Name(idxPR(1:N));
topPR = sortedPR(1:N);

disp('Top users based on PageRank:');
for i = 1:N
    fprintf('%d. User: %s | PageRank Score: %.5f\n', i, topUsers{i}, topPR(i));
end

% Highlight top users (by PageRank) in red.
highlight(p, topUsers, 'NodeColor', 'r', 'MarkerSize', 7);
% Annotate top users with their rank number.
% Note: When many nodes are highlighted, overlapping text may occur.
% Use findnode for efficient node index lookup instead of find+strcmp
nodeIdxs = findnode(G, topUsers);
for i = 1:N
    nodeIdx = nodeIdxs(i);
    % Only annotate if the node coordinates exist (to avoid errors).
    if nodeIdx > 0
        text(p.XData(nodeIdx), p.YData(nodeIdx), num2str(i), ...
            'FontSize', 8, 'Color', 'k', 'FontWeight', 'bold');
    end
end
%% Attach Node Click Callback
% The ButtonDownFcn is set on the overall plot.
% When a click occurs, the callback will identify the nearest node based on the node coordinates.
set(p, 'ButtonDownFcn', @onNodeClick);

%% Callback Function for Mouse Click on Graph Nodes
function onNodeClick(~, event)
    % Retrieve the stored graph, data, and plot handle from the figure.
    figData = get(gcf, 'UserData');
    G       = figData.G;
    data    = figData.data;
    p       = figData.plotHandle;
    
    % --- Determine the clicked node ---
    % Use the click location to find the nearest node marker.
    clickPoint = event.IntersectionPoint(1:2);
    distances = sqrt((p.XData - clickPoint(1)).^2 + (p.YData - clickPoint(2)).^2);
    [minDist, idx] = min(distances);
    
    % (Optional) Define a threshold; if the click is too far from any node, exit.
    threshold = 0.05;
    if minDist > threshold
        disp('Click was not close enough to any node.');
        return;
    end
    
    % Identify the clicked node by its comment_id.
    clickedNodeID = G.Nodes.Name{idx};
    disp(['Clicked comment_id: ', clickedNodeID]);
    
    % Retrieve the corresponding serial_number from the data table.
    rowIdx = strcmp(string(data.comment_id), string(clickedNodeID));
    if any(rowIdx)
        disp(['Serial number for clicked comment: ', num2str(data.serial_number(rowIdx))]);
    else
        disp('Clicked comment_id not found in data table.');
    end
    
    % --- Find descendant nodes based on the graph structure ---
    % Since edges in G point from child to parent, reverse the edge directions
    % to get the "children" and further descendants.
    G_rev = flipedge(G);
    descendantNodes = bfsearch(G_rev, clickedNodeID);
    % Exclude the clicked node itself.
    descendantNodes(strcmp(descendantNodes, clickedNodeID)) = [];
    disp('Connected comment_ids (descendants) under this node:');
    disp(descendantNodes);
    
    % --- Filter data and display comment details ---
    % Filter the data table to include rows for the clicked comment and its descendants.
    allIDs = [clickedNodeID; descendantNodes];
    idxRows = ismember(string(data.comment_id), string(allIDs));
    subData = data(idxRows, :);
    
    % Display how many comments (documents) are used for the topic analysis.
    fprintf('Performing topic analysis on %d comments...\n', height(subData));
    
    % Build a multi-line string with comment details.
    detailsStr = '';
    for i = 1:height(subData)
        detailsStr = sprintf('%scomment_id: %s | serial_number: %s\nComment: %s\n\n', ...
            detailsStr, string(subData.comment_id(i)), string(subData.serial_number(i)), string(subData.comment_body{i}));
    end
    
    % Display the comment details in a new figure with a scrollable text box.
    detailsFig = figure('Name', 'Comment Details', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
    % Create an editable uicontrol that allows scrolling.
    uicontrol('Parent', detailsFig, 'Style', 'edit', 'Max', 2, 'Min', 0, ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.05 0.05 0.9 0.9], ...
        'String', detailsStr, 'FontSize', 8);
    
    % --- Clean and tokenize the comment text ---
    % Convert comment_body to lowercase, remove punctuation, and remove stop words.
    docs = tokenizedDocument(lower(subData.comment_body));
    docs = erasePunctuation(docs);
    docs = removeStopWords(docs);
    
    % --- Build the TF-IDF matrix ---
    % Create a bag-of-words model.
    bag = bagOfWords(docs);
    % Compute the TF-IDF matrix as a sparse matrix.
    tfidfMat = tfidf(bag);
    
    % --- Latent Semantic Analysis (LSA) and Word Cloud ---
    % Use singular value decomposition (SVD) to extract latent topics.
    [~, ~, V] = svds(tfidfMat);
    
    % For demonstration, select the first latent topic (first column of V).
    topicWeights = V(:,1);
    words = bag.Vocabulary;
    
    % Sort words by the absolute value of their weight in descending order.
    [~, sortIdx] = sort(abs(topicWeights), 'descend');
    topN = min(20, length(words));
    topWords = words(sortIdx(1:topN));
    topWeights = topicWeights(sortIdx(1:topN));
    
    % The wordcloud function requires non-negative sizes, so use absolute weights.
    figure;
    wordcloud(topWords, abs(topWeights));
    title(['Latent Semantic Topic for comment_id: ', clickedNodeID]);
    
    % Optionally, print out the top words and their weights to the command window.
    disp('Top words in the extracted topic:');
    for i = 1:topN
        fprintf('%s (weight: %.3f)\n', topWords{i}, topWeights(i));
    end
end
