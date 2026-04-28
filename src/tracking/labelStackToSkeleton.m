function skelStack = labelStackToSkeleton(labelStack, varargin)
%LABELSTACKTOSKELETON Convert label stack to centroid skeleton stack.
%
% Each labeled object becomes one 255-valued pixel at its centroid.
% Background is 0.
%
% Output:
%   skelStack: uint8 stack, values 0 and 255 only.

p = inputParser;
p.addRequired('labelStack', @(x) isnumeric(x) || islogical(x));
p.addParameter('MinSize', 0, @isnumeric);
p.parse(labelStack, varargin{:});

minSize = p.Results.MinSize;

[H, W, Z] = size(labelStack);
skelStack = zeros(H, W, Z, 'uint8');

for z = 1:Z
    lab = labelStack(:,:,z);

    stats = regionprops(lab, 'Centroid', 'Area');

    for i = 1:numel(stats)

        if stats(i).Area < minSize
            continue;
        end

        c = stats(i).Centroid;

        x = round(c(1));
        y = round(c(2));

        % Safety clamp
        x = max(1, min(W, x));
        y = max(1, min(H, y));

        skelStack(y, x, z) = 255;
    end
end

end