clear
close all

if ismac
    % Code to run on Mac platform
    addpath /Applications/CPLEX_Studio129/cplex/matlab/x86-64_osx/
elseif isunix
    % Code to run on Linux platform
    error('You''re on linux, sounds like a you problem.')
elseif ispc
    % Code to run on Windows platform
    addpath C:\'Program Files'\IBM\ILOG\CPLEX_Studio129\cplex\matlab\x64_win64
else
    error('Platform not supported')
end

% Reading input airport and flight data
D = readtable('CSV_files/gate_stand_distance.csv', 'ReadRowNames', true);
G = readtable('CSV_files/gates.csv', 'ReadRowNames', true);
M = readtable('CSV_files/schedule.csv', 'ReadRowNames', true);
L = readtable('CSV_files/stand_limit.csv', 'ReadRowNames', true);
R = readtable('CSV_files/stand_runway_distance.csv', 'ReadRowNames', true);

n_stands = length(D.Properties.RowNames);
n_ts = 60 * 24;
n_gates = length(D.Properties.VariableNames);
n_flights = length(M.Properties.RowNames);
vars = n_flights * n_stands * n_gates;

base.n_flights = n_flights;
base.n_stands = n_stands;
base.n_gates = n_gates;
base.n_ts = n_ts;
base.vars = vars;


%% Allocation requirement

tic

allocation = zeros(vars, 2);
count = 0;
for i = 1:n_flights
    line = zeros(1, vars);
    for j = 1:n_stands
        for k = 1:n_gates
            count = count + 1;
            allocation(count, :) = [i, fsgIndex(base, i, j, k)];
        end
    end
end

allocation_A = sparse(allocation(:, 1), allocation(:, 2), 1);

allocation_lhs = sparse(1:n_flights, ones(n_flights, 1), 1);
allocation_rhs = sparse(1:n_flights, ones(n_flights, 1), 1);

clear allocation;
d = toc;
disp(['Done preparing allocation matrix (' num2str(d) 's)'])

%% Stand limitations

tic

standlimits = zeros(vars, 1);
count = 0;
for i = 1:n_flights
    type = getFirst(M(i, 'AircraftType').AircraftType);
    stands = find(L.(type) == 0);
    for s = 1:n_stands
        if (sum(stands == s) >= 1)
            for k = 1:n_gates
                count = count + 1;
                standlimits(count) = fsgIndex(base, i, s, k);
            end
        end
    end
end

standlimits = standlimits(1:count);

standlimits_A = sparse(ones(size(standlimits, 2), 1), standlimits, 1, 1, vars);
standlimits_lhs = 0;
standlimits_rhs = 0;

clear standlimits;
d = toc;
disp(['Done preparing standlimits matrix (' num2str(d) 's)'])


%% Domestic/international flights limitations

tic

int_gates = zeros(1, n_gates);
dom_gates = zeros(1, n_gates);
int_flights = zeros(1, n_flights);
dom_flights = zeros(1, n_flights);

count = 0;
count_dom = 0;
count_int = 0;
for i = 1:n_flights
    count = count + 1;
    region = getFirst(M(i, 'Region').Region);
    if (strcmp('DOM', region))
        count_dom = count_dom + 1;
        dom_flights(count_dom) = count;
    else
        count_int = count_int + 1;
        int_flights(count_int) = count;
    end
end
int_flights = int_flights(1:count_int);
dom_flights = dom_flights(1:count_dom);

count = 0;
count_dom = 0;
count_int = 0;
for i = 1:n_gates
    count = count + 1;
    region = getFirst(G(i, 'Region').Region);
    if (strcmp('DOM', region))
        count_dom = count_dom + 1;
        dom_gates(count_dom) = count;
    else
        count_int = count_int + 1;
        int_gates(count_int) = count;
    end
end
int_gates = int_gates(1:count_int);
dom_gates = dom_gates(1:count_dom);

gateregion = zeros(vars, 1);

count = 0;
for i = int_flights
    for j = dom_gates
        for k = 1:n_stands
            count = count + 1;
            gateregion(count) = fsgIndex(base, i, k, j);
        end
    end
end
for i = dom_flights
    for j = int_gates
        for k = 1:n_stands
            count = count + 1;
            gateregion(count) = fsgIndex(base, i, k, j);
        end
    end
end

gateregion = gateregion(1:count);

gateregion_A = sparse(ones(count, 1), gateregion, 1, 1, vars);
gateregion_lhs = 0;
gateregion_rhs = 0;

clear gateregion;
d = toc;
disp(['Done preparing gateregion matrix (' num2str(d) 's)'])

%% Create objective functions

tic
valid = find((standlimits_A + gateregion_A) == 0);

obj1 = makeStandGateObjective(valid, base, D, M);
obj2 = makeStandRunwayObjective(valid, base, R);
obj3 = makeTerminalGateObjective(valid, base, G, M);

d = toc;
disp(['Done creating objective function (' num2str(d) 's)'])

%% Give names to the variables

varNames = cell(vars, 1);
for v = 1:vars
    [f, s, g] = unwrapIndex(v, n_stands, n_gates);
    varNames(v, :) = {['F' num2str(f) 'S' num2str(s) 'G' num2str(g)]};
end

%% Timetable constraints, begin iteration on buffertime

sols = cell(31, 4);

btcount = 0;

for buffertime = 0:30
    btcount = btcount + 1;
    
    tic
    
    timetable = zeros(n_flights * n_ts, 2);
    slots = zeros(n_flights, 1);
    
    count = 0;
    
    for f = 1:n_flights
        EIBT = split(M(f, :).EIBT, ':');
        EOBT = split(M(f, :).EOBT, ':');
        EIBT_h = str2double(EIBT{1});
        EIBT_m = str2double(EIBT{2});
        EOBT_h = str2double(EOBT{1});
        EOBT_m = str2double(EOBT{2});
        
        % trick, even though the minutes go above 60, the maths is still valid
        EIBT_m = EIBT_m - buffertime;
        EOBT_m = EOBT_m + buffertime;
        
        slots(f) = tsIndex(base, EIBT_h, EIBT_m);
        
        if (EIBT_h > EOBT_h)
            for i = tsIndex(base, EIBT_h, EIBT_m):tsIndex(base, 23, 59)
                count = count + 1;
                timetable(count, :) = [f, i];
            end
            for i = 1:tsIndex(base, EOBT_h, EOBT_m)
                count = count + 1;
                timetable(count, :) = [f, i];
            end
        else
            for i = tsIndex(base, EIBT_h, EIBT_m):tsIndex(base, EOBT_h, EOBT_m)
                count = count + 1;
                timetable(count, :) = [f, i];
            end
        end
    end
    
    timetable = timetable(1:count, :);
    
    slots = unique(slots);
    
    timetable = sparse(timetable(:, 1), timetable(:, 2), 1, n_flights, n_ts);
    
    indices = zeros(n_ts * length(slots) * (n_stands + n_gates), 2);
    count = 0;
    current = 0;
    for ts = slots'
        for j = 1:n_stands
            res = find(timetable(:, ts) == 1)';
            if (length(res) > 1)
                current = current + 1;
                for i = res
                    for k = 1:n_gates
                        count = count + 1;
                        indices(count, :) = [current, fsgIndex(base, i, j, k)];
                    end
                end
            end
        end
    end
    for ts = slots'
        for k = 1:n_gates
            res = find(timetable(:, ts) == 1)';
            if (length(res) > 1)
                current = current + 1;
                for i = res
                    for j = 1:n_stands
                        count = count + 1;
                        indices(count, :) = [current, fsgIndex(base, i, j, k)];
                    end
                end
            end
        end
    end
    
    indices = indices(1:count, :);
    timeslot_A = sparse(indices(:, 1), indices(:, 2), 1, max(indices(:, 1)), vars);
    
    rows = size(timeslot_A, 1);
    timeslot_lhs = sparse(1:rows, ones(1, rows), 0);
    timeslot_rhs = sparse(1:rows, ones(1, rows), 1);
    
    clear rows indices;
    d = toc;
    disp(['Done timetable constraints (' num2str(d) 's)'])
    
    
    tic
    c = Cplex;
    c.DisplayFunc = @sayNothing;
    %dummy
    c.addCols(1, zeros(size(c.Model.A, 1), 1), 0, 1, 'B', 'fffff');
    
    c.Model.ctype = char(66 * ones(1, vars));
    c.Model.A = [
        allocation_A%(:, valid);
        timeslot_A%(:, valid);
        standlimits_A
        gateregion_A
        ];
    c.Model.lhs = [
        allocation_lhs
        timeslot_lhs
        standlimits_lhs
        gateregion_lhs
        ];
    c.Model.rhs = [
        allocation_rhs
        timeslot_rhs
        standlimits_rhs
        gateregion_rhs
        ];
    c.Model.lb = zeros(1, vars);
    c.Model.ub =  ones(1, vars);
    c.Model.sense = 'minimize';
    
    c.Model.colname = varNames;
    
    
    close all
    
    c.Model.obj = obj1;
    c.solve();
    
    sols(btcount, 1) = {c.Solution};
    %printTimetables(c.Solution.x, base, M, 100, G, D);
    
    %pause
    
    c.Model.obj = obj2;
    c.solve();
    
    sols(btcount, 2) = {c.Solution};
    %printTimetables(c.Solution.x, base, M, 200, G, D);
    
    %pause
    
    c.Model.obj = obj3;
    c.solve();
    
    sols(btcount, 3) = {c.Solution};
    %printTimetables(c.Solution.x, base, M, 300, G, D);
    
    %pause
    
    weights = [1, 1, 1];
    
    obj = weights * [obj1/max(obj1); obj2/max(obj2); obj3/max(obj3)];
    
    c.Model.obj = obj;
    c.solve();
    
    sols(btcount, 4) = {c.Solution};
    
    %printTimetables(c.Solution.x, base, M, 400, G, D);
    
    disp(['Finished buffertime = ' num2str(btcount)])
end

%% Print some solutions and sensitivity analysis

close all
printTimetables(sols{1, 1}.x, base, M, 100, G, D)
printTimetables(sols{1, 2}.x, base, M, 200, G, D)
printTimetables(sols{1, 3}.x, base, M, 300, G, D)
printTimetables(sols{1, 4}.x, base, M, 400, G, D)

%%

close all
buffertime = 0;
objVals = zeros(4, length(buffertime));

for btidx = 1:length(buffertime)
    for i = 1:4
        objVals(i, btidx) = sols{btidx, i}.objval;
    end
end

figure
for i = 1:4
    subplot(2, 2, i)
    %objVals(i, :) = objVals(i, :) / max(objVals(i, :));
    plot(buffertime, objVals(i, :))
    grid on
    title(['Sensitivity for obj. ' num2str(i)])
    xlabel('Buffer time (minutes)')
    ylabel('Optimal solution cost')
end

%% Compare objectives
close all

objAll = zeros(4, vars);
objAll(1, :) = obj1;
objAll(2, :) = obj2;
objAll(3, :) = obj3;
objAll(4, :) = obj;

figure
for i = 1:4
    subplot(2, 2, i) % objective i
    if i == 4
        title('Objective func. weighted')
    else
        title(['Objective func. ' num2str(i)])
    end
    hold on
    grid on
    for j = 1:4 % solution to objective j
        plot(j, getCost(sols{1, j}.x, objAll(i, :)), 'x', 'MarkerSize', 12, 'LineWidth', 2)
    end
    %legend('Cost sol. 1', 'Cost sol. 2', 'Cost sol. 3', 'Cost sol. weighted')
    xticks([1, 2, 3, 4])
    xticklabels({'Sol. 1', 'Sol. 2', 'Sol. 3', 'Sol. weighted'})
    xlim([0 5])
    ll = ylim;
    ll(1) = .90 * ll(1);
    ll(2) = 1.1 * ll(2);
    ylim(ll)
    ylabel('Cost')
    hold off
end


%% Functions

function sayNothing(~)
end

function Z = getCost(sol, obj)
Z = sum(sol .* obj');
end
