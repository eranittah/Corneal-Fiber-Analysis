function labelStackSeeded = refine_labels_logmax_watershed(imgStack, labelStack, params)
% refine_labels_logmax_watershed
% Uses LoG regional maxima as watershed seeds inside an existing candidate mask.

%% Defaults
if ~isfield(params, 'logSize');             params.logSize = 9; end
if ~isfield(params, 'logSigma');            params.logSigma = 1.5; end
if ~isfield(params, 'seedThresholdFactor'); params.seedThresholdFactor = 0.35; end
if ~isfield(params, 'seedDilateRadius');    params.seedDilateRadius = 1; end
if ~isfield(params, 'distanceSmoothSigma'); params.distanceSmoothSigma = 1; end
if ~isfield(params, 'verbose');             params.verbose = true; end

%% Initialize
[H, W, Z] = size(imgStack);
labelStackSeeded = zeros(H, W, Z, 'uint16');

h = fspecial('log', params.logSize, params.logSigma);

%% Process slice-by-slice
for z = 1:Z

    img = imgStack(:,:,z);
    mask = labelStack(:,:,z) > 0;

    if ~any(mask(:))
        continue;
    end

    % Invert image so dark fibril cores are bright
    imgInv = imcomplement(mat2gray(img));

    % LoG blob response
    imgLoG = -imfilter(imgInv, h, 'replicate');
    imgLoG = mat2gray(imgLoG);

    % Restrict seed detection to candidate mask
    imgSeed = imgLoG;
    imgSeed(~mask) = 0;

    % Regional maxima inside candidate mask
    seedMask = imregionalmax(imgSeed);

    % Suppress weak maxima
    localMaxVal = max(imgSeed(mask), [], 'all');
    seedMask = seedMask & imgSeed > params.seedThresholdFactor * localMaxVal;

    % Optional tiny dilation so seeds are easier for imimposemin
    if params.seedDilateRadius > 0
        seedMask = imdilate(seedMask, strel('disk', params.seedDilateRadius));
        seedMask = seedMask & mask;
    end

    % Fallback if no seeds found
    if ~any(seedMask(:))
        ccFallback = bwconncomp(mask);
        labelStackSeeded(:,:,z) = uint16(labelmatrix(ccFallback));
        continue;
    end

    % Distance transform of candidate mask
    D = bwdist(~mask);

    if params.distanceSmoothSigma > 0
        D = imgaussfilt(D, params.distanceSmoothSigma);
    end

    % Watershed from imposed seed minima
    Dneg = -D;
    Dneg(~mask) = Inf;

    Dimp = imimposemin(Dneg, seedMask);
    L = watershed(Dimp);

    % Apply watershed split inside mask
    bwSplit = mask;
    bwSplit(L == 0) = 0;

    cc = bwconncomp(bwSplit);
    labelStackSeeded(:,:,z) = uint16(labelmatrix(cc));

    if params.verbose && mod(z,50)==1
        fprintf('Slice %d/%d | LoG seeds: %d | objects: %d\n', ...
            z, Z, bwconncomp(seedMask).NumObjects, cc.NumObjects);
    end
end

end