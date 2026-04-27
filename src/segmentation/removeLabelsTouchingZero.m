function [labelClean, removedMask] = removeLabelsTouchingZero(imgPre, labelStack)

    imgPre = double(imgPre);

    inputWas2D = ismatrix(imgPre);

    if inputWas2D
        imgPre = reshape(imgPre, size(imgPre,1), size(imgPre,2), 1);
        labelStack = reshape(labelStack, size(labelStack,1), size(labelStack,2), 1);
    end

    [ny, nx, nz] = size(imgPre);

    if ~isequal(size(labelStack), [ny nx nz])
        error('imgPre and labelStack must have identical dimensions.');
    end

    labelClean = labelStack;
    removedMask = false(size(labelStack));

    for k = 1:nz

        img = imgPre(:,:,k);
        labels = labelClean(:,:,k);

        zeroMask = img == 0;

        % Dilate zero regions so labels touching the zero boundary are removed
        zeroDilated = imdilate(zeroMask, ones(3));

        labelIDs = unique(labels);
        labelIDs(labelIDs == 0) = [];

        removeMaskSlice = false(size(labels));

        for i = 1:numel(labelIDs)
            id = labelIDs(i);
            objMask = labels == id;

            if any(zeroDilated(objMask))
                removeMaskSlice(objMask) = true;
            end
        end

        labels(removeMaskSlice) = 0;

        labelClean(:,:,k) = labels;
        removedMask(:,:,k) = removeMaskSlice;
    end

    if inputWas2D
        labelClean = labelClean(:,:,1);
        removedMask = removedMask(:,:,1);
    end
end