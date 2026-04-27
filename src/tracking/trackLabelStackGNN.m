function tracksOut = trackLabelStackGNN(labelStack, varargin)
%TRACKLABELSTACKGNN Track labeled objects through z using MATLAB trackerGNN.
%
% tracksOut = trackLabelStackGNN(labelStack)
% tracksOut = trackLabelStackGNN(labelStack, 'AssignmentThreshold', 30, ...)
%
% Input
%   labelStack : H x W x Z label matrix
%
% Output
%   tracksOut : struct array with fields:
%       id
%       xyz
%       sliceIdx
%       stateHistory

% ----------------------------
% Parse inputs
% ----------------------------
p = inputParser;
p.addRequired('labelStack', @(x) isnumeric(x) || islogical(x));
p.addParameter('AssignmentThreshold', 30, @isnumeric);
p.addParameter('ConfirmationThreshold', [3 5], @isnumeric);
p.addParameter('DeletionThreshold', [5 5], @isnumeric);
p.addParameter('MinTrackLength', 5, @isnumeric);
p.parse(labelStack, varargin{:});

assignmentThreshold = p.Results.AssignmentThreshold;
confirmationThreshold = p.Results.ConfirmationThreshold;
deletionThreshold = p.Results.DeletionThreshold;
minTrackLength = p.Results.MinTrackLength;

[~, ~, numSlices] = size(labelStack);

% ----------------------------
% Create GNN tracker
% ----------------------------
tracker = trackerGNN( ...
    'FilterInitializationFcn', @initFibrilFilter, ...
    'AssignmentThreshold', assignmentThreshold, ...
    'ConfirmationThreshold', confirmationThreshold, ...
    'DeletionThreshold', deletionThreshold);

% Temporary history map
trackHist = containers.Map('KeyType', 'double', 'ValueType', 'any');

% ----------------------------
% Run tracker slice by slice
% ----------------------------
for z = 1:numSlices

    detections = makeDetectionsFromLabelSlice(labelStack(:,:,z), z);

    time = z;

    confirmedTracks = tracker(detections, time);

    for k = 1:numel(confirmedTracks)
        tr = confirmedTracks(k);

        id = tr.TrackID;
        state = tr.State;

        % State is expected to be [x; vx; y; vy]
        x = state(1);
        y = state(3);

        row = struct();
        row.xyz = [x, y, z];
        row.sliceIdx = z;
        row.state = state(:)';

        if isKey(trackHist, id)
            old = trackHist(id);
            old.xyz(end+1,:) = row.xyz;
            old.sliceIdx(end+1,1) = z;
            old.stateHistory(end+1,:) = row.state;
            trackHist(id) = old;
        else
            newTrack.id = id;
            newTrack.xyz = row.xyz;
            newTrack.sliceIdx = z;
            newTrack.stateHistory = row.state;
            trackHist(id) = newTrack;
        end
    end
end

% ----------------------------
% Convert map to struct array
% ----------------------------
ids = cell2mat(keys(trackHist));
tracksOut = struct('id', {}, 'xyz', {}, 'sliceIdx', {}, 'stateHistory', {});

for i = 1:numel(ids)
    tr = trackHist(ids(i));

    if size(tr.xyz,1) >= minTrackLength
        tracksOut(end+1) = tr; %#ok<AGROW>
    end
end

end

% ========================================================================
% Helper: convert one label slice into objectDetection array
% ========================================================================
function detections = makeDetectionsFromLabelSlice(labelSlice, z)

stats = regionprops(labelSlice, 'Centroid', 'Area', 'EquivDiameter');

detections = objectDetection.empty;

for i = 1:numel(stats)
    c = stats(i).Centroid;

    measurement = [c(1); c(2)];

    attr.Area = stats(i).Area;
    attr.EquivDiameter = stats(i).EquivDiameter;
    attr.Slice = z;

    detections(end+1) = objectDetection(z, measurement, ...
        'MeasurementNoise', eye(2), ...
        'ObjectAttributes', attr); %#ok<AGROW>
end

end

% ========================================================================
% Helper: initialize Kalman filter for fibril centroid tracking
% ========================================================================
function filter = initFibrilFilter(detection)

% Measurement is [x; y]
measurement = detection.Measurement;

% State format:
% [x; vx; y; vy]
initialState = [measurement(1); 0; measurement(2); 0];

% Constant velocity model
dt = 1;

F = [1 dt 0  0;
     0 1  0  0;
     0 0  1 dt;
     0 0  0 1];

H = [1 0 0 0;
     0 0 1 0];

initialStateCovariance = diag([4, 10, 4, 10]);

processNoise = diag([1, 2, 1, 2]);

measurementNoise = detection.MeasurementNoise;

filter = trackingKF( ...
    'MotionModel', 'Custom', ...
    'State', initialState, ...
    'StateCovariance', initialStateCovariance, ...
    'StateTransitionModel', F, ...
    'MeasurementModel', H, ...
    'ProcessNoise', processNoise, ...
    'MeasurementNoise', measurementNoise);

end