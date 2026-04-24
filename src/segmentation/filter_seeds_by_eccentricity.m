function seedMaskFiltered = filter_seeds_by_eccentricity(imgSeed, seedMask, params)
% filter_seeds_by_eccentricity
% Removes ridge-like seeds by checking local patch eccentricity around each seed.

if ~isfield(params, 'seedPatchRadius');       params.seedPatchRadius = 5; end
if ~isfield(params, 'maxSeedEccentricity');   params.maxSeedEccentricity = 0.85; end
if ~isfield(params, 'localThresholdFactor');  params.localThresholdFactor = 0.5; end

[H, W] = size(imgSeed);
seedMaskFiltered = false(H, W);

[ySeed, xSeed] = find(seedMask);

for i = 1:numel(xSeed)

    x = xSeed(i);
    y = ySeed(i);

    r = params.seedPatchRadius;

    x1 = max(1, x-r);
    x2 = min(W, x+r);
    y1 = max(1, y-r);
    y2 = min(H, y+r);

    patch = imgSeed(y1:y2, x1:x2);

    if max(patch(:)) == 0
        continue;
    end

    % Threshold local bright LoG response around seed
    bwPatch = patch > params.localThresholdFactor * max(patch(:));

    % Keep only the connected component containing the seed
    seedXLocal = x - x1 + 1;
    seedYLocal = y - y1 + 1;

    cc = bwconncomp(bwPatch);

    keepThisSeed = false;

    for k = 1:cc.NumObjects
        if any(cc.PixelIdxList{k} == sub2ind(size(bwPatch), seedYLocal, seedXLocal))

            stats = regionprops(cc, 'Eccentricity');

            if stats(k).Eccentricity <= params.maxSeedEccentricity
                keepThisSeed = true;
            end

            break;
        end
    end

    if keepThisSeed
        seedMaskFiltered(y,x) = true;
    end
end

end