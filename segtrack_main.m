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
imgPre = imgStack;

%% 6. Segment fibrils

% Placeholder for now
labelStack = [];

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