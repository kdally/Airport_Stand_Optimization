function obj = makeStandGateObjective(valid, base, D, M)

obj = zeros(1, length(valid));
count = 0;
for i = valid
    count = count + 1;
    [flight, stand, gate] = unwrapIndex(i, base.n_stands, base.n_gates);
    dist = D(stand, gate);
    obj(count) = dist.(1) * M(flight, 6).Passengers;
end
obj = sparse(1, valid, obj, 1, base.vars);

end

