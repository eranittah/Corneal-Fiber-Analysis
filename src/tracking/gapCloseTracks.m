function tracksOut = gapCloseTracks(tracksIn, varargin)
%GAPCLOSETRACKS Merge fragmented tracks across short missing-slice gaps.

p = inputParser;
p.addRequired('tracksIn', @isstruct);
p.addParameter('MaxGap', 5, @isnumeric);
p.addParameter('MaxDistPerSlice', 3, @isnumeric);
p.addParameter('MinTrackLength', 5, @isnumeric);
p.addParameter('Verbose', true, @islogical);
p.parse(tracksIn, varargin{:});

maxGap = p.Results.MaxGap;
maxDistPerSlice = p.Results.MaxDistPerSlice;
minTrackLength = p.Results.MinTrackLength;
verbose = p.Results.Verbose;

if isempty(tracksIn)
    tracksOut = tracksIn;
    return;
end

n = numel(tracksIn);

startZ = zeros(n,1);
endZ   = zeros(n,1);
startXY = zeros(n,2);
endXY   = zeros(n,2);

for i = 1:n
    xyz = tracksIn(i).xyz;
    [~, ord] = sort(xyz(:,3));
    xyz = xyz(ord,:);

    tracksIn(i).xyz = xyz;
    tracksIn(i).sliceIdx = xyz(:,3);

    startZ(i) = xyz(1,3);
    endZ(i) = xyz(end,3);
    startXY(i,:) = xyz(1,1:2);
    endXY(i,:) = xyz(end,1:2);
end

% Cost matrix: row = ending track, col = starting track
cost = inf(n,n);

for i = 1:n
    for j = 1:n
        if i == j
            continue;
        end

        gap = startZ(j) - endZ(i);

        if gap <= 0 || gap > maxGap
            continue;
        end

        distXY = norm(startXY(j,:) - endXY(i,:));
        allowedDist = maxDistPerSlice * gap;

        if distXY <= allowedDist
            cost(i,j) = distXY;
        end
    end
end

assignments = matchpairs(cost, maxDistPerSlice * maxGap);

% Explicit link maps
nextTrack = zeros(n,1);
prevTrack = zeros(n,1);

for k = 1:size(assignments,1)
    a = assignments(k,1); % track ending first
    b = assignments(k,2); % track starting later

    if a >= 1 && a <= n && b >= 1 && b <= n
        nextTrack(a) = b;
        prevTrack(b) = a;
    end
end

tracksOut = struct('id', {}, 'xyz', {}, 'sliceIdx', {}, 'stateHistory', {});
used = false(n,1);
newID = 1;

% Start chains only at tracks with no previous parent
chainStarts = find(prevTrack == 0);

for s = reshape(chainStarts,1,[])
    if used(s)
        continue;
    end

    chain = [];
    current = s;

    while current ~= 0
        if current < 1 || current > n
            break;
        end

        if used(current)
            break;
        end

        chain(end+1) = current; %#ok<AGROW>
        used(current) = true;

        current = nextTrack(current);
    end

    mergedXYZ = [];
    mergedState = [];

    for idx = 1:numel(chain)
        c = chain(idx);

        mergedXYZ = [mergedXYZ; tracksIn(c).xyz]; %#ok<AGROW>

        if isfield(tracksIn, 'stateHistory') && ~isempty(tracksIn(c).stateHistory)
            mergedState = [mergedState; tracksIn(c).stateHistory]; %#ok<AGROW>
        end
    end

    [~, ord] = sort(mergedXYZ(:,3));
    mergedXYZ = mergedXYZ(ord,:);

    if size(mergedXYZ,1) >= minTrackLength
        tracksOut(end+1).id = newID; %#ok<AGROW>
        tracksOut(end).xyz = mergedXYZ;
        tracksOut(end).sliceIdx = mergedXYZ(:,3);

        if ~isempty(mergedState) && size(mergedState,1) == size(mergedXYZ,1)
            tracksOut(end).stateHistory = mergedState(ord,:);
        else
            tracksOut(end).stateHistory = [];
        end

        newID = newID + 1;
    end
end

% Add any remaining unused tracks
for i = 1:n
    if used(i)
        continue;
    end

    xyz = tracksIn(i).xyz;

    if size(xyz,1) >= minTrackLength
        tracksOut(end+1).id = newID; %#ok<AGROW>
        tracksOut(end).xyz = xyz;
        tracksOut(end).sliceIdx = xyz(:,3);

        if isfield(tracksIn, 'stateHistory')
            tracksOut(end).stateHistory = tracksIn(i).stateHistory;
        else
            tracksOut(end).stateHistory = [];
        end

        newID = newID + 1;
    end
end

if verbose
    fprintf('Gap closing: %d input tracks -> %d output tracks. Merged %d links.\n', ...
        n, numel(tracksOut), size(assignments,1));
end

end