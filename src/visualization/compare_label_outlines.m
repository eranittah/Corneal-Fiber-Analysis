function compare_label_outlines(imgStack, labelStack1, labelStack2, z)

if nargin < 4
    z = round(size(imgStack,3)/2);
end

figure;

bw1 = labelStack1(:,:,z) > 0;
bw2 = labelStack2(:,:,z) > 0;

% Raw
ax0 = subplot(1,3,1);
imshow(imgStack(:,:,z), []);
title('Raw');

% Method 1
ax1 = subplot(1,3,2);
imshow(imgStack(:,:,z), []);
hold on;
visboundaries(ax1, bw1, 'Color', 'r', 'LineWidth', 0.5);
title('Method 1');

% Method 2
ax2 = subplot(1,3,3);
imshow(imgStack(:,:,z), []);
hold on;
visboundaries(ax2, bw2, 'Color', 'g', 'LineWidth', 0.5);
title('Method 2');

linkaxes([ax0, ax1, ax2], 'xy');

end