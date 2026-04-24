function numObjs = plot_objects_per_slice(labelStack)
% plot_objects_per_slice
% Computes and plots number of connected components per slice
%
% INPUT
%   labelStack : H x W x Z labeled image stack
%
% OUTPUT
%   numObjs : Z x 1 vector of object counts per slice

Z = size(labelStack, 3);
numObjs = zeros(Z,1);

for z = 1:Z
    cc = bwconncomp(labelStack(:,:,z) > 0);
    numObjs(z) = cc.NumObjects;
end

figure;
plot(numObjs,'.');
xlabel('Slice');
ylabel('# Objects');
title('Objects per slice');
grid on;

end