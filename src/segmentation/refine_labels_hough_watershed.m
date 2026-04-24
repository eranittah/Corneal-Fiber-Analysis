function labelStackSeeded = refine_labels_hough_watershed(imgStack, labelStack, params)
% refine_labels_hough_watershed
% Uses existing disconnected label mask as candidate regions.
% Within each slice:
%   1. Mask original image
%   2. Detect circular dark fibril cores using imfindcircles
%   3. Use circle centers as watershed seeds
%   4. Watershed only within candidate mask
%
% INPUT
%   imgStack    : original/raw or preprocessed image stack, H x W x Z
%   labelStack  : candidate label stack from segment_fibrils_basic
%   params      : struct with optional fields:
%       .radiusRange
%       .sensitivity
%       .edgeThreshold
%       .seedDiskRadius
%       .distanceSmoothSigma
%       .verbose
%
% OUTPUT
%   labelStackSeeded : refined label stack

%% Defaults

if ~isfield(params, 'radiusRange');         params.radiusRange = [2 6]; end
if ~isfield(params, 'sensitivity');         params.sensitivity = 0.92; end
if ~isfield(params, 'edgeThreshold');       params.edgeThreshold = 0.05; end
if ~isfield(params, 'seedDiskRadius');      params.seedDiskRadius = 1; end
if ~isfield(params, 'distanceSmoothSigma'); params.distanceSmoothSigma = 1; end
if ~isfield(params, 'verbose');             params.verbose = true; end

%% Initialize

[H, W, Z] = size(imgStack);
labelStackSeeded = zeros(H, W, Z, 'uint16');

[X, Y] = meshgrid(1:W, 1:H);

%% Process slice-by-slice

for z = 1:Z

    img = imgStack(:,:,z);
    mask = labelStack(:,:,z) > 0;

    if ~any(mask(:))
        continue;
    end

    % Normalize image
    imgNorm = mat2gray(img);

    % Invert so dark fibril cores become bright circles
    imgInv = imcomplement(imgNorm);

    % Suppress everything outside candidate mask
    imgMasked = imgInv;
    imgMasked(~mask) = 0;

    % Detect circular fibril cores
    [centers, radii] = imfindcircles( ...
        imgMasked, ...
        params.radiusRange, ...
        'ObjectPolarity', 'bright', ...
        'Sensitivity', params.sensitivity, ...
        'EdgeThreshold', params.edgeThreshold);
    warning('off','images:imfindcircles:warnForSmallRadius');

    % Build seed mask from detected centers
    seedMask = false(H, W);

    for i = 1:size(centers,1)
        cx = centers(i,1);
        cy = centers(i,2);

        seed = (X - cx).^2 + (Y - cy).^2 <= params.seedDiskRadius^2;
        seedMask = seedMask | seed;
    end

    % If no seeds are found, keep original candidate mask labels
    if ~any(seedMask(:))
        ccFallback = bwconncomp(mask);
        labelStackSeeded(:,:,z) = uint16(labelmatrix(ccFallback));

        if params.verbose && mod(z,50)==1
            fprintf('Slice %d/%d | no Hough seeds found, using fallback labels\n', z, Z);
        end

        continue;
    end

    % Distance transform within candidate mask
    D = bwdist(~mask);

    if params.distanceSmoothSigma > 0
        D = imgaussfilt(D, params.distanceSmoothSigma);
    end

    % Watershed wants basins, so use negative distance
    Dneg = -D;

    % Prevent watershed outside candidate mask
    Dneg(~mask) = Inf;

    % Impose Hough centroids as minima
    Dimp = imimposemin(Dneg, seedMask);

    % Watershed
    L = watershed(Dimp);

    % Keep only regions inside candidate mask
    L(~mask) = 0;

    % Remove watershed ridge lines from mask
    bwSplit = mask;
    bwSplit(L == 0) = 0;

    % Relabel final split objects
    cc = bwconncomp(bwSplit);
    labelStackSeeded(:,:,z) = uint16(labelmatrix(cc));

    if params.verbose && mod(z,50)==1
        fprintf('Slice %d/%d | seeds: %d | objects: %d\n', ...
            z, Z, size(centers,1), cc.NumObjects);
    end
end

end