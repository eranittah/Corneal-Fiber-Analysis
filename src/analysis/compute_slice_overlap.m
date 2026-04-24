function overlapFrac = compute_slice_overlap(labelStack)

Z = size(labelStack,3);
overlapFrac = zeros(Z-1,1);

for z = 1:Z-1
    bw1 = labelStack(:,:,z) > 0;
    bw2 = labelStack(:,:,z+1) > 0;

    overlap = nnz(bw1 & bw2);
    union   = nnz(bw1 | bw2);

    if union == 0
        overlapFrac(z) = 0;
    else
        overlapFrac(z) = overlap / union;
    end
end

figure;
plot(overlapFrac, 'LineWidth', 1.5);
xlabel('Slice');
ylabel('Overlap fraction');
title('Slice-to-slice overlap');

end