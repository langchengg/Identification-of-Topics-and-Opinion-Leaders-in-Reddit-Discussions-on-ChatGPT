clc; 
clear;
close all;

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
% An edge goes from a comment (child) to its parent.
childCommentIds = commentIds;
parentNodeIds = parentCommentIds;

% Create a directed graph representing comment thread structure (omitting self loops)
commentThreadGraph = digraph(childCommentIds, parentNodeIds, [], uniqueNodeIds, 'OmitSelfLoops');

%% Compute Centrality Measures
% PageRank: finds nodes with high influence based on link structure.
pageRankScores = centrality(commentThreadGraph, 'pagerank');

% Hubs and Authorities: based on the HITS algorithm.
hubScores = centrality(commentThreadGraph, 'hubs');
authorityScores = centrality(commentThreadGraph, 'authorities');

% Closeness: outcloseness and incloseness measures.
outClosenessScores = centrality(commentThreadGraph, 'outcloseness');
inClosenessScores = centrality(commentThreadGraph, 'incloseness');

% Store these measures in the Nodes table for later use.
commentThreadGraph.Nodes.PageRank = pageRankScores;
commentThreadGraph.Nodes.Hubs = hubScores;
commentThreadGraph.Nodes.Authorities = authorityScores;
commentThreadGraph.Nodes.OutCloseness = outClosenessScores;
commentThreadGraph.Nodes.InCloseness = inClosenessScores;

%% Display Top Users Based on PageRank
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

%% Visualization of the Graph and Top Users

% Plot the entire graph using a force-directed layout.
figure;
graphPlot = plot(commentThreadGraph, 'Layout', 'force');
title('Comment Thread Graph (Centrality Analysis)');
axis off;

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

%% Bar Chart of Top Users Based on PageRank
figure;
bar(topUserPageRankScores);
% To improve readability when topUserCount is large, show only every label.
xAxisTickIndices = 1:topUserCount;
set(gca, 'XTick', xAxisTickIndices, 'XTickLabel', topUserIds(xAxisTickIndices), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('PageRank Score');
title('Top 5 Users Based on PageRank');
grid on;

%% (Optional) Visualization for Hubs, Authorities, Closeness

% Top Hubs
[sortedHubScores, sortedHubIndices] = sort(hubScores, 'descend');
topHubUserIds = commentThreadGraph.Nodes.Name(sortedHubIndices(1:topUserCount));
topHubValues = sortedHubScores(1:topUserCount);
figure;
bar(topHubValues);
xAxisTickIndices = 1:topUserCount;
set(gca, 'XTick', xAxisTickIndices, 'XTickLabel', topHubUserIds(xAxisTickIndices), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('Hub Score');
title('Top 5 Users Based on Hubs Centrality');
grid on;

% Top Authorities
[sortedAuthorityScores, sortedAuthorityIndices] = sort(authorityScores, 'descend');
topAuthorityUserIds = commentThreadGraph.Nodes.Name(sortedAuthorityIndices(1:topUserCount));
topAuthorityValues = sortedAuthorityScores(1:topUserCount);
figure;
bar(topAuthorityValues);
xAxisTickIndices = 1:topUserCount;
set(gca, 'XTick', xAxisTickIndices, 'XTickLabel', topAuthorityUserIds(xAxisTickIndices), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('Authorities Score');
title('Top 5 Users Based on Authorities Centrality');
grid on;

% Top Out Closeness
[sortedOutClosenessScores, sortedOutClosenessIndices] = sort(outClosenessScores, 'descend');
topOutClosenessUserIds = commentThreadGraph.Nodes.Name(sortedOutClosenessIndices(1:topUserCount));
topOutClosenessValues = sortedOutClosenessScores(1:topUserCount);
figure;
bar(topOutClosenessValues);
xAxisTickIndices = 1:topUserCount;
set(gca, 'XTick', xAxisTickIndices, 'XTickLabel', topOutClosenessUserIds(xAxisTickIndices), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('Out Closeness Score');
title('Top 5 Users Based on Out Closeness');
grid on;

% Top In Closeness
[sortedInClosenessScores, sortedInClosenessIndices] = sort(inClosenessScores, 'descend');
topInClosenessUserIds = commentThreadGraph.Nodes.Name(sortedInClosenessIndices(1:topUserCount));
topInClosenessValues = sortedInClosenessScores(1:topUserCount);
figure;
bar(topInClosenessValues);
xAxisTickIndices = 1:topUserCount;
set(gca, 'XTick', xAxisTickIndices, 'XTickLabel', topInClosenessUserIds(xAxisTickIndices), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('In Closeness Score');
title('Top 5 Users Based on In Closeness');
grid on;
