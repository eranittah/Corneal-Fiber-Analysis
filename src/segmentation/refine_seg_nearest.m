function [labelStackRefined, neighborCounts] = refine_seg_nearest(labelStack, params)
% refine_seg_nearest
% Removes labels that have fewer than a minimum number of nearest neighbors
% within a cutoff distance, based on object centroids.
%
% INPUT
%   labelStack : H x W x Z labeled stack
%   params     : struct with optional fields:
%       .cutoffDist      distance cutoff in pixels
%       .minNeighbors    minimum number of neighbors required
%       .verbose
%
% OUTPUT
%   labelStackRefined : filtered/relabelled stack
%   neighborCounts    : cell array containing neighbor counts per slice

%% Defaults

if ~isfield(params, 'cutoffDist');   params.cutoffDist = 15; end
if ~isfield(params, 'minNeighbors'); params.minNeighbors = 3; end
if ~isfield(params, 'verbose');      params.verbose = true; end

%% Initialize

[H, W, Z] = size(labelStack);
labelStackRefined = zeros(H, W, Z, 'uint16');
neighborCounts = cell(Z,1);

%% Process slice-by-slice

for z = 1:Z

    L = labelStack(:,:,z);

    stats = regionprops(L, 'Centroid', 'PixelIdxList');

    nObj = numel(stats);

    if nObj == 0
        neighborCounts{z} = [];
        continue;
    end

    centroids = vertcat(stats.Centroid);

    % Pairwise centroid distances
    D = pdist2(centroids, centroids);

    % Ignore self-distance
    D(1:nObj+1:end) = Inf;

    % Count neighbors within cutoff
    nNeighbors = sum(D <= params.cutoffDist, 2);

    neighborCounts{z} = nNeighbors;

    % Keep only sufficiently surrounded objects
    keep = nNeighbors >= params.minNeighbors;

    bwKeep = false(H, W);

    for i = find(keep)'
        bwKeep(stats(i).PixelIdxList) = true;
    end

    % Relabel after filtering
    cc = bwconncomp(bwKeep);
    labelStackRefined(:,:,z) = uint16(labelmatrix(cc));

    if params.verbose && mod(z,50)==1
        fprintf('Slice %d/%d | objects: %d -> %d\n', ...
            z, Z, nObj, cc.NumObjects);
    end
end

end