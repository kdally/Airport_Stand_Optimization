function printTimetables(solution, base, M, offset, G, D)

sol = find(solution == 1);

standtt = zeros(base.n_stands, base.n_ts);
gatett = zeros(base.n_gates, base.n_ts);

count = 0;
for x = sol'
    [f, s, g] = unwrapIndex(x, base.n_stands, base.n_gates);
    
    count = count + 1;

    EIBT = split(M(f, :).EIBT, ':');
    EOBT = split(M(f, :).EOBT, ':');
    EIBT_h = str2double(EIBT{1});
    EIBT_m = str2double(EIBT{2});
    EOBT_h = str2double(EOBT{1});
    EOBT_m = str2double(EOBT{2});
    
    if (EIBT_h > EOBT_h)
        for i = tsIndex(base, EIBT_h, EIBT_m):tsIndex(base, 23, 59)
            standtt(s, i) = standtt(s, i) + 1;
            gatett(g, i) = gatett(g, i) + 1;
        end
        for i = 1:tsIndex(base, EOBT_h, EOBT_m)
            standtt(s, i) = standtt(s, i) + 1;
            gatett(g, i) = gatett(g, i) + 1;
        end
    else
        for i = tsIndex(base, EIBT_h, EIBT_m):tsIndex(base, EOBT_h, EOBT_m)
            standtt(s, i) = standtt(s, i) + 1;
            gatett(g, i) = gatett(g, i) + 1;
        end
    end
end

%% Timetable graph

[~, idx] = stackNumbers(standtt);

figure(offset + 1)
h = barh(size(standtt, 1):-1:1, idx, 'stacked');
set(h(1:2:size(h, 2)), 'Visible', 'off');
set(h(2:2:size(h, 2)), 'FaceColor', 'y');
xlim([0, base.n_ts])
xticks(linspace(0, 1440, 13))
xticklabels({'0:00','2:00','4:00','6:00','8:00','10:00','12:00','14:00','16:00','18:00','20:00','22:00','0:00'})
yticks(1:1:base.n_stands)
yticklabels(flip(D.Properties.RowNames)')
set(gcf,'position',[000,000,600,600])
xlabel('Time');
ylabel('Stand Number');    


[~, idx] = stackNumbers(gatett);

figure(offset + 2)
h = barh(size(gatett, 1):-1:1, idx, 'stacked');
set(h(1:2:size(h, 2)), 'Visible', 'off');
set(h(2:2:size(h, 2)), 'FaceColor', 'y');
xlim([0, base.n_ts])
xticks(linspace(0, 1440, 13))
xticklabels({'0:00','2:00','4:00','6:00','8:00','10:00','12:00','14:00','16:00','18:00','20:00','22:00','0:00'})
set(gcf,'position',[000,000,600,600])
xlabel('Time');
ylabel('Gate Number'); 
yticks(1:1:base.n_gates);
yticklabels(flip(G.Properties.RowNames)');


for x = sol'
    [f, s, g] = unwrapIndex(x, base.n_stands, base.n_gates);

    EIBT = split(M(f, :).EIBT, ':');
    EIBT_h = str2double(EIBT{1});
    EIBT_m = str2double(EIBT{2});
    EOBT = split(M(f, :).EOBT, ':');
    EOBT_h = str2double(EOBT{1});
    EOBT_m = str2double(EOBT{2});
    indI = tsIndex(base, EIBT_h, EIBT_m);
    indO = tsIndex(base, EOBT_h, EOBT_m);
    
    if (indI > indO)
        ind = tsIndex(base, EOBT_h, EOBT_m - 70);
    else
        ind = indI;
    end
    
    name = M.Properties.RowNames(f);
    figure(offset + 1)
    text(ind, (base.n_stands - s + 1), name,'FontSize',9)
    figure(offset + 2)
    text(ind, (base.n_gates - g + 1), name,'FontSize',9)
end

figure(offset + 1)
ax = gca;
outerpos = ax.OuterPosition;
ti = ax.TightInset; 
left = outerpos(1) + ti(1);
bottom = outerpos(2) + ti(2);
ax_width = outerpos(3) - ti(1) - ti(3);
ax_height = outerpos(4) - ti(2) - ti(4);
ax.Position = [left bottom ax_width ax_height];
figure(offset + 2)
ax = gca;
outerpos = ax.OuterPosition;
ti = ax.TightInset; 
left = outerpos(1) + ti(1);
bottom = outerpos(2) + ti(2);
ax_width = outerpos(3) - ti(1) - ti(3);
ax_height = outerpos(4) - ti(2) - ti(4);
ax.Position = [left bottom ax_width ax_height];

end