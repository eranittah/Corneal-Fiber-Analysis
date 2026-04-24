function imgStack = loadTiffStack(filePath)
% loadTiffStack
% Loads a 2D or 3D TIFF image stack into MATLAB.
%
% INPUT
%   filePath : full path to TIFF file
%
% OUTPUT
%   imgStack : image stack as a 3D numeric array

info = imfinfo(filePath);
numSlices = numel(info);

height = info(1).Height;
width  = info(1).Width;

firstSlice = imread(filePath, 1);

imgStack = zeros(height, width, numSlices, class(firstSlice));
imgStack(:,:,1) = firstSlice;

for z = 2:numSlices
    imgStack(:,:,z) = imread(filePath, z);
end

end