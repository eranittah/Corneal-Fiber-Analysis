function [posMask, negMask, finalMask, action] = interactivePaintMask2D(img, initMask)

% Interactive painting tool for SAM prompting
% Left click  = positive (include)
% Right click = negative (exclude)
%
% Keys:
%   A = accept
%   R = rerun SAM
%   C = cancel
%   [ / ] = decrease/increase brush size

if nargin < 2 || isempty(initMask)
    initMask = false(size(img));
end

img = mat2gray(img);

posMask = false(size(img));
negMask = false(size(img));
finalMask = initMask;
action = '';

brushRadius = 5;

% --- Figure setup ---
hFig = figure('Name','Interactive SAM Mask Painter',...
    'NumberTitle','off','KeyPressFcn',@keyHandler);

hAx = axes(hFig);
imshow(img, 'Parent', hAx); hold on;

hOverlay = imshow(cat(3, ...
    finalMask, zeros(size(finalMask)), negMask));
set(hOverlay, 'AlphaData', 0.3);

title({'Left = include | Right = exclude',...
       '[ / ] brush size | A accept | R rerun | C cancel'});

set(hFig, 'WindowButtonDownFcn', @mouseDown);
set(hFig, 'WindowButtonUpFcn', @mouseUp);
set(hFig, 'WindowButtonMotionFcn', @mouseMove);

isDrawing = false;
drawMode = 'pos'; % 'pos' or 'neg'

% --- Callbacks ---
    function mouseDown(~,~)
        isDrawing = true;

        sel = get(hFig, 'SelectionType');
        if strcmp(sel, 'normal')
            drawMode = 'pos';
        elseif strcmp(sel, 'alt')
            drawMode = 'neg';
        end

        applyBrush();
    end

    function mouseUp(~,~)
        isDrawing = false;
    end

    function mouseMove(~,~)
        if isDrawing
            applyBrush();
        end
    end

    function applyBrush()
        pt = round(get(hAx, 'CurrentPoint'));
        x = pt(1,1);
        y = pt(1,2);

        if x < 1 || y < 1 || x > size(img,2) || y > size(img,1)
            return;
        end

        [X,Y] = meshgrid(1:size(img,2), 1:size(img,1));
        mask = (X - x).^2 + (Y - y).^2 <= brushRadius^2;

        if strcmp(drawMode, 'pos')
            posMask(mask) = true;
            negMask(mask) = false;
        else
            negMask(mask) = true;
            posMask(mask) = false;
        end

        updateOverlay();
    end

    function updateOverlay()
        finalMask = (initMask | posMask) & ~negMask;

        overlay = cat(3, ...
            finalMask, ...   % red = mask
            zeros(size(finalMask)), ...
            negMask);        % blue = excluded

        set(hOverlay, 'CData', overlay);
    end

    function keyHandler(~, event)
        switch lower(event.Key)
            case 'a'
                action = 'accept';
                uiresume;
                close(hFig);
            case 'r'
                action = 'rerunSAM';
                uiresume;
                close(hFig);
            case 'c'
                action = 'cancel';
                uiresume;
                close(hFig);
            case 'bracketleft'
                brushRadius = max(1, brushRadius - 2);
                title(sprintf('Brush size: %d', brushRadius));
            case 'bracketright'
                brushRadius = brushRadius + 2;
                title(sprintf('Brush size: %d', brushRadius));
        end
    end

uiwait(hFig);

end