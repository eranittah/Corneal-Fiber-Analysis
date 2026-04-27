function tracksOut = trackLabelStackKalmanLAP(labelStack, varargin)
%TRACKLABELSTACKKALMANLAP Fast centroid tracking using Kalman filters + LAP.
%
% tracksOut = trackLabelStackKalmanLAP(labelStack)
%
% Uses:
%   regionprops  -> detections
%   trackingKF   -> one Kalman filter per active track
%   matchpairs   -> LAP assignment
%
% Output:
%   tracksOut(i).id
%   tracksOut(i).xyz
%   tracksOut(i).sliceIdx
%   tracksOut(i).stateHistory

% ----------------------------
% Parse inputs
% ----------------------------
p = inputParser;
p.addRequired('labelStack', @(x) isnumeric(x) || islogical(x));
p.addParameter('MaxDist', 8, @isnumeric);
p.addParameter('MaxMissed', 2, @isnumeric);
p.addParameter('MinTrackLength', 5, @isnumeric);
p.addParameter('MeasurementNoise', 1, @isnumeric);
p.addParameter('ProcessNoise', 0.5, @isnumeric);
p.addParameter('Verbose', true, @islogical);
p.parse(labelStack, varargin{:});

maxDist = p.Results.MaxDist;
maxMissed = p.Results.MaxMissed;
minTrackLength = p.Results.MinTrackLength;
measurementNoiseVal = p.Results.MeasurementNoise;
processNoiseVal = p.Results.ProcessNoise;
verbose = p.Results.Verbose;

[~, ~, numSlices] = size(labelStack);

% ----------------------------
% Track storage
% ----------------------------
tracks = struct( ...
    'id', {}, ...
    'kf', {}, ...
    'xyz', {}, ...
    'sliceIdx', {}, ...
    'stateHistory', {}, ...
    'missed', {}, ...
    'active', {});

nextID = 1;

totalTimer = tic;

% ----------------------------
% Main tracking loop
% ----------------------------
for z = 1:numSlices

    sliceTimer = tic;

    % Get detections from current slice
    detXY = getCentroidsFromLabelSlice(labelStack(:,:,z));

    % Find active tracks
    activeIdx = find([tracks.active]);

    % ------------------------------------------------------------
    % Initialize from first non-empty slice
    % ------------------------------------------------------------
    if isempty(activeIdx)
        for d = 1:size(detXY,1)
            tracks(end+1) = createNewTrack( ...
                nextID, detXY(d,:), z, measurementNoiseVal, processNoiseVal); %#ok<AGROW>
            nextID = nextID + 1;
        end

        if verbose
            fprintf('Slice %d / %d | Detections: %d | Active tracks: %d | Time: %.3f s\n', ...
                z, numSlices, size(detXY,1), numel(find([tracks.active])), toc(sliceTimer));
        end

        continue;
    end

    % ------------------------------------------------------------
    % Predict all active tracks
    % ------------------------------------------------------------
    predXY = nan(numel(activeIdx), 2);

    for i = 1:numel(activeIdx)
        t = activeIdx(i);
        predictedState = predict(tracks(t).kf);

        % State format: [x; vx; y; vy]
        predXY(i,:) = [predictedState(1), predictedState(3)];
    end

    % ------------------------------------------------------------
    % Assign detections to predicted track positions using LAP
    % ------------------------------------------------------------
    assignments = zeros(0,2);

    if ~isempty(detXY) && ~isempty(predXY)
        costMatrix = pdist2(predXY, detXY);

        % Gate impossible links
        costMatrix(costMatrix > maxDist) = Inf;

        % LAP assignment
        assignments = matchpairs(costMatrix, maxDist);
    end

    % ------------------------------------------------------------
    % Update matched tracks
    % ------------------------------------------------------------
    matchedTrackRows = assignments(:,1);
    matchedDetRows = assignments(:,2);

    for k = 1:size(assignments,1)
        trackRow = assignments(k,1);
        detRow = assignments(k,2);

        t = activeIdx(trackRow);
        xy = detXY(detRow,:);

        correctedState = correct(tracks(t).kf, xy(:));

        tracks(t).xyz(end+1,:) = [xy, z];
        tracks(t).sliceIdx(end+1,1) = z;
        tracks(t).stateHistory(end+1,:) = correctedState(:)';
        tracks(t).missed = 0;
    end

    % ------------------------------------------------------------
    % Handle unmatched active tracks
    % ------------------------------------------------------------
    unmatchedTrackRows = setdiff(1:numel(activeIdx), matchedTrackRows);

    for r = unmatchedTrackRows
        t = activeIdx(r);

        tracks(t).missed = tracks(t).missed + 1;

        % Store predicted position during missed frame
        state = tracks(t).kf.State;
        tracks(t).xyz(end+1,:) = [state(1), state(3), z];
        tracks(t).sliceIdx(end+1,1) = z;
        tracks(t).stateHistory(end+1,:) = state(:)';

        if tracks(t).missed > maxMissed
            tracks(t).active = false;
        end
    end

    % ------------------------------------------------------------
    % Start new tracks from unmatched detections
    % ------------------------------------------------------------
    unmatchedDetRows = setdiff(1:size(detXY,1), matchedDetRows);

    for d = unmatchedDetRows
        tracks(end+1) = createNewTrack( ...
            nextID, detXY(d,:), z, measurementNoiseVal, processNoiseVal); %#ok<AGROW>
        nextID = nextID + 1;
    end

    if verbose
        fprintf('Slice %d / %d | Detections: %d | Active tracks: %d | Assignments: %d | Time: %.3f s\n', ...
            z, numSlices, size(detXY,1), numel(find([tracks.active])), size(assignments,1), toc(sliceTimer));
    end
end

% ----------------------------
% Export only useful fields
% ----------------------------
tracksOut = struct('id', {}, 'xyz', {}, 'sliceIdx', {}, 'stateHistory', {});

for i = 1:numel(tracks)
    if size(tracks(i).xyz,1) >= minTrackLength
        tracksOut(end+1).id = tracks(i).id; %#ok<AGROW>
        tracksOut(end).xyz = tracks(i).xyz;
        tracksOut(end).sliceIdx = tracks(i).sliceIdx;
        tracksOut(end).stateHistory = tracks(i).stateHistory;
    end
end

if verbose
    fprintf('TOTAL KALMAN-LAP TRACKING TIME: %.2f seconds\n', toc(totalTimer));
    fprintf('Returned %d tracks with length >= %d slices.\n', numel(tracksOut), minTrackLength);
end

end

% ========================================================================
% Helper: extract centroids from label slice
% ========================================================================
function detXY = getCentroidsFromLabelSlice(labelSlice)

stats = regionprops(labelSlice, 'Centroid');

if isempty(stats)
    detXY = zeros(0,2);
    return;
end

detXY = vertcat(stats.Centroid);

end

% ========================================================================
% Helper: create one new Kalman-filtered track
% ========================================================================
function tr = createNewTrack(id, xy, z, measurementNoiseVal, processNoiseVal)

kf = initCentroidKalmanFilter(xy, measurementNoiseVal, processNoiseVal);

state = kf.State;

tr.id = id;
tr.kf = kf;
tr.xyz = [xy, z];
tr.sliceIdx = z;
tr.stateHistory = state(:)';
tr.missed = 0;
tr.active = true;

end

% ========================================================================
% Helper: initialize constant-velocity Kalman filter
% ========================================================================
function kf = initCentroidKalmanFilter(xy, measurementNoiseVal, processNoiseVal)

% State format:
%   [x; vx; y; vy]
initialState = [xy(1); 0; xy(2); 0];

dt = 1;

F = [1 dt 0  0;
     0 1  0  0;
     0 0  1 dt;
     0 0  0 1];

H = [1 0 0 0;
     0 0 1 0];

initialStateCovariance = diag([4, 10, 4, 10]);

processNoise = processNoiseVal * diag([1, 2, 1, 2]);

measurementNoise = measurementNoiseVal * eye(2);

kf = trackingKF( ...
    'MotionModel', 'Custom', ...
    'State', initialState, ...
    'StateCovariance', initialStateCovariance, ...
    'StateTransitionModel', F, ...
    'MeasurementModel', H, ...
    'ProcessNoise', processNoise, ...
    'MeasurementNoise', measurementNoise);

end