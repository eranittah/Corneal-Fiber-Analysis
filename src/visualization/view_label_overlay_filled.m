function view_label_overlay_filled(imgStack, labelStack, zStart, alphaVal)
% view_label_overlay_filled
% Interactive viewer for one label stack overlaid as low-opacity filled labels.
%
% Inputs:
%   imgStack    - grayscale image stack, size Y x X x Z
%   labelStack  - label matrix stack, size Y x X x Z
%   zStart      - optional starting slice
%   alphaVal    - optional overlay opacity, default = 0.25
%
% Keyboard controls:
%   Right arrow / D : next slice
%   Left arrow / A  : previous slice

if nargin < 3 || isempty(zStart)
    zStart = round(size(imgStack, 3) / 2);
end

if nargin < 4 || isempty(alphaVal)
    alphaVal = 0.25;
end

Z = size(imgStack, 3);
z = max(1, min(Z, zStart));

fig = figure('Name', 'Filled Label Overlay Viewer');
set(fig, 'KeyPressFcn', @keyPress);

ax = axes('Parent', fig);

updateDisplay();

    function updateDisplay()

        if ~isempty(ax.Children)
            xlimKeep = xlim(ax);
            ylimKeep = ylim(ax);
        else
            xlimKeep = [];
            ylimKeep = [];
        end

        cla(ax);

        img = imgStack(:,:,z);
        L = labelStack(:,:,z);

        imshow(img, [], 'Parent', ax);
        hold(ax, 'on');

        labels = unique(L(:));
        labels(labels == 0) = [];

        if ~isempty(labels)
            rgbOverlay = label2rgb(L, 'lines', 'k', 'shuffle');

            h = imshow(rgbOverlay, 'Parent', ax);
            set(h, 'AlphaData', alphaVal * (L > 0));
        end

        title(ax, sprintf('Filled Label Overlay | Slice %d/%d', z, Z));

        if ~isempty(xlimKeep)
            xlim(ax, xlimKeep);
            ylim(ax, ylimKeep);
        end

        hold(ax, 'off');
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