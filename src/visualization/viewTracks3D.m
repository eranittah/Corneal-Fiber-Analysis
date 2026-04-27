function viewTracks3D(tracks, varargin)
%VIEWTRACKS3D Visualize fibril tracks in 3D.
%
% viewTracks3D(tracks)
% viewTracks3D(tracks, 'MinLength', 10, 'ScaleZ', 1)

p = inputParser;
p.addRequired('tracks', @isstruct);
p.addParameter('MinLength', 1, @isnumeric);
p.addParameter('ScaleZ', 1, @isnumeric);
p.addParameter('ShowPoints', true, @islogical);
p.addParameter('LineWidth', 1.5, @isnumeric);
p.parse(tracks, varargin{:});

minLength = p.Results.MinLength;
scaleZ = p.Results.ScaleZ;
showPoints = p.Results.ShowPoints;
lineWidth = p.Results.LineWidth;

figure;
hold on;

nShown = 0;

for i = 1:numel(tracks)
    xyz = tracks(i).xyz;

    if size(xyz,1) < minLength
        continue;
    end

    x = xyz(:,1);
    y = xyz(:,2);
    z = xyz(:,3) * scaleZ;

    plot3(x, y, z, '-', 'LineWidth', lineWidth);

    if showPoints
        plot3(x, y, z, '.', 'MarkerSize', 8);
    end

    nShown = nShown + 1;
end

axis equal;
grid on;
xlabel('X (px)');
ylabel('Y (px)');
zlabel(sprintf('Z × %.3g', scaleZ));
title(sprintf('3D Tracks (%d shown)', nShown));

view(3);
rotate3d on;

end