clc; 
clear;
close all;

%% Read Data and Construct Graph
% Read the CSV file (update the filename as needed)
filename = 'updated_chatgpt_reddit_comments.csv';
data = readtable(filename);

% Extract comment_id and comment_parent_id from the data table.
comment_ids = data.comment_id;
parent_ids  = data.comment_parent_id;

% Collect all unique node names.
all_nodes = unique([comment_ids; parent_ids]);

% Create a list of edges (source, target).
% An edge goes from a comment (child) to its parent.
sources = comment_ids;
targets = parent_ids;

% Create a directed graph (omitting self loops)
G = digraph(sources, targets, [], all_nodes, 'OmitSelfLoops');

%% Compute Centrality Measures
% PageRank: finds nodes with high influence based on link structure.
pr_scores = centrality(G, 'pagerank');

% Hubs and Authorities: based on the HITS algorithm.
hub_ranks  = centrality(G, 'hubs');
auth_ranks = centrality(G, 'authorities');

% Closeness: outcloseness and incloseness measures.
out_close = centrality(G, 'outcloseness');
in_close  = centrality(G, 'incloseness');

% Store these measures in the Nodes table for later use.
G.Nodes.PageRank = pr_scores;
G.Nodes.Hubs = hub_ranks;
G.Nodes.Authorities = auth_ranks;
G.Nodes.OutCloseness = out_close;
G.Nodes.InCloseness = in_close;

%% Display Top Users Based on PageRank
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

%% Visualization of the Graph and Top Users

% Plot the entire graph using a force-directed layout.
figure;
p = plot(G, 'Layout', 'force');
title('Comment Thread Graph (Centrality Analysis)');
axis off;

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

%% Bar Chart of Top Users Based on PageRank
figure;
bar(topPR);
% To improve readability when N is large, show only every label.
xtickIdx = 1:N;
set(gca, 'XTick', xtickIdx, 'XTickLabel', topUsers(xtickIdx), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('PageRank Score');
title('Top 5 Users Based on PageRank');
grid on;

%% (Optional) Visualization for Hubs, Authorities, Closeness

% Top Hubs
[sortedHubs, idxHubs] = sort(hub_ranks, 'descend');
topHubs = G.Nodes.Name(idxHubs(1:N));
topHubsScores = sortedHubs(1:N);
figure;
bar(topHubsScores);
xtickIdx = 1:N;
set(gca, 'XTick', xtickIdx, 'XTickLabel', topHubs(xtickIdx), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('Hub Score');
title('Top 5 Users Based on Hubs Centrality');
grid on;

% Top Authorities
[sortedAuth, idxAuth] = sort(auth_ranks, 'descend');
topAuth = G.Nodes.Name(idxAuth(1:N));
topAuthScores = sortedAuth(1:N);
figure;
bar(topAuthScores);
xtickIdx = 1:N;
set(gca, 'XTick', xtickIdx, 'XTickLabel', topAuth(xtickIdx), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('Authorities Score');
title('Top 5 Users Based on Authorities Centrality');
grid on;

% Top Out Closeness
[sortedOut, idxOut] = sort(out_close, 'descend');
topOut = G.Nodes.Name(idxOut(1:N));
topOutScores = sortedOut(1:N);
figure;
bar(topOutScores);
xtickIdx = 1:N;
set(gca, 'XTick', xtickIdx, 'XTickLabel', topOut(xtickIdx), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('Out Closeness Score');
title('Top 5 Users Based on Out Closeness');
grid on;

% Top In Closeness
[sortedIn, idxIn] = sort(in_close, 'descend');
topIn = G.Nodes.Name(idxIn(1:N));
topInScores = sortedIn(1:N);
figure;
bar(topInScores);
xtickIdx = 1:N;
set(gca, 'XTick', xtickIdx, 'XTickLabel', topIn(xtickIdx), 'XTickLabelRotation', 45);
xlabel('User ID');
ylabel('In Closeness Score');
title('Top 5 Users Based on In Closeness');
grid on;
