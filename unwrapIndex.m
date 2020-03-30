function [flight, stand, gate] = unwrapIndex(i, n_stands, n_gates)
    gate = mod(i, n_gates) + (mod(i, n_gates) == 0) .* n_gates;
    flight = fix(i / (n_stands * n_gates)) + (mod(i, (n_stands * n_gates)) ~= 0) .* 1;
    stand = (i - gate - (flight - 1) * n_gates * n_stands) / n_gates + 1;
end
