function obj = makeStandRunwayObjective(valid, base, R)

obj = zeros(1, length(valid));
count = 0;
for i = valid
    count = count + 1;
    [~, stand, ~] = unwrapIndex(i, base.n_stands, base.n_gates);
    
    obj(count) = R(stand, 1).DistanceRW;
end
obj = sparse(1, valid, obj, 1, base.vars);

end