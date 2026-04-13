%% =========================================================================
% M3 CIRCUIT OG — Model Motor + Radiador acoblat (M1 dinàmic + M2)
% -------------------------------------------------------------------------
% CIRCUIT TANCAT:
%   Tout_motor(k) → Radiador M2 → Tw_rad_out(k)
%   Tw_rad_out(k) → Circuit (tau_circ) → Tin_motor(k+1)
%
% Paràmetres identificats: x = [P_scale, Alpha, R_amb, R_fewat, alpha_eff, tau_circ]
% =========================================================================
clear; clc; close all;

%% =========================================================================
% BLOC 1 — CONSTANTS FÍSIQUES
%% =========================================================================
C_cu     = 807.2;           % [J/K]    capacitat tèrmica Cu
C_fe     = 32952.1;         % [J/K]    capacitat tèrmica Fe
rho_f    = 1070.0;          % [kg/m3]  densitat refrigerant (glicol 50%)
cp_f     = 3350.0;          % [J/kg·K] calor específic refrigerant
mdot     = 0.0001 * rho_f;  % = 0.107 kg/s (6 L/min)
T_amb    = 25.0;            % [°C] temperatura ambient motor
R_fase   = 0.0027;          % [Ω/fase] DATASHEET (fix)
R_cufe   = 0.0823;          % [K/W]
k_fe     = 0.099459;        % [W/rpm]
T0       = 20.586;          % [°C]
PLOSS_MIN= 50.0;            % [W]
SMOOTH_W = 11;

% Paràmetres empírics radiador (calibrats ANSYS)
A_coef = 0.423595;
A_exp  = 0.176056;
Ta_ambient = 25.0;          % [°C] temperatura ambient AIRE (≠ T_amb motor)
v_vehicle  = 33.33;         % [m/s] = 120 km/h  ← modificar si cal

% --- Geometria radiador (MODIFICA AQUÍ per canviar mida) ------------------
% Aletes (costat AIRE)
AmpladaSup       = 400-3;    % [m]  amplada nucli superior
AmpladaInf       = 210e-3;    % [m]  amplada nucli inferior
% --- PARAMETRES RADIADOR (extrets a mòdul compartit) ---
if isempty(which('radiador_params')), addpath(fullfile(pwd, '..', '..')); end
[AcAire, AcAigua, AcAire_ref, AcAigua_ref] = radiador_params();

fprintf('=== GEOMETRIA RADIADOR ===\n');
fprintf('  AcAire=%.4f m2 (Ref ANSYS: %.4f)\n', AcAire, AcAire_ref);
fprintf('  AcAigua=%.4f m2 (Ref ANSYS: %.4f)\n', AcAigua, AcAigua_ref);
fprintf('  escala_aire=%.4f | escala_aigua=%.4f | escala_geom=%.4f\n\n', ...
        AcAire/AcAire_ref, AcAigua/AcAigua_ref, ...
        sqrt((AcAire/AcAire_ref)*(AcAigua/AcAigua_ref)));

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
Tout_raw  = df.T_UUT_EM_OutCoolMeas;
Tw_raw    = df.T_UUT_EM_Winding;
Qcool_raw = df.Qcool;
I_raw     = df.Ierms_Xion_ACCalc;

valid = ~isnan(t_raw) & ~isnan(rpm_raw) & ~isnan(Tw_raw) & ...
        ~isnan(Tin_raw) & ~isnan(I_raw);
t_v        = t_raw(valid);
rpm_v      = max(rpm_raw(valid), 0);
Tin_meas   = Tin_raw(valid);
Tout_meas  = Tout_raw(valid);
Tw_meas    = Tw_raw(valid);
Qcool_meas = max(Qcool_raw(valid), 0);
I_v        = max(I_raw(valid), 0);

rpm_sm   = smoothdata(rpm_v,       'gaussian', SMOOTH_W);
I_sm     = smoothdata(I_v,         'gaussian', SMOOTH_W);
Qcool_sm = smoothdata(Qcool_meas,  'gaussian', SMOOTH_W);
Tw_sm    = smoothdata(Tw_meas,     'gaussian', SMOOTH_W);
Tin_sm   = smoothdata(Tin_meas,    'gaussian', SMOOTH_W);
Tout_sm  = smoothdata(Tout_meas,   'gaussian', SMOOTH_W);
n        = length(t_v);

fprintf('Dades: %d mostres | %.0fs (%.1f min)\n', n, t_v(end), t_v(end)/60);
fprintf('T_wind: %.1f–%.1f°C | Q_cool: %.0f–%.0f W\n\n', ...
        min(Tw_sm), max(Tw_sm), min(Qcool_sm), max(Qcool_sm));

%% =========================================================================
% BLOC 3 — IDENTIFICACIÓ fmincon (circuit tancat M1+M2)
% x = [P_scale, Alpha, R_amb, R_fewat, alpha_eff, tau_circ]
%% =========================================================================
fprintf('=== IDENTIFICACIÓ fmincon ===\n');

x0 = [1.80,  0.35,  0.15,  0.0130,  0.00393,  60.0];
%     P_scale Alpha R_amb  R_fewat  alpha_eff  tau_circ[s]
lb   = [0.50,  0.05,  0.05,  0.003,   0.001,    10.0];
ub   = [8.00,  0.80,  2.00,  0.100,   0.020,   300.0];

w_T   = 1.0;   % pes T_winding
w_Q   = 0.5;   % pes Q_cool
w_Tin = 0.3;   % pes Tin circuit

options = optimoptions('fmincon', ...
    'Display','iter', ...
    'MaxFunctionEvaluations', 3000, ...
    'MaxIterations', 200, ...
    'StepTolerance',     1e-6, ...
    'FunctionTolerance', 1e-6, ...
    'Algorithm', 'interior-point');

cost_fn = @(x) cost_circuit(x, t_v, rpm_sm, I_sm, Tw_sm, Qcool_sm, Tin_sm, ...
    R_fase, R_cufe, k_fe, T0, PLOSS_MIN, C_cu, C_fe, mdot, cp_f, T_amb, ...
    A_coef, A_exp, Ta_ambient, v_vehicle, AcAire, AcAire_ref, AcAigua, AcAigua_ref, ...
    w_T, w_Q, w_Tin);

[x_opt, J_opt] = fmincon(cost_fn, x0, [], [], [], [], lb, ub, [], options);

P_scale   = x_opt(1);
Alpha     = x_opt(2);
R_amb     = x_opt(3);
R_fewat   = x_opt(4);
alpha_eff = x_opt(5);
tau_circ  = x_opt(6);

fprintf('\n=== PARÀMETRES IDENTIFICATS ===\n');
fprintf('  P_scale   = %.5f\n',    P_scale);
fprintf('  Alpha     = %.5f\n',    Alpha);
fprintf('  R_amb     = %.5f K/W\n',R_amb);
fprintf('  R_fewat   = %.6f K/W\n',R_fewat);
fprintf('  alpha_eff = %.6f /°C\n',alpha_eff);
fprintf('  tau_circ  = %.2f s\n',  tau_circ);
fprintf('  Cost òptim J = %.6f\n\n', J_opt);

%% =========================================================================
% BLOC 4 — SIMULACIÓ FINAL amb paràmetres identificats
%% =========================================================================
[Tcu, Tout_motor, Qcool_sim, Tin_circ, Ploss_sim, Qamb_sim] = sim_circuit( ...
    x_opt, t_v, rpm_sm, I_sm, ...
    R_fase, R_cufe, k_fe, T0, PLOSS_MIN, C_cu, C_fe, mdot, cp_f, T_amb, ...
    A_coef, A_exp, Ta_ambient, v_vehicle, AcAire, AcAire_ref, AcAigua, AcAigua_ref, ...
    Tin_sm(1));

%% =========================================================================
% BLOC 5 — MÈTRIQUES
%% =========================================================================
mae_Tw  = mean(abs(Tcu        - Tw_sm));
rmse_Tw = sqrt(mean((Tcu      - Tw_sm).^2));
mae_Q   = mean(abs(Qcool_sim  - Qcool_sm));
mae_Tin = mean(abs(Tin_circ   - Tin_sm));
mae_To  = mean(abs(Tout_motor - Tout_sm));

fprintf('=== MÈTRIQUES ===\n');
fprintf('  MAE T_wind  = %.3f °C   RMSE = %.3f °C\n', mae_Tw, rmse_Tw);
fprintf('  MAE Q_cool  = %.1f W\n',  mae_Q);
fprintf('  MAE T_in    = %.4f °C\n', mae_Tin);
fprintf('  MAE T_out   = %.4f °C\n', mae_To);
fprintf('  T_wind max model=%.1f°C | mesurat=%.1f°C\n', max(Tcu), max(Tw_sm));
fprintf('  Q_cool max model=%.0fW  | mesurat=%.0fW\n\n', max(Qcool_sim), max(Qcool_sm));

%% =========================================================================
% BLOC 6 — GRÀFIQUES
%% =========================================================================
figure('Name','M3 OG: Model Motor i Radiador', ...
       'Units','normalized', 'Position',[0.02 0.02 0.96 0.95]);

subplot(5,1,1);
yyaxis left;
plot(t_v, rpm_sm, 'b-', 'LineWidth', 0.9); ylabel('RPM');
ylim([0, max(rpm_sm)*1.15]);
yyaxis right;
plot(t_v, I_sm,   'r-', 'LineWidth', 1.2); ylabel('I_{rms} [A]');
title(sprintf('Perfil Carrera — %.0fs (%.1f min)', t_v(end), t_v(end)/60));
legend('RPM','I_{rms}','Location','best','FontSize',8); grid on;

subplot(5,1,2);
plot(t_v, Tw_sm, 'k--', 'LineWidth', 1.2); 
hold on;
plot(t_v, Tcu,   'r-',  'LineWidth', 2.0);
yline(120, 'k:', 'T_{max}=120°C', 'LineWidth', 1.5, ...
      'LabelHorizontalAlignment','left','LabelVerticalAlignment','bottom');
ylabel('T_{wind} [°C]');
title(sprintf('T_{winding} | MAE=%.2f°C  RMSE=%.2f°C', mae_Tw, rmse_Tw));
legend('Mesurat','Model M3','Location','best','FontSize',8); grid on;

subplot(5,1,3);
plot(t_v, Tin_sm,   'b--', 'LineWidth', 1.2); 
hold on;
plot(t_v, Tin_circ, 'b-',  'LineWidth', 2.0);
ylabel('T_{in} [°C]');
title(sprintf('T_{in} motor | T_{out} Radiador'));
legend('Mesurat','Model (circuit tancat)','Location','best','FontSize',8); grid on;

subplot(5,1,4);
plot(t_v, Tout_sm,    'k--', 'LineWidth', 1.2);
hold on;
plot(t_v, Tout_motor, 'b-',  'LineWidth', 2.0);
ylabel('T_{out} [°C]');
title(sprintf('T_{out} motor | T_{in} Radiador'));
legend('Mesurat','Model','Location','best','FontSize',8); grid on;

subplot(5,1,5);
plot(t_v, Qcool_sm,  'k--', 'LineWidth', 1.2);
hold on; 
plot(t_v, Qcool_sim, 'm-',  'LineWidth', 2.0);
plot(t_v, Qamb_sim,  'b-',  'LineWidth', 1.5);
ylabel('Q [W]'); xlabel('Temps [s]');
title(sprintf('Q_{cool} MAE=%.1f W', mae_Q));
legend('Q_{cool} mesurat','Q_{cool} model','Q_{amb} model', ...
       'Location','best','FontSize',8); grid on;

sgtitle(sprintf('M3: Motor + Radiador MotoSpirit'));

%% =========================================================================
% FUNCIONS LOCALS
%% =========================================================================

function J = cost_circuit(x, t_v, rpm_sm, I_sm, Tw_sm, Qcool_sm, Tin_sm, ...
    R_fase, R_cufe, k_fe, T0, PLOSS_MIN, C_cu, C_fe, mdot, cp_f, T_amb, ...
    A_coef, A_exp, Ta_ambient, v_vehicle, AcAire, AcAire_ref, AcAigua, AcAigua_ref, ...
    w_T, w_Q, w_Tin)

    [Tcu, ~, Qcool_sim, Tin_circ, ~, ~] = sim_circuit(x, t_v, rpm_sm, I_sm, ...
        R_fase, R_cufe, k_fe, T0, PLOSS_MIN, C_cu, C_fe, mdot, cp_f, T_amb, ...
        A_coef, A_exp, Ta_ambient, v_vehicle, AcAire, AcAire_ref, AcAigua, AcAigua_ref, ...
        Tin_sm(1));

    sig_T   = std(Tw_sm)   + 1e-6;
    sig_Q   = std(Qcool_sm)+ 1e-6;
    sig_Tin = std(Tin_sm)  + 1e-6;

    J = w_T   * mean(abs(Tcu       - Tw_sm))   / sig_T   + ...
        w_Q   * mean(abs(Qcool_sim - Qcool_sm)) / sig_Q   + ...
        w_Tin * mean(abs(Tin_circ  - Tin_sm))   / sig_Tin;
end

% -------------------------------------------------------------------------

function [Tcu, Tout_motor, Qcool_sim, Tin_circ, Ploss_sim, Qamb_sim] = sim_circuit( ...
    x, t_v, rpm_sm, I_sm, ...
    R_fase, R_cufe, k_fe, T0, PLOSS_MIN, C_cu, C_fe, mdot, cp_f, T_amb, ...
    A_coef, A_exp, Ta_ambient, v_vehicle, AcAire, AcAire_ref, AcAigua, AcAigua_ref, ...
    Tin0)
%
%  x = [P_scale, Alpha, R_amb, R_fewat, alpha_eff, tau_circ]
%
%  Per cada pas k:
%  M1: P_joule = 3*R_fase*(1+alpha_eff*(Tcu-T0))*I^2  (R_fase fix, Datasheet)
%      P_ferro = k_fe * rpm
%      Ploss   = P_scale * (P_joule + P_ferro)
%      ODE Cu: dTcu/dt = (Alpha*Ploss - Q_int) / C_cu
%      ODE Fe: dTfe/dt = ((1-Alpha)*Ploss + Q_int - Q_ext - Q_amb) / C_fe
%  M2: Av = A_coef * v^A_exp * escala_geom
%      escala_geom = sqrt(AcAire/AcAire_ref * AcAigua/AcAigua_ref)
%      Tw_rad_out = Tout - Av*(Tout - Ta_ambient)
%  Circuit: Tin(k+1) = Tin(k) + dt/tau_circ*(Tw_rad_out - Tin(k))

    P_scale   = x(1);
    Alpha     = x(2);
    R_amb     = x(3);
    R_fewat   = x(4);
    alpha_eff = x(5);
    tau_circ  = max(x(6), 1e-3);

    n     = length(t_v);
    R_tot = R_fewat + 1.0/(mdot*cp_f);

    Tcu       = zeros(n,1);
    Tout_motor= zeros(n,1);
    Qcool_sim = zeros(n,1);
    Tin_circ  = zeros(n,1);
    Ploss_sim = zeros(n,1);
    Qamb_sim  = zeros(n,1);

    Tcu(1)      = 25.0;
    Tfe         = 23.0;
    Tin_circ(1) = Tin0;

    for k = 1:n-1
        dt = t_v(k+1) - t_v(k);
        if dt <= 0
            Tcu(k+1)      = Tcu(k);
            Tin_circ(k+1) = Tin_circ(k);
            continue;
        end

        % ── M1: motor ──────────────────────────────────────────────────
        P_joule  = 3.0 * R_fase * (1 + alpha_eff*(Tcu(k)-T0)) * I_sm(k)^2;
        P_ferro  = k_fe * rpm_sm(k);
        Ploss_k  = max(PLOSS_MIN, P_scale * (P_joule + P_ferro));
        Ploss_sim(k) = Ploss_k;

        Q_int = (Tcu(k) - Tfe)        / R_cufe;
        Q_ext = (Tfe    - Tin_circ(k)) / R_tot;
        Q_amb = (Tfe    - T_amb)       / R_amb;
        Qamb_sim(k) = Q_amb;

        Tout_motor(k) = Tin_circ(k) + Q_ext / (mdot*cp_f);
        Qcool_sim(k)  = mdot * cp_f * (Tout_motor(k) - Tin_circ(k));

        Tcu(k+1) = Tcu(k) + (Alpha*Ploss_k - Q_int) / C_cu * dt;
        Tfe      = Tfe    + ((1-Alpha)*Ploss_k + Q_int - Q_ext - Q_amb) / C_fe * dt;

        % ── M2: radiador ───────────────────────────────────────────────
        escala_aire  = AcAire  / AcAire_ref;
        escala_aigua = AcAigua / AcAigua_ref;
        escala_geom  = sqrt(escala_aire * escala_aigua);
        Av           = min(A_coef * max(v_vehicle,0)^A_exp * escala_geom, 1.0);
        Tw_rad_out   = Tout_motor(k) - Av * (Tout_motor(k) - Ta_ambient);

        % ── Circuit: primera ordre ──────────────────────────────────────
        Tin_circ(k+1) = Tin_circ(k) + dt/tau_circ * (Tw_rad_out - Tin_circ(k));
    end

    Tout_motor(end) = Tout_motor(end-1);
    Qcool_sim(end)  = Qcool_sim(end-1);
    Ploss_sim(end)  = Ploss_sim(end-1);
    Qamb_sim(end)   = Qamb_sim(end-1);
end