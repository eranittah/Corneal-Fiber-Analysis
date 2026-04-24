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

%% 5. Preprocess stack

% Placeholder for now
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

%% 7. Refine Segmentation using either LoG or Hough
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
        labelStackSeeded = refine_labels_hough_watershed(imgPre, labelStack, wsParams);

    case "logmax"
        labelStackSeeded = refine_labels_logmax_watershed(imgPre, labelStack, wsParams);

    otherwise
        error('Unknown refineMethod: %s', params.refineMethod);
end
%% 8. Re-refine based on neighborhood density
nnParams = struct();
nnParams.cutoffDist = 12;      % pixels
nnParams.minNeighbors = 3;
nnParams.verbose = true;

[labelStackNN, neighborCounts] = refine_seg_nearest(labelStackSeeded, nnParams);
%% Visual debug (outlines only)
%Show segmentation overlays
compare_label_outlines(imgPre, labelStack, labelStackSeeded);
% plot number of objects per-slice (evaluate noise)
% numObjs = plot_objects_per_slice(labelStackSeeded);
%check quality of overlaps
% ovelapFrac = compute_slice_overlap(labelStackSeeded);

%% 7. Track fibrils through slices

% Placeholder for now
tracks = [];

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