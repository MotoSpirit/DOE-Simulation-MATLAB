%% plot_derating_curves.m
% Visualització de les corbes de derating tèrmic T-k
% Motor i Bateria per a les configuracions CAIXA i DIRECTE
% =========================================================

clear; clc;

%% --- Dades CAIXA ---
% Corba OPTIMITZADA per a CAIXA (Model de Potència T_start=116.0, Alpha=1.53)
derat_c = struct( ...
    'mot_T', [0,125.852,125.862,126.245,126.628,127.011,127.393,127.776,128.159,128.542,128.924,129.307, ...
              129.69,130.073,130.455,130.838,131.221,131.604,131.986,132.369,132.752,133.135,133.517, ...
              133.9,134.283,134.666,135.048,135.431,135.814,136.197,136.579,136.962,137.345,137.728, ...
              138.11,138.493,138.876,139.259,139.641,140.024,140.407,140.79,141.172,141.555,141.938, ...
              142.321,142.703,143.086,143.469,143.852,144.234,144.617,145,145.01,200], ...
    'mot_k', [1.000,1.000,1.000,0.997,0.992,0.986,0.978,0.969,0.960,0.949,0.938,0.926,0.913,0.899,0.885, ...
              0.870,0.855,0.839,0.822,0.805,0.787,0.769,0.750,0.731,0.712,0.692,0.671,0.650,0.629,0.607, ...
              0.585,0.562,0.539,0.515,0.491,0.467,0.443,0.417,0.392,0.366,0.340,0.314,0.287,0.260,0.232, ...
              0.204,0.176,0.148,0.119,0.089,0.060,0.030,0.000,0.000,0.000], ...
    'bat_T', [0, 60, 65, 70, 75, 100], ...
    'bat_k', [1.0, 1.0, 0.85, 0.5, 0, 0]);

%% --- Dades DIRECTE ---
% Corba OPTIMITZADA per a DIRECTE (Model de Potència T_start=105.7, Alpha=1.51)
derat_d = struct( ...
    'mot_T', [0,119.99,120,120.5,121,121.5,122,122.5,123,123.5,124,124.5,125,125.5,126,126.5,127,127.5, ...
              128,128.5,129,129.5,130,130.5,131,131.5,132,132.5,133,133.5,134,134.5,135,135.5,136,136.5, ...
              137,137.5,138,138.5,139,139.5,140,140.5,141,141.5,142,142.5,143,143.5,144,144.5,145,145.01,200], ...
    'mot_k', [1.000,1.000,1.000,0.997,0.992,0.985,0.977,0.968,0.958,0.948,0.936,0.924,0.911,0.897,0.882, ...
              0.867,0.852,0.836,0.819,0.802,0.784,0.766,0.747,0.728,0.708,0.688,0.667,0.646,0.625,0.603, ...
              0.581,0.558,0.535,0.512,0.488,0.464,0.439,0.414,0.389,0.363,0.337,0.311,0.284,0.257,0.230, ...
              0.202,0.174,0.146,0.118,0.089,0.059,0.030,0.000,0.000,0.000], ...
    'bat_T', [0, 62.19, 62.2, 64.15, 66.1, 68.05, 70, 70.01, 100], ...
    'bat_k', [1.0, 1.0, 1.0, 0.817, 0.598, 0.339, 0, 0, 0]);

%% --- Colors ---
col_c    = [0.00, 0.45, 0.74];   % azul  -> CAIXA
col_d    = [0.85, 0.33, 0.10];   % taronja -> DIRECTE
col_cbat = [0.30, 0.60, 1.00];   % blau clar bateria CAIXA
col_dbat = [1.00, 0.55, 0.20];   % taronja clar bateria DIRECTE

%% =========================================================
%  Figura 1 — Motor derating  (T-k  motor)
%% =========================================================
fig1 = figure('Name','Motor Derating T-k','NumberTitle','off', ...
              'Color','w','Position',[100 200 860 480]);

% Zona útil (k=1) — fons verd clar
x_fill_c = [min(derat_c.mot_T), derat_c.mot_T(find(derat_c.mot_k<1,1)-1), ...
             derat_c.mot_T(find(derat_c.mot_k<1,1)-1), min(derat_c.mot_T)];
y_fill   = [0 0 1 1];
fill(x_fill_c, y_fill, [0.85 0.95 0.85], 'EdgeColor','none','FaceAlpha',0.35); hold on;

% Referència k=1 i k=0
yline(1.0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.8,'HandleVisibility','off');
yline(0.0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.8,'HandleVisibility','off');

% Corbes principals (només rang actiu: evitem la prolongació a T=200)
mask_c = derat_c.mot_T <= 145.01;
mask_d = derat_d.mot_T <= 145.01;

plot(derat_c.mot_T(mask_c), derat_c.mot_k(mask_c), '-', ...
     'Color', col_c, 'LineWidth', 2.5, 'DisplayName', 'CAIXA  (T_{start}=116.0°C, α=1.53)');
plot(derat_d.mot_T(mask_d), derat_d.mot_k(mask_d), '-', ...
     'Color', col_d, 'LineWidth', 2.5, 'DisplayName', 'DIRECTE (T_{start}=105.7°C, α=1.51)');

% Punt d'inici del derating
T0_c = derat_c.mot_T(find(derat_c.mot_k < 1, 1));
T0_d = derat_d.mot_T(find(derat_d.mot_k < 1, 1));
plot(T0_c, 1.0, 'o', 'Color', col_c, 'MarkerFaceColor', col_c, 'MarkerSize', 7, 'HandleVisibility','off');
plot(T0_d, 1.0, 'o', 'Color', col_d, 'MarkerFaceColor', col_d, 'MarkerSize', 7, 'HandleVisibility','off');
xline(T0_c, ':', 'Color', col_c, 'LineWidth', 1.2, 'HandleVisibility','off');
xline(T0_d, ':', 'Color', col_d, 'LineWidth', 1.2, 'HandleVisibility','off');

xlabel('Temperatura motor (°C)', 'FontSize', 12, 'FontWeight','bold');
ylabel('Factor de derating  k  [-]', 'FontSize', 12, 'FontWeight','bold');
title('Corbes de Derating del Motor — CAIXA vs DIRECTE', 'FontSize', 14, 'FontWeight','bold');
legend('Location','northeast','FontSize',10);
grid on; box on;
xlim([115, 147]); ylim([-0.05, 1.10]);
set(gca,'FontSize',11,'GridAlpha',0.3,'XMinorGrid','on');

% Anotacions dels punts de tall
text(T0_c+0.1, 1.04, sprintf('%.1f°C', T0_c), 'Color', col_c, ...
     'FontSize', 9, 'FontWeight','bold', 'HorizontalAlignment','left');
text(T0_d+0.1, 1.04, sprintf('%.1f°C', T0_d), 'Color', col_d, ...
     'FontSize', 9, 'FontWeight','bold', 'HorizontalAlignment','left');

%% =========================================================
%  Figura 2 — Bateria derating  (T-k  bateria)
%% =========================================================
fig2 = figure('Name','Bateria Derating T-k','NumberTitle','off', ...
              'Color','w','Position',[160 150 860 480]);

yline(1.0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.8,'HandleVisibility','off'); hold on;
yline(0.0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.8,'HandleVisibility','off');

% Corbes bateria
stairs(derat_c.bat_T, derat_c.bat_k, '-', ...
       'Color', col_c, 'LineWidth', 2.5, 'DisplayName', 'CAIXA');
stairs(derat_d.bat_T, derat_d.bat_k, '-', ...
       'Color', col_d, 'LineWidth', 2.5, 'DisplayName', 'DIRECTE');

% Punts de control
plot(derat_c.bat_T, derat_c.bat_k, 'o', 'Color', col_c, ...
     'MarkerFaceColor', col_c, 'MarkerSize', 6, 'HandleVisibility','off');
plot(derat_d.bat_T, derat_d.bat_k, 's', 'Color', col_d, ...
     'MarkerFaceColor', col_d, 'MarkerSize', 6, 'HandleVisibility','off');

xlabel('Temperatura bateria (°C)', 'FontSize', 12, 'FontWeight','bold');
ylabel('Factor de derating  k  [-]', 'FontSize', 12, 'FontWeight','bold');
title('Corbes de Derating de la Bateria — CAIXA vs DIRECTE', 'FontSize', 14, 'FontWeight','bold');
legend('Location','northeast','FontSize',10);
grid on; box on;
xlim([-2, 80]); ylim([-0.05, 1.15]);
set(gca,'FontSize',11,'GridAlpha',0.3,'XMinorGrid','on');

%% =========================================================
%  Figura 3 — Ambdues corbes juntes (subplots)
%% =========================================================
fig3 = figure('Name','Derating Complet T-k','NumberTitle','off', ...
              'Color','w','Position',[220 100 1100 520]);

% --- Subplot motor ---
ax1 = subplot(1,2,1);
yline(1.0,'--','Color',[0.6 0.6 0.6],'LineWidth',0.8,'HandleVisibility','off'); hold on;
yline(0.0,'--','Color',[0.6 0.6 0.6],'LineWidth',0.8,'HandleVisibility','off');
plot(derat_c.mot_T(mask_c), derat_c.mot_k(mask_c), '-', 'Color', col_c, 'LineWidth', 2.5, ...
     'DisplayName', sprintf('CAIXA  (%.0f°C)', T0_c));
plot(derat_d.mot_T(mask_d), derat_d.mot_k(mask_d), '-', 'Color', col_d, 'LineWidth', 2.5, ...
     'DisplayName', sprintf('DIRECTE (%.1f°C)', T0_d));
xline(T0_c, ':', 'Color', col_c, 'LineWidth', 1.2, 'HandleVisibility','off');
xline(T0_d, ':', 'Color', col_d, 'LineWidth', 1.2, 'HandleVisibility','off');
xlabel('T_{motor} (°C)', 'FontSize', 11, 'FontWeight','bold');
ylabel('k  [-]', 'FontSize', 11, 'FontWeight','bold');
title('Motor', 'FontSize', 13, 'FontWeight','bold');
legend('Location','northeast','FontSize',9);
grid on; box on;
xlim([115, 147]); ylim([-0.05, 1.10]);
set(ax1,'FontSize',10,'GridAlpha',0.3);

% --- Subplot bateria ---
ax2 = subplot(1,2,2);
yline(1.0,'--','Color',[0.6 0.6 0.6],'LineWidth',0.8,'HandleVisibility','off'); hold on;
yline(0.0,'--','Color',[0.6 0.6 0.6],'LineWidth',0.8,'HandleVisibility','off');
stairs(derat_c.bat_T, derat_c.bat_k, '-', 'Color', col_c, 'LineWidth', 2.5, 'DisplayName', 'CAIXA');
stairs(derat_d.bat_T, derat_d.bat_k, '-', 'Color', col_d, 'LineWidth', 2.5, 'DisplayName', 'DIRECTE');
plot(derat_c.bat_T, derat_c.bat_k, 'o', 'Color', col_c, 'MarkerFaceColor', col_c, 'MarkerSize', 6, 'HandleVisibility','off');
plot(derat_d.bat_T, derat_d.bat_k, 's', 'Color', col_d, 'MarkerFaceColor', col_d, 'MarkerSize', 6, 'HandleVisibility','off');
xlabel('T_{bateria} (°C)', 'FontSize', 11, 'FontWeight','bold');
ylabel('k  [-]', 'FontSize', 11, 'FontWeight','bold');
title('Bateria', 'FontSize', 13, 'FontWeight','bold');
legend('Location','northeast','FontSize',9);
grid on; box on;
xlim([-2, 80]); ylim([-0.05, 1.15]);
set(ax2,'FontSize',10,'GridAlpha',0.3);

sgtitle('Corbes de Derating Tèrmic — CAIXA vs DIRECTE', 'FontSize', 15, 'FontWeight','bold');

fprintf('\n✓ Figures generades:\n');
fprintf('  Fig 1 — Motor derating T-k\n');
fprintf('  Fig 2 — Bateria derating T-k\n');
fprintf('  Fig 3 — Subplots motor + bateria\n');
