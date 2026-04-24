function compare_label_outlines(imgStack, labelStack1, labelStack2, zStart)
% compare_label_outlines
% Interactive 3-panel slice viewer:
%   1. Raw image
%   2. LabelStack1 outlines
%   3. LabelStack2 outlines
%
% Keyboard controls:
%   Right arrow / D : next slice
%   Left arrow / A  : previous slice

if nargin < 4 || isempty(zStart)
    zStart = round(size(imgStack,3)/2);
end

Z = size(imgStack,3);
z = max(1, min(Z, zStart));

fig = figure('Name', 'Compare Label Outlines');
set(fig, 'KeyPressFcn', @keyPress);

ax0 = subplot(1,3,1);
ax1 = subplot(1,3,2);
ax2 = subplot(1,3,3);

linkaxes([ax0, ax1, ax2], 'xy');

updateDisplay();

    function updateDisplay()

    % Preserve current FOV if axes already contain an image
    if ~isempty(ax0.Children)
        xlimKeep = xlim(ax0);
        ylimKeep = ylim(ax0);
    else
        xlimKeep = [];
        ylimKeep = [];
    end

    cla(ax0);
    cla(ax1);
    cla(ax2);

    bw1 = labelStack1(:,:,z) > 0;
    bw2 = labelStack2(:,:,z) > 0;

    % Raw
    imshow(imgStack(:,:,z), [], 'Parent', ax0);
    title(ax0, sprintf('Raw | Slice %d/%d', z, Z));

    % Label stack 1
    imshow(imgStack(:,:,z), [], 'Parent', ax1);
    hold(ax1, 'on');
    visboundaries(ax1, bw1, 'Color', 'r', 'LineWidth', 0.5);
    title(ax1, sprintf('Label Stack 1 | Slice %d/%d', z, Z));

    % Label stack 2
    imshow(imgStack(:,:,z), [], 'Parent', ax2);
    hold(ax2, 'on');
    visboundaries(ax2, bw2, 'Color', 'g', 'LineWidth', 0.5);
    title(ax2, sprintf('Label Stack 2 | Slice %d/%d', z, Z));

    linkaxes([ax0, ax1, ax2], 'xy');

    % Restore previous zoom/pan view
    if ~isempty(xlimKeep)
        xlim(ax0, xlimKeep);
        ylim(ax0, ylimKeep);
    end

    drawnow;
end

    function keyPress(~, event)

        switch event.Key
            case {'rightarrow', 'd'}
                z = min(Z, z + 1);
                updateDisplay();

            case {'leftarrow', 'a'}
                z = max(1, z - 1);
                updateDisplay();
        end
    end

end