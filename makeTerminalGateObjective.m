function obj = makeTerminalGateObjective(valid, base, G, M)

obj = zeros(1, length(valid));
count = 0;
for i = valid
    count = count + 1;
    [flight, ~, gate] = unwrapIndex(i, base.n_stands, base.n_gates);
    obj(count) = G(gate, 3).WalkingDistance * M(flight, 6).Passengers;
end
obj = sparse(1, valid, obj, 1, base.vars);

end

