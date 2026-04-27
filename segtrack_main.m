%% main_segtrack_pipeline.m
% Main pipeline for corneal fibril segmentation and tracking
% Author: Eran Ittah
% Project: Corneal Fiber Analysis

clear; clc; close all;

%% 1. Set project paths

projectRoot = fileparts(mfilename('fullpath'));

srcDir     = fullfile(projectRoot, 'src');
dataDir    = fullfile(projectRoot, 'data');
outputDir  = fullfile(projectRoot, 'outputs');

addpath(genpath(srcDir));

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% 2. User settings

params = struct();

params.pixelSizeXY_nm = 3;
params.pixelSizeZ_nm  = 3;

params.verbose = true;
params.saveResults = true;

%% 3. Select input image stack

[fileName, filePath] = uigetfile( ...
    {'*.tif;*.tiff', 'TIFF stacks (*.tif, *.tiff)'}, ...
    'Select image stack');

if isequal(fileName, 0)
    error('No file selected.');
end

imagePath = fullfile(filePath, fileName);

fprintf('Loading image stack:\n%s\n', imagePath);

%% 4. Load image stack

imgStack = loadTiffStack(imagePath);

fprintf('Loaded stack size: %d x %d x %d\n', ...
    size(imgStack,1), size(imgStack,2), size(imgStack,3));

%% 5. Preprocess stack & add hann window to abrupt masks
% taperWidthPx = 5;
% blackThreshold = 0;
% [imgFeathered, softKeepMaskStack, inferredMaskStack] = featherBlackMaskedStack(imgStack, taperWidthPx, blackThreshold);
%%
imgPre = imgaussfilt3(imgStack, [1 1 0.5]);
imgPre = imgPre(:,:,200:300);

%% 6. Preliminary fibril Segmentation

segParams.minArea = 5;
segParams.logSize = 9;
segParams.logSigma = 1.5;
segParams.thresholdFactor = 1.25;
segParams.closeRadius = 0;
segParams.verbose = true;

labelStack = segment_fibrils_basic(imgPre, segParams);

%% 7. initial label filtering of those at mask boundarys
[labelClean, ~] = removeLabelsTouchingZero(imgPre, labelStack);

%% 8. Refine Segmentation using either LoG or Hough
wsParams = struct();
wsParams.logSize = 9;
wsParams.logSigma = 1.5;
wsParams.seedThresholdFactor = 0.35;
wsParams.seedDilateRadius = 1;
wsParams.distanceSmoothSigma = 1;
wsParams.verbose = true;

params.refineMethod = "logmax";  % "hough" or "logmax"

switch params.refineMethod
    case "hough"
        labelStackSeeded = refine_labels_hough_watershed(imgPre, labelClean, wsParams);

    case "logmax"
        labelStackSeeded = refine_labels_logmax_watershed(imgPre, labelClean, wsParams);

    otherwise
        error('Unknown refineMethod: %s', params.refineMethod);
end
%% 7. Track fibrils through slices
% Placeholder for now
tic
tracks = trackLabelStackGNN(labelStackSeeded);
toc
%% Fast Kalman Tracking...
tracksFast = trackLabelStackKalmanLAP(labelStack, ...
    'MaxDist', 8, ...
    'MaxMissed', 10, ...
    'MinTrackLength', 20, ...
    'Verbose', true);
%% close gaps after tracking
tracksClosed = gapCloseTracks(tracksFast, ...
    'MaxGap', 5, ...
    'MaxDistPerSlice', 3, ...
    'MinTrackLength', 20, ...
    'Verbose', true);
%% Visual debug (outlines only)
%Show segmentation overlays
% compare_label_outlines(imgPre, labelStack, labelStackSeeded);
% View just filled labels
view_label_overlay_filled(imgPre,labelStackSeeded);
% plot number of objects per-slice (evaluate noise)
% numObjs = plot_objects_per_slice(labelStackSeeded);
%check quality of overlaps
% ovelapFrac = compute_slice_overlap(labelStackSeeded);


%% 8. Save outputs

if params.saveResults
    savePath = fullfile(outputDir, 'segtrack_main_results.mat');

    refineMethod = params.refineMethod;

    save(savePath, ...
    'params', ...
    'imagePath', ...
    'labelStack', ...
    'labelStackSeeded', ...
    'refineMethod', ...
    '-v7.3');

    fprintf('Results saved to:\n%s\n', savePath);
end

%% 9. Done

fprintf('Pipeline complete.\n');