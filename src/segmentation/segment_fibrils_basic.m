function labelStack = segment_fibrils_basic(imgStack, params)

if ~isfield(params, 'minArea');         params.minArea = 5; end
if ~isfield(params, 'logSize');         params.logSize = 9; end
if ~isfield(params, 'logSigma');        params.logSigma = 1.5; end
if ~isfield(params, 'thresholdFactor'); params.thresholdFactor = 1.0; end
if ~isfield(params, 'closeRadius');     params.closeRadius = 0; end
if ~isfield(params, 'verbose');         params.verbose = true; end

[H, W, Z] = size(imgStack);
labelStack = zeros(H, W, Z, 'uint16');

h = fspecial('log', params.logSize, params.logSigma);

for z = 1:Z

    img = imgStack(:,:,z);

    imgInv = imcomplement(mat2gray(img));

    imgLoG = -imfilter(imgInv, h, 'replicate');
    imgLoG = mat2gray(imgLoG);

    T = graythresh(imgLoG);
    bw = imgLoG > params.thresholdFactor*T;

    % Optional tiny closing only
    if params.closeRadius > 0
        bw = imclose(bw, strel('disk', params.closeRadius));
    end

    bw = bwareaopen(bw, params.minArea);

    cc = bwconncomp(bw);

    bwDilated = false(size(bw));
    se = strel('disk', 1);
    
    for i = 1:cc.NumObjects
        temp = false(size(bw));
        temp(cc.PixelIdxList{i}) = true;
    
        temp = imdilate(temp, se);
    
        bwDilated = bwDilated | temp;
    end
    
    cc2 = bwconncomp(bwDilated);
    labelSlice = labelmatrix(cc2);
    labelStack(:,:,z) = uint16(labelSlice);

    if params.verbose && mod(z,50)==1
        fprintf('Slice %d/%d | T=%.3f | objects=%d | pixels=%d\n', ...
            z, Z, T, cc.NumObjects, nnz(bw));
    end
end
end