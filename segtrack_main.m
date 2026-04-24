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

%% 7. Refine Segmentation
wsParams = struct();
wsParams.radiusRange = [4 8];
wsParams.sensitivity = 0.96;
wsParams.edgeThreshold = 0.05;
wsParams.seedDiskRadius = 1;
wsParams.distanceSmoothSigma = 1;
wsParams.verbose = true;

labelStackSeeded = refine_labels_hough_watershed(imgPre, labelStack, wsParams);
%% Visual debug (outlines only)

z = round(size(imgPre, 3) / 2);

figure;

% Binary masks
bw1 = labelStack(:,:,z) > 0;
bw2 = labelStackSeeded(:,:,z) > 0;

% --- Original labels ---
ax1 = subplot(1,3,1);
imshow(imgPre(:,:,z), []);
hold on;
visboundaries(ax1, bw1, 'Color', 'r', 'LineWidth', 0.5);
title('Original Labels');

% --- Seeded / watershed labels ---
ax2 = subplot(1,3,2);
imshow(imgPre(:,:,z), []);
hold on;
visboundaries(ax2, bw2, 'Color', 'g', 'LineWidth', 0.5);
title('Seeded + Watershed');

% --- Seeded / watershed labels ---
ax3 = subplot(1,3,3);
imshow(imgPre(:,:,z), []);
title('original');

% Sync zoom/pan
linkaxes([ax1, ax2,ax3], 'xy');
% %% Visual debug
% z = round(size(imgPre, 3) / 2);
% figure;
% imshow(imgPre(:,:,z), []);
% hold on;
% h = imshow(label2rgb(labelStackSeeded(:,:,z), 'jet', 'k', 'shuffle'));
% set(h, 'AlphaData', 0.3);
% title('Overlay');
%% 7. Track fibrils through slices

% Placeholder for now
tracks = [];

%% 8. Save outputs

if params.saveResults
    savePath = fullfile(outputDir, 'segtrack_main_results.mat');

    save(savePath, ...
        'params', ...
        'imagePath', ...
        'labelStack', ...
        'tracks', ...
        '-v7.3');

    fprintf('Results saved to:\n%s\n', savePath);
end

%% 9. Done

fprintf('Pipeline complete.\n');