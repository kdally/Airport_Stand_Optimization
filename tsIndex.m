function i = tsIndex(base, h, m)
    i = 1 + h * (base.n_ts / 24) + fix(m/(60 / (base.n_ts / 24)));
end