%% =========================================================================
% MODEL TÈRMIC MOTOR — AMB Ierms  (v10 — R_fase fixat per Datasheet)
% -------------------------------------------------------------------------
% PARÀMETRES FIXATS (Datasheet / Físics):
%   R_fase    = 0.0027 Ω/fase  ← Datasheet
%   R_cufe    = 0.0823  K/W    ← Resistència tèrmica Cu↔Fe (física)
%   k_fe      = 0.099459 W/rpm ← Pèrdues ferro proporcionals a RPM
%   T0        = 20.586 °C      ← Temperatura referència (t=0 empíric)
%   PLOSS_MIN = 50 W           ← Pèrdues mínimes de ralentí
%
% VARIABLES IDENTIFICADES per fmincon:
%   P_scale   — factor d'escala pèrdues totals (cobreix pèrdues no modelades)
%   Alpha     — fracció de pèrdues absorbida per Cu (vs. Fe)
%   R_amb     — resistència tèrmica Fe-ambient [K/W]
%   R_fewat   — resistència tèrmica Fe-refrigerant [K/W]
%   alpha_eff — coeficient tèrmic de resistència del Cu [1/°C] (identificat)
%               S'aplica ÚNICAMENT a P_joule (físicament correcte:
%               el coure augmenta R amb T; el ferro no)
% =========================================================================

clear; clc; close all;

%% =========================================================================
% BLOC 1 — CONSTANTS FÍSIQUES
%% =========================================================================
C_cu  = 807.2;          % [J/K]    Capacitat tèrmica bobinatge Cu
C_fe  = 32952.1;        % [J/K]    Capacitat tèrmica nucli Fe
rho_f = 1070.0;         % [kg/m³]  Densitat refrigerant (glicol)
cp_f  = 3350.0;         % [J/kg·K] Calor específic refrigerant
mdot  = 0.0001 * rho_f; % = 0.107 kg/s  (6 L/min × 1070 kg/m³) — CSV header
T_amb = 25.0;           % [°C]    Temperatura ambient
SMOOTH_W = 11;          % Finestra suavitzat Gaussian

% --- Paràmetres FIXATS (no identificats) ---
R_fase    = 0.0027;     % [Ω/fase] ← DATASHEET
R_cufe    = 0.0823;     % [K/W]    Resistència tèrmica Cu↔Fe (física)
k_fe      = 0.099459;   % [W/rpm]  Pèrdues ferro per RPM
T0        = 20.586;     % [°C]     Temperatura ref. (= T_winding(t=0))
PLOSS_MIN = 50.0;       % [W]      Pèrdues mínimes ralentí

fprintf('=== PARÀMETRES FIXATS ===\n');
fprintf('  R_fase    = %.4f Ω/fase  (Datasheet)\n', R_fase);
fprintf('  mdot      = %.4f kg/s   (6 L/min × %.0f kg/m³)\n', mdot, rho_f);
fprintf('  R_cufe    = %.4f K/W\n', R_cufe);
fprintf('  k_fe      = %.6f W/rpm\n', k_fe);
fprintf('  T0        = %.3f °C\n\n', T0);

%% =========================================================================
% BLOC 2 — LECTURA CSV
%% =========================================================================
filename_csv = 'PerfilMOTORLAND.csv';
opts = detectImportOptions(filename_csv);
opts.DataLines         = [3, Inf];
opts.VariableNamesLine = 1;
df = readtable(filename_csv, opts);

t_raw     = df.timestamps;
rpm_raw   = df.SPEED;
Tin_raw   = df.T_UUT_EM_InCoolMeas;
Tout_emp  = df.T_UUT_EM_OutCoolMeas;
Tw_emp    = df.T_UUT_EM_Winding;
Qcool_emp = df.Qcool;
I_raw     = df.Ierms_Xion_ACCalc;

valid = ~isnan(t_raw) & ~isnan(rpm_raw) & ~isnan(Tw_emp) & ...
        ~isnan(Tin_raw) & ~isnan(I_raw);
t_raw     = t_raw(valid);
rpm_raw   = max(rpm_raw(valid),   0);
Tin_raw   = Tin_raw(valid);
Tout_emp  = Tout_emp(valid);
Tw_emp    = Tw_emp(valid);
Qcool_emp = max(Qcool_emp(valid), 0);
I_raw     = max(I_raw(valid),     0);

rpm_sm   = smoothdata(rpm_raw,   'gaussian', SMOOTH_W);
I_sm     = smoothdata(I_raw,     'gaussian', SMOOTH_W);
Qcool_sm = smoothdata(Qcool_emp, 'gaussian', SMOOTH_W);
Tw_sm    = smoothdata(Tw_emp,    'gaussian', SMOOTH_W);
Tin_sm   = smoothdata(Tin_raw,   'gaussian', SMOOTH_W);
Tout_sm  = smoothdata(Tout_emp,  'gaussian', SMOOTH_W);

Qcool_max = max(Qcool_sm);
Tw_range  = max(Tw_sm) - min(Tw_sm);

fprintf('=== DADES (%s) ===\n', filename_csv);
fprintf('  Mostres: %d | Durada: %.0fs (%.1f min)\n', ...
        length(t_raw), t_raw(end), t_raw(end)/60);
fprintf('  I_rms:  %.1f – %.1f A\n', min(I_sm), max(I_sm));
fprintf('  RPM:    %.0f – %.0f rpm\n', min(rpm_sm), max(rpm_sm));
fprintf('  Qcool:  %.0f – %.0f W\n', min(Qcool_sm), max(Qcool_sm));
fprintf('  T_wind: %.1f – %.1f °C\n\n', min(Tw_sm), max(Tw_sm));

% Estimació P_joule de referència (sense T-corr) per validar R_fase
I_max = max(I_sm);
P_joule_ref = 3 * R_fase * I_max^2;
fprintf('  [Info] P_joule(I_max=%.0fA) = 3×%.4fΩ×%.0f² = %.0f W\n\n', ...
        I_max, R_fase, I_max, P_joule_ref);

%% =========================================================================
% BLOC 3 — IDENTIFICACIÓ (fmincon)
%
% x = [P_scale, Alpha, R_amb, R_fewat, alpha_eff]
%
% R_fase FIXAT al valor Datasheet (0.0027 Ω/fase).
% alpha_eff s'identifica i s'aplica ÚNICAMENT a P_joule.
%   Valor referència Cu pur: 0.00393 /°C
%   Rang permès [0.001, 0.050] per absorbir efectes empírics addicionals.
%
% Cost: J = MAE_Tw/Tw_range + MAE_Q/Qcool_max
%% =========================================================================
fprintf('=== IDENTIFICACIÓ (fmincon) ===\n');
fprintf('  R_fase FIXAT = %.4f Ω/fase (Datasheet)\n\n', R_fase);

%         P_scale  Alpha   R_amb   R_fewat  alpha_eff
x0 = [1.0,     0.10,   0.20,   0.0163,  0.00393];
lb = [0.5,     0.01,   0.02,   0.001,   0.001  ];
ub = [3.0,     0.50,   5.0,    0.150,   0.050  ];

cost_fn = @(x) cost_model(x, t_raw, Tin_sm, Tw_sm, Qcool_sm, ...
    rpm_sm, I_sm, Qcool_max, Tw_range, ...
    R_fase, C_cu, C_fe, R_cufe, mdot, cp_f, T_amb, ...
    k_fe, T0, PLOSS_MIN);

fmc_opts = optimoptions('fmincon', ...
    'Display','iter', 'Algorithm','interior-point', ...
    'TolFun',1e-8, 'TolX',1e-9, ...
    'MaxIterations',500, 'MaxFunctionEvaluations',5000);

x_opt = fmincon(cost_fn, x0, [], [], [], [], lb, ub, [], fmc_opts);

P_scale_opt   = x_opt(1);
Alpha_opt     = x_opt(2);
R_amb_opt     = x_opt(3);
R_fewat_opt   = x_opt(4);
alpha_eff_opt = x_opt(5);

%% =========================================================================
% BLOC 4 — SIMULACIÓ I MÈTRIQUES
%% =========================================================================
[Tcu_sim, Tout_sim, Qcool_sim] = sim_motor_I( ...
    R_fase, P_scale_opt, Alpha_opt, R_amb_opt, R_fewat_opt, alpha_eff_opt, ...
    R_cufe, C_cu, C_fe, mdot, cp_f, T_amb, ...
    k_fe, T0, PLOSS_MIN, ...
    t_raw, Tin_sm, rpm_sm, I_sm, Tw_emp(1));

mae_Tw   = mean(abs(Tcu_sim - Tw_sm));
rmse_Tw  = sqrt(mean((Tcu_sim - Tw_sm).^2));
mae_Tout = mean(abs(Tout_sim - Tout_sm));
mae_Q    = mean(abs(Qcool_sim - Qcool_sm));

fprintf('\n=== PARÀMETRES IDENTIFICATS ===\n');
fprintf('  R_fase    = %.4f Ω/fase  (FIXAT — Datasheet)\n', R_fase);
fprintf('  P_scale   = %.4f\n',      P_scale_opt);
fprintf('  Alpha     = %.4f\n',      Alpha_opt);
fprintf('  R_amb     = %.4f K/W\n',  R_amb_opt);
fprintf('  R_fewat   = %.5f K/W\n',  R_fewat_opt);
fprintf('  alpha_eff = %.5f /°C    (ref. Cu pur: 0.00393 /°C)\n\n', alpha_eff_opt);

fprintf('=== RESULTATS ===\n');
fprintf('  T_winding màx model   = %.1f °C\n', max(Tcu_sim));
fprintf('  T_winding màx empíric = %.1f °C\n', max(Tw_emp));
fprintf('  MAE  T_winding = %.3f °C\n', mae_Tw);
fprintf('  RMSE T_winding = %.3f °C\n', rmse_Tw);
fprintf('  MAE  T_out     = %.4f °C\n', mae_Tout);
fprintf('  MAE  Qcool     = %.1f W\n\n', mae_Q);

%% =========================================================================
% BLOC 5 — GRÀFIQUES
%% =========================================================================
figure('Name','M1: Model Tèrmic Motor');

% ---- Subplot 1: RPM + Corrent ----
subplot(4,1,1);
yyaxis left;
plot(t_raw, rpm_sm, 'b-', 'LineWidth', 0.9);
ylabel('RPM'); ylim([0, max(rpm_sm)*1.15]);
yyaxis right;
plot(t_raw, I_sm, 'r-', 'LineWidth', 1.2);
ylabel('I_{rms} [A]');
xlabel('Temps [s]');
title(sprintf('Perfil de Carrera — %.0fs (%.1f min)', t_raw(end), t_raw(end)/60));
legend('RPM','I_{rms}','Location','best','FontSize',8);
grid on;

% ---- Subplot 2: T_winding ----
subplot(4,1,2);
plot(t_raw, Tw_sm,   'k--', 'LineWidth', 1.2); hold on;
plot(t_raw, Tcu_sim, 'r-',  'LineWidth', 2.0);
yline(120,'k:','T_{max}=120°C','LineWidth',1.5, ...
    'LabelHorizontalAlignment','left','LabelVerticalAlignment','bottom');
ylabel('T_{winding} [°C]');
xlabel('Temps [s]');
ylim([min(Tw_emp)-5, max(max(Tcu_sim),max(Tw_emp))*1.05]);
title(sprintf('T_{winding} | MAE=%.2f°C  RMSE=%.2f°C', mae_Tw, rmse_Tw));
legend('Empíric','Model','Location','best','FontSize',8);
grid on;

% ---- Subplot 3: T_fluid ----
subplot(4,1,3);
plot(t_raw, Tin_sm,   'b--', 'LineWidth', 1.2); hold on;
plot(t_raw, Tout_sm,  'k--', 'LineWidth', 1.2);
plot(t_raw, Tout_sim, 'b-',  'LineWidth', 2.0);
ylabel('T [°C]');
xlabel('Temps [s]');
T_all = [Tin_sm; Tout_sm; Tout_sim];
ylim([min(T_all)-0.5, max(T_all)+1.5]);
title(sprintf('T_{fluid} | MAE T_{out}=%.4f°C', mae_Tout));
legend('T_{in} empíric','T_{out} empíric','T_{out} model', ...
    'Location','best','FontSize',8);
grid on;

% ---- Subplot 4: Qcool ----
subplot(4,1,4);
plot(t_raw, Qcool_sm,  'k--', 'LineWidth', 1.2); hold on;
plot(t_raw, Qcool_sim, 'm-',  'LineWidth', 2.0);
ylabel('Q_{cool} [W]');
xlabel('Temps [s]');
title(sprintf('Q_{cool} | MAE=%.1f W', mae_Q));
legend('Empíric','Model','Location','best','FontSize',8);
grid on;

sgtitle('M1: Model Tèrmic Motor');

%% =========================================================================
% FUNCIONS LOCALS
%% =========================================================================

function J = cost_model(x, t, Tin_v, Tw_ref, Qcool_ref, rpm_v, I_v, ...
    Qcool_max, Tw_range, ...
    R_fase, C_cu, C_fe, R_cufe, mdot, cp_f, T_amb, ...
    k_fe, T0, Ploss_min)
% Cost normalitzat (escales comparables):
%   J = MAE_Tw/Tw_range + MAE_Q/Qcool_max  ∈ [0, 2]

if any(x <= 0); J = 1e9; return; end

[Tcu, ~, Qcool_sim] = sim_motor_I( ...
    R_fase, x(1), x(2), x(3), x(4), x(5), ...
    R_cufe, C_cu, C_fe, mdot, cp_f, T_amb, ...
    k_fe, T0, Ploss_min, ...
    t, Tin_v, rpm_v, I_v, Tw_ref(1));

J = mean(abs(Tcu - Tw_ref))    / Tw_range + ...
    mean(abs(Qcool_sim - Qcool_ref)) / Qcool_max;
end

% -------------------------------------------------------------------------

function [Tcu, Tout, Qcool_out] = sim_motor_I( ...
    R_fase, P_scale, Alpha, R_amb, R_fewat, alpha_eff, ...
    R_cufe, C_cu, C_fe, mdot, cp_f, T_amb, ...
    k_fe, T0, Ploss_min, ...
    t, Tin_v, rpm_v, I_v, Tw_init)
%
% MODEL DE PÈRDUES (v10 — físicament correcte):
%   P_joule = 3 × R_fase × [1 + alpha_eff×(Tcu−T0)] × I²
%             ↑ resistència del Cu augmenta linealment amb temperatura
%   P_ferro = k_fe × RPM
%             ↑ pèrdues ferro: no depenen de Tcu en aquest model
%   P_total = P_scale × (P_joule + P_ferro)
%             ↑ P_scale absorbeix pèrdues addicionals (fricció, etc.)
%
% MODEL TÈRMIC (2 nodes: Cu i Fe):
%   C_cu × dTcu/dt = Alpha×P     − (Tcu−Tfe)/R_cufe
%   C_fe × dTfe/dt = (1−Alpha)×P + (Tcu−Tfe)/R_cufe
%                                − (Tfe−Tin)/R_tot
%                                − (Tfe−Tamb)/R_amb
%
% CIRCUIT REFRIGERANT:
%   R_tot = R_fewat + 1/(mdot×cp_f)   [K/W]
%   Tout  = Tin + Q_ext/(mdot×cp_f)
%   Qcool = mdot×cp_f×(Tout−Tin)

R_tot = R_fewat + 1.0/(mdot*cp_f);
n = length(t);
Tcu       = zeros(n,1);
Tout      = zeros(n,1);
Qcool_out = zeros(n,1);
Tcu(1) = Tw_init;
Tfe    = Tw_init - 2.0;   % Tfe inicial lleugerament per sota Tcu

for k = 1:n-1
    dt = t(k+1) - t(k);
    if dt <= 0; Tcu(k+1) = Tcu(k); continue; end

    % --- Pèrdues (alpha_eff ÚNICAMENT a P_joule) ---
    P_joule = 3.0 * R_fase * (1 + alpha_eff*(Tcu(k) - T0)) * I_v(k)^2;
    P_ferro = k_fe * rpm_v(k);
    Ploss_k = max(Ploss_min, P_scale * (P_joule + P_ferro));

    % --- Fluxos tèrmics ---
    Q_int = (Tcu(k) - Tfe)    / R_cufe;   % Cu → Fe
    Q_ext = (Tfe - Tin_v(k))  / R_tot;    % Fe → refrigerant
    Q_amb = (Tfe - T_amb)     / R_amb;    % Fe → ambient

    % --- Temperatura sortida refrigerant ---
    Tout(k)      = Tin_v(k) + Q_ext / (mdot*cp_f);
    Qcool_out(k) = mdot * cp_f * (Tout(k) - Tin_v(k));

    % --- Integració Euler directa ---
    Tcu(k+1) = Tcu(k) + (Alpha*Ploss_k - Q_int)                         / C_cu * dt;
    Tfe      = Tfe    + ((1-Alpha)*Ploss_k + Q_int - Q_ext - Q_amb)     / C_fe * dt;
end

Tout(end)      = Tout(end-1);
Qcool_out(end) = Qcool_out(end-1);
end
