function [idx, r] = stackNumbers(A)
    max = 0;
    r = zeros(size(A, 1), 5);
    idx = zeros(size(A, 1), 5);
    for i = 1:size(A, 1)
        row = 1;
        ind = 1;
        if (A(i, 1) == 1)
            ind = [ind, 1];
            row = [0, row];
        end
        for j = 2:size(A, 2)
            if (A(i, j) == A(i, j-1))
                row(end) = row(end) + 1;
            else
                row = [row, 1];
                ind = [ind, j];
            end
        end
        if (size(row, 2) > max)
            max = size(row, 2);
        end
        for k = 1:length(row)
            r(i, k) = row(k);
            idx(i, k) = ind(k);
        end
    end
    r = r(:, 1:max);
    idx = idx(:, 1:max);
end