function i = fsgIndex(base, f, s, g)
    i = (f - 1) * base.n_stands * base.n_gates + (s - 1) * base.n_gates + g;
end