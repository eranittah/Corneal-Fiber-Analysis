function exportTiffStack3D(stack3D, outPath, varargin)
%EXPORTTIFFSTACK3D Export a 3D matrix as a multi-page TIFF stack with metadata.
%
% exportTiffStack3D(stack3D, outPath)
% exportTiffStack3D(stack3D, outPath, 'PixelSizeXY', 4, 'PixelSizeZ', 3, 'Unit', 'nm')
%
% Metadata is written into the TIFF ImageDescription field.

p = inputParser;
p.addRequired('stack3D', @(x) isnumeric(x) || islogical(x));
p.addRequired('outPath', @(x) ischar(x) || isstring(x));
p.addParameter('PixelSizeXY', [], @isnumeric);
p.addParameter('PixelSizeZ', [], @isnumeric);
p.addParameter('Unit', 'pixel', @(x) ischar(x) || isstring(x));
p.addParameter('DataType', 'uint8', @(x) ischar(x) || isstring(x));
p.addParameter('Overwrite', true, @islogical);
p.parse(stack3D, outPath, varargin{:});

pixelSizeXY = p.Results.PixelSizeXY;
pixelSizeZ  = p.Results.PixelSizeZ;
unitName    = char(p.Results.Unit);
dataType    = char(p.Results.DataType);
overwrite   = p.Results.Overwrite;

outPath = char(outPath);

if exist(outPath, 'file') && ~overwrite
    error('File already exists: %s', outPath);
end

% Convert data type
switch lower(dataType)
    case 'uint8'
        stackOut = uint8(stack3D);
    case 'uint16'
        stackOut = uint16(stack3D);
    case 'single'
        stackOut = single(stack3D);
    otherwise
        error('Unsupported DataType: %s. Use uint8, uint16, or single.', dataType);
end

[H, W, Z] = size(stackOut);

% Metadata string
metadata = sprintf([ ...
    'ImageJ=1.53\n' ...
    'images=%d\n' ...
    'slices=%d\n' ...
    'width=%d\n' ...
    'height=%d\n' ...
    'unit=%s\n'], ...
    Z, Z, W, H, unitName);

if ~isempty(pixelSizeXY)
    metadata = sprintf('%sspacing_xy=%g\npixel_width=%g\npixel_height=%g\n', ...
        metadata, pixelSizeXY, pixelSizeXY, pixelSizeXY);
end

if ~isempty(pixelSizeZ)
    metadata = sprintf('%sspacing=%g\npixel_depth=%g\n', ...
        metadata, pixelSizeZ, pixelSizeZ);
end

% Delete existing file if overwriting
if exist(outPath, 'file') && overwrite
    delete(outPath);
end

% Write stack
for z = 1:Z
    slice = stackOut(:,:,z);

    if z == 1
        imwrite(slice, outPath, ...
            'tif', ...
            'Compression', 'none', ...
            'Description', metadata);
    else
        imwrite(slice, outPath, ...
            'tif', ...
            'WriteMode', 'append', ...
            'Compression', 'none');
    end
end

fprintf('Exported TIFF stack: %s\n', outPath);
fprintf('Size: %d x %d x %d\n', H, W, Z);

if ~isempty(pixelSizeXY) || ~isempty(pixelSizeZ)
    fprintf('Voxel size: XY = %g %s, Z = %g %s\n', ...
        pixelSizeXY, unitName, pixelSizeZ, unitName);
end

end