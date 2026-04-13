%% VALIDACIÓ COMPARATIVA POWERTRAIN DOE 5
% Comparativa de models tèrmics (M1v10 vs M3) utilitzant el corrent REAL del CSV.
% -------------------------------------------------------------------------

clear; clc; close all;

% Afegir carpetes al Path
script_dir = pwd;
doe_dir = fullfile(script_dir, 'DOE_Derrating5', 'DOE 5');
addpath(fullfile(doe_dir, 'BATERIA'));
addpath(fullfile(doe_dir, 'EFICIENCIA'));
addpath(fullfile(doe_dir, 'FÍSICA', 'matlabdefinitiu'));
addpath(doe_dir);

%% 1. CARREGAR DADES CSV (Dades Banc)
fprintf('Carregant PerfilMOTORLAND.csv...\n');
data = readtable(fullfile(script_dir, 'PerfilMOTORLAND.csv'));
data(isnan(data.timestamps), :) = []; 

t_vec          = data.timestamps;
rpm_vec        = data.SPEED;
trq_ref_vec    = data.TORQUE;
t_winding_meas = data.T_UUT_EM_Winding;
i_rms_meas     = data.Ierms_Xion_ACCalc;
t_in_meas      = data.T_UUT_EM_InCoolMeas;
n_steps        = length(t_vec);

%% 2. PARÀMETRES MODÈLS TÈRMICS
% --- Model M1v10 (Nou Identificat) ---
P_scale_m1   = 2.9908;  Alpha_m1     = 0.1629;
R_amb_m1     = 0.0203;  R_fewat_m1   = 0.01805;
alpha_eff_m1 = 0.00729;

% --- Model M3 (Anterior OGv4 - Circuit Tancat) ---
P_scale_m3   = 1.80;    Alpha_m3     = 0.35;
R_amb_m3     = 0.15;    R_fewat_m3   = 0.0130;
alpha_eff_m3 = 0.00393;
tau_circ     = 60.0;    A_coef_rad   = 0.423595; A_exp_rad = 0.176056; 
v_vehicle    = 22.22;   Ta_aire = 25.0;
if isempty(which('radiador_params')), addpath(fullfile(fileparts(mfilename('fullpath')), 'DOE_Derrating5', 'DOE 5', 'MODEL TERMIC MOTOR')); end
[AcAire_m3, AcAigua_m3, AcAire_ref, AcAigua_ref] = radiador_params();

% Constants Físiques (Comuns)
C_cu      = 807.2;    C_fe      = 32952.1;
R_cufe    = 0.0823;   R_fase    = 0.0027;
k_fe      = 0.099459; T0_ref    = 20.586;
mdot      = 0.1070;   cp_f      = 3350.0;
T_amb     = 25.0;     Ploss_min = 50.0;

% Resistències derivades
R_tot_m1 = R_fewat_m1 + 1.0/(mdot * cp_f);
R_tot_m3 = R_fewat_m3 + 1.0/(mdot * cp_f);

% Inicialització Estats
T_cu_m1 = t_winding_meas(1); T_fe_m1 = t_winding_meas(1) - 2.0;
T_cu_m3 = t_winding_meas(1); T_fe_m3 = t_winding_meas(1) - 2.0;
Tin_sim_m3 = t_in_meas(1);

% Resultats
res_Tcu_m1  = zeros(n_steps, 1);
res_Tcu_m3  = zeros(n_steps, 1);
res_Tin_m3  = zeros(n_steps, 1);
res_Tout_m1 = zeros(n_steps, 1);
res_Tout_m3 = zeros(n_steps, 1);

%% 3. SIMULACIÓ AMB CORRENT REAL (Validació)
fprintf('Validant models amb Irms real del CSV...\n');
for k = 1:n_steps
    if k == 1, dt = t_vec(2) - t_vec(1); else, dt = t_vec(k) - t_vec(k-1); end
    if dt <= 0, dt = 1e-3; end
    
    rpm_k   = rpm_vec(k);
    i_rms_k = i_rms_meas(k); % <--- USANT CORRENT REAL
    Tin_k   = t_in_meas(k);  % Entrada M1
    
    % --- Pas Tèrmic Model M1v10 ---
    Pj_m1 = 3.0 * R_fase * (1 + alpha_eff_m1*(T_cu_m1 - T0_ref)) * i_rms_k^2;
    Ploss_m1 = max(Ploss_min, P_scale_m1 * (Pj_m1 + k_fe*rpm_k));
    Q_int_m1 = (T_cu_m1 - T_fe_m1) / R_cufe;
    Q_ext_m1 = (T_fe_m1 - Tin_k) / R_tot_m1;
    Q_amb_m1 = (T_fe_m1 - T_amb) / R_amb_m1;
    T_cu_m1 = T_cu_m1 + (Alpha_m1 * Ploss_m1 - Q_int_m1) / C_cu * dt;
    T_fe_m1 = T_fe_m1 + ((1-Alpha_m1)*Ploss_m1 + Q_int_m1 - Q_ext_m1 - Q_amb_m1) / C_fe * dt;
    res_Tout_m1(k) = Tin_k + Q_ext_m1 / (mdot * cp_f);
    
    % --- Pas Tèrmic Model M3 (Circuit Tancat) ---
    Pj_m3 = 3.0 * R_fase * (1 + alpha_eff_m3*(T_cu_m3 - T0_ref)) * i_rms_k^2;
    Ploss_m3 = max(Ploss_min, P_scale_m3 * (Pj_m3 + k_fe*rpm_k));
    Q_int_m3 = (T_cu_m3 - T_fe_m3) / R_cufe;
    Q_ext_m3 = (T_fe_m3 - Tin_sim_m3) / R_tot_m3;
    Q_amb_m3 = (T_fe_m3 - T_amb) / R_amb_m3;
    T_cu_m3 = T_cu_m3 + (Alpha_m3 * Ploss_m3 - Q_int_m3) / C_cu * dt;
    T_fe_m3 = T_fe_m3 + ((1-Alpha_m3)*Ploss_m3 + Q_int_m3 - Q_ext_m3 - Q_amb_m3) / C_fe * dt;
    Tout_m3 = Tin_sim_m3 + Q_ext_m3 / (mdot * cp_f);
    
    % Actualització Radiador M3
    escala_geom = sqrt((AcAire_m3/AcAire_ref) * (AcAigua_m3/AcAigua_ref));
    Av = min(A_coef_rad * v_vehicle^A_exp_rad * escala_geom, 1.0);
    Tw_rad_out = Tout_m3 - Av * (Tout_m3 - Ta_aire);
    Tin_sim_m3 = Tin_sim_m3 + (dt / tau_circ) * (Tw_rad_out - Tin_sim_m3);
    
    % Guardar Resultats
    res_Tcu_m1(k) = T_cu_m1;
    res_Tcu_m3(k) = T_cu_m3;
    res_Tin_m3(k) = Tin_sim_m3;
    res_Tout_m3(k) = Tout_m3;
end

%% 4. GRÀFICS DE VALIDACIÓ
fprintf('Generant gràfics de validació...\n');
figure('Color', 'w', 'Name', 'Validació: Models Tèrmics amb Irms Real', 'WindowState', 'maximized');

h_ax(1) = subplot(5,1,1); hold on; grid on;
plot(t_vec, t_winding_meas, 'k--', 'DisplayName', 'Real (CSV)');
plot(t_vec, res_Tcu_m1, 'r', 'LineWidth', 1.5, 'DisplayName', 'Model M1v10');
plot(t_vec, res_Tcu_m3, 'b:', 'LineWidth', 1.5, 'DisplayName', 'Model M3 (OGv4)');
ylabel('Temp [ºC]'); title('Validació Temperatura Motor (T-Winding)'); legend show;

h_ax(2) = subplot(5,1,2); hold on; grid on;
plot(t_vec, i_rms_meas, 'k', 'LineWidth', 1.2, 'DisplayName', 'RMS (CSV)');
ylabel('I RMS [A]'); title('Corrent de Fase d''Entrada (Ground Truth)'); legend show;

h_ax(3) = subplot(5,1,3); hold on; grid on;
plot(t_vec, rpm_vec, 'b', 'DisplayName', 'Speed');
ylabel('RPM'); title('Velocitat del Motor'); legend show;

h_ax(4) = subplot(5,1,4); hold on; grid on;
plot(t_vec, t_in_meas, 'r', 'LineWidth', 1.2, 'DisplayName', 'Tin (CSV/M1)');
plot(t_vec, res_Tin_m3, 'b:', 'LineWidth', 1.5, 'DisplayName', 'Tin (M3 Sim)');
ylabel('Temp [ºC]'); title('Temperatures d''Entrada (Tin)'); legend show;

h_ax(5) = subplot(5,1,5); hold on; grid on;
plot(t_vec, res_Tout_m1, 'r', 'LineWidth', 1.2, 'DisplayName', 'Tout (M1v10)');
plot(t_vec, res_Tout_m3, 'b:', 'LineWidth', 1.2, 'DisplayName', 'Tout (M3)');
ylabel('Temp [ºC]'); xlabel('Time [s]'); title('Temperatures de Sortida (Tout)'); legend show;

linkaxes(h_ax, 'x'); dcm_obj = datacursormode(gcf);
set(dcm_obj, 'UpdateFcn', @(obj, ev) custom_datatip(obj, ev, t_vec, i_rms_meas, t_winding_meas, res_Tcu_m1, res_Tcu_m3, t_in_meas, res_Tin_m3));
saveas(gcf, 'Validacio_Comparativa_IrmsReal.png');
fprintf('Validació completada.\n');

%% FUNCIONS LOCALS
function txt = custom_datatip(~, ev, t, i_rms, tw_meas, t_m1, t_m3, tin_meas, tin_m3)
    pos = get(ev, 'Position'); [~,idx] = min(abs(t - pos(1)));
    txt = {['Temps: ', num2str(t(idx), '%.2f'), ' s'], ...
           ['I RMS Real: ', num2str(i_rms(idx), '%.1f'), ' A'], ...
           ['Temp Wind Real: ', num2str(tw_meas(idx), '%.1f'), ' ºC'], ...
           ['Temp M1v10: ', num2str(t_m1(idx), '%.1f'), ' ºC'], ...
           ['Temp M3 OG: ', num2str(t_m3(idx), '%.1f'), ' ºC'], ...
           ['Tin (CSV / Sim M3): ', num2str(tin_meas(idx), '%.1f'), ' / ', num2str(tin_m3(idx), '%.1f'), ' ºC']};
end
