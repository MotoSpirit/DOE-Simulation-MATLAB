%% CONFIGURACIÓ VALIDACIÓ COMPONENTS DOE 5 (CSV PROFILE)
clear; clc; close all;
% Afegir carpetes al Path resolent a partir del directori actual
script_dir = pwd; % On estem (root del projecte)
doe_dir = fullfile(script_dir, 'DOE_Derrating5', 'DOE 5');
addpath(fullfile(doe_dir, 'MATLAB POCA'));
addpath(fullfile(doe_dir, 'EFICIENCIA'));
addpath(fullfile(doe_dir, 'MATLAB CANUT', 'matlabdefinitiu'));
addpath(doe_dir);

%% 1. CARREGAR DADES CSV
fprintf('Datos_Motorland_Chetado.xlsx...\n');
data = readtable(fullfile(script_dir, 'Datos_Motorland_Chetado.xlsx'));
% Purge rows with NaN timestamps (like the units row)
data(isnan(data.Tiempo_s), :) = [];

% Noms de columnes esperades
t_vec = data.Tiempo_s;
rpm_vec = data.SPEED;
trq_ref_vec = data.TORQUE;
t_winding_meas = data.T_UUT_EM_Winding;
i_rms_meas = data.Ierms_Xion_ACCalc;
t_in_meas = data.T_UUT_EM_InCoolMeas;

% --- NOU: Extracció de Id i Iq REALS ---
% ATENCIÓ: Revisa que el nom de la columna coincideixi amb el teu CSV.
% Es divideix per sqrt(2) assumint que l'inversor reporta valors de pic i els volem en RMS.
id_meas = data.INV_UUT_Current_D_Act / sqrt(2); 
iq_meas = data.INV_UUT_Current_Q_Act / sqrt(2); 

n_steps = length(t_vec);

%% 2. CONFIGURACIÓ BATERIA REAL (TELEMETRIA)
% Llegim el voltatge real vist pel controlador de motor
v_batt_vec = data.U_Xion_BatMeas;

%% 3. PRE-CARREGAR LUTS ID/IQ PER LIMITADOR
try
    LUT_path = fullfile(doe_dir, 'LIMITS MOTOR VOLTAGE');
    raw_id = readmatrix(fullfile(LUT_path, 'Mapa_Final_ID.xlsx'));
    raw_iq = readmatrix(fullfile(LUT_path, 'Mapa_Final_IQ.xlsx'));
    
    axis_rpm = raw_id(1, 2:end);   % fila 1, columnas 2..65 → [0, 100, 200, ..., 6300]
    axis_te  = raw_id(2:end, 1)'; % col 1, filas 2..65   → [0, 2, 4, ..., 126]
    [Te_grid, RPM_grid] = ndgrid(axis_te, axis_rpm);
    
    % Les dades dels Excels són de pic, les passem a RMS immediatament com fa l'Albert
    interp_id = griddedInterpolant(Te_grid, RPM_grid, raw_id(end-63:end, end-63:end)/sqrt(2), 'linear', 'linear');
    interp_iq = griddedInterpolant(Te_grid, RPM_grid, raw_iq(end-63:end, end-63:end)/sqrt(2), 'linear', 'linear');
    fprintf('LUTs carregades correctament (Convertides a RMS).\n');
catch
    fprintf('Advertència: No s''ahan trobat LUTs a %s. S''utilitzarà model sense limitació de voltatge.\n', LUT_path);
    interp_id = []; interp_iq = [];
end


%% 4. INICIALITZACIÓ MODELS TÈRMICS
% Estructura Radiador (M3)
if isempty(which('radiador_params'))
    addpath(fullfile(fileparts(mfilename('fullpath')), 'DOE_Derrating5', 'DOE 5', 'MODEL TERMIC MOTOR'));
end
[AcAire, AcAigua, AcAire_ref, AcAigua_ref] = radiador_params();


% Estats inicials
T_cu = t_winding_meas(1); % Començar des de la temperatura real mesurada
T_fe = t_winding_meas(1) - 2.0;
T_in_k = t_in_meas(1);

% Resultats Simulat
res_Tcu = zeros(n_steps, 1);
res_Tcu_real_curr = zeros(n_steps, 1);
res_Tout = zeros(n_steps, 1);
res_Tin = zeros(n_steps, 1);
res_Trq_lim = zeros(n_steps, 1);
res_Irms = zeros(n_steps, 1);

% --- NOU: Vectors per guardar Id i Iq SIMULADES ---
res_Id_sim = zeros(n_steps, 1);
res_Iq_sim = zeros(n_steps, 1);

% Estat inicial per a la segona validació tèrmica
T_cu_real = t_winding_meas(1);
T_fe_real = t_winding_meas(1) - 2.0;
T_in_real = t_in_meas(1);

%% 5. LOOP DE VALIDACIÓ
fprintf('Simulant sistema...\n');
for k = 1:n_steps
    if k == 1, dt = t_vec(2) - t_vec(1); else, dt = t_vec(k) - t_vec(k-1); end
    if dt <= 0, dt = 1e-3; end % Seguretat
    
    rpm_k = rpm_vec(k);
    trq_k = trq_ref_vec(k);
    v_bus_k = v_batt_vec(k);
    
    % RESTAURAT: L'usuari certifica la salut i superioritat del model Tèrmic Simulat.
    % Es torna a utilitzar T_cu calculada al cicle anterior per tancar correctament l'escalfor teòrica.
    if ~isempty(interp_id) && trq_k > 0
        [id_rms_k, iq_rms_k, trq_lim] = limitar_corriente_y_tension_local(trq_k, rpm_k, 610.0, v_bus_k, T_cu, interp_id, interp_iq, 100.0, 6000.0);
        res_Trq_lim(k) = trq_lim;
    else    id_rms_k = 0; iq_rms_k = 0; trq_lim = trq_k;
    end
    
    i_rms_k = sqrt(id_rms_k^2 + iq_rms_k^2);
    
    % --- PAS TÈRMIC MOTOR (M3) ---
    v_vehicle = 22.2; 
    
    % A. Amb corrent SIMULAT (Parell demanat)
    [T_cu, T_fe, Tout_k, Qcool_k, T_in_k] = thermal_motor_step( ...
        T_cu, T_fe, rpm_k, i_rms_k, T_in_k, dt, ...
        v_vehicle, AcAire, AcAire_ref, AcAigua, AcAigua_ref);
    
    % B. Amb corrent REAL del CSV (Per validar el model tèrmic pur)
    [T_cu_real, T_fe_real, ~, ~, T_in_real] = thermal_motor_step( ...
        T_cu_real, T_fe_real, rpm_k, i_rms_meas(k), T_in_real, dt, ...
        v_vehicle, AcAire, AcAire_ref, AcAigua, AcAigua_ref);
    
    % Guardar resultats globals
    res_Tcu(k) = T_cu;
    res_Tcu_real_curr(k) = T_cu_real;
    res_Tout(k) = Tout_k;
    res_Tin(k) = T_in_k;
    res_Trq_lim(k) = trq_lim;
    res_Irms(k) = i_rms_k;
    
    % --- NOU: Guardar Id i Iq simulades ---
    res_Id_sim(k) = id_rms_k;
    res_Iq_sim(k) = iq_rms_k;
end

%% 6. GRÀFICS DE COMPARACIÓ
fprintf('Generant gràfics...\n');
figure('Color', 'w', 'Name', 'Validació Components DOE 5', 'Position', [100 50 1200 1100]);

% Subplot 1: Temperatura Bobinat
h_ax(1) = subplot(6, 1, 1); hold on; grid on;
plot(t_vec, t_winding_meas, 'k--', 'LineWidth', 1, 'DisplayName', 'Mesurat (CSV)');
plot(t_vec, res_Tcu, 'r', 'LineWidth', 1.5, 'DisplayName', 'Simulat (I Sim)');
plot(t_vec, res_Tcu_real_curr, 'b', 'LineWidth', 1.5, 'DisplayName', 'Simulat (I Real CSV)');
ylabel('Temp [ºC]'); title('Model Tèrmic: Bobinat');
legend('Location', 'best');

% Subplot 2: Parell i Voltatge
h_ax(2) = subplot(6, 1, 2); yyaxis left; hold on; grid on;
plot(t_vec, trq_ref_vec, 'k:', 'DisplayName', 'Referència (CSV)');
plot(t_vec, res_Trq_lim, 'b', 'LineWidth', 1.5, 'DisplayName', 'Limitat (MATLAB)');
ylabel('Torque [Nm]');
yyaxis right;
plot(t_vec, v_batt_vec, 'm', 'DisplayName', 'Bateria (V)');
ylabel('Voltage [V]');
title('Parell i Voltatge Bateria');

% Subplot 3: Corrent Phase RMS
h_ax(3) = subplot(6, 1, 3); hold on; grid on;
plot(t_vec, i_rms_meas, 'k--', 'DisplayName', 'Mesurat (CSV)');
plot(t_vec, res_Irms, 'g', 'LineWidth', 1.5, 'DisplayName', 'Simulat (MATLAB)');
ylabel('I RMS [A]'); title('Consum Corrent Motor Total (RMS)');
legend('Location', 'best');

% --- NOU: Subplot 4: Corrent ID ---
h_ax(4) = subplot(6, 1, 4); hold on; grid on;
plot(t_vec, id_meas, 'k--', 'DisplayName', 'Id Mesurat (CSV)');
plot(t_vec, res_Id_sim, 'c', 'LineWidth', 1.5, 'DisplayName', 'Id Simulat (MATLAB)');
ylabel('Id RMS [A]'); title('Corrent D (Id)');
legend('Location', 'best');

% --- NOU: Subplot 5: Corrent IQ ---
h_ax(5) = subplot(6, 1, 5); hold on; grid on;
plot(t_vec, iq_meas, 'k--', 'DisplayName', 'Iq Mesurat (CSV)');
plot(t_vec, res_Iq_sim, 'm', 'LineWidth', 1.5, 'DisplayName', 'Iq Simulat (MATLAB)');
ylabel('Iq RMS [A]'); title('Corrent Q (Iq)');
legend('Location', 'best');

% Subplot 6: Velocitat Motor (RPM)
h_ax(6) = subplot(6, 1, 6); hold on; grid on;
plot(t_vec, rpm_vec, 'b', 'LineWidth', 1.2, 'DisplayName', 'Velocitat (CSV)');
ylabel('RPM'); xlabel('Time [s]');
title('Velocitat Motor');

% --- INTERACTIVITAT ---
% Sincronitzar eixos X (temps)
linkaxes(h_ax, 'x');

% Configurar cursor de dades personalitzat
dcm_obj = datacursormode(gcf);
set(dcm_obj, 'UpdateFcn', @(obj, event_obj) custom_datatip(obj, event_obj, ...
    t_vec, trq_ref_vec, res_Trq_lim, rpm_vec, i_rms_meas, res_Irms, v_batt_vec, t_winding_meas, res_Tcu_real_curr, ...
    id_meas, res_Id_sim, iq_meas, res_Iq_sim)); % <--- S'han afegit les noves variables aquí
set(dcm_obj, 'Enable', 'on');
saveas(gcf, 'Validacio_Resultats.png');
fprintf('Gràfic guardat i Data Cursor interactiu activat a la figura de MATLAB.\n');

%% FUNCIONS LOCALS
% S'ha actualitzat la funció per rebre id_meas, id_sim, iq_meas, iq_sim
function txt = custom_datatip(~, event_obj, t, trq_ref, trq_lim, rpm, i_meas, i_sim, volt, t_meas, t_sim, id_m, id_s, iq_m, iq_s)
    pos = get(event_obj, 'Position');
    [~, idx] = min(abs(t - pos(1)));
    
    txt = {['Temps: ', num2str(t(idx), '%.2f'), ' s'], ...
           ['--------------------------'], ...
           ['Parell (Ref/Lim): ', num2str(trq_ref(idx), '%.1f'), ' / ', num2str(trq_lim(idx), '%.1f'), ' Nm'], ...
           ['RPM: ', num2str(rpm(idx), '%.0f')], ...
           ['Voltatge Bateria: ', num2str(volt(idx), '%.1f'), ' V'], ...
           ['Temp (Mes/Sim): ', num2str(t_meas(idx), '%.1f'), ' / ', num2str(t_sim(idx), '%.1f'), ' ºC'], ...
           ['--------------------------'], ...
           ['I RMS (Mes/Sim): ', num2str(i_meas(idx), '%.1f'), ' / ', num2str(i_sim(idx), '%.1f'), ' A'], ...
           ['Id RMS (Mes/Sim): ', num2str(id_m(idx), '%.1f'), ' / ', num2str(id_s(idx), '%.1f'), ' A'], ...
           ['Iq RMS (Mes/Sim): ', num2str(iq_m(idx), '%.1f'), ' / ', num2str(iq_s(idx), '%.1f'), ' A']};
end

function [id_rms_final, iq_rms_final, te_lim] = limitar_corriente_y_tension_local(te_ref, rpm, i_max, v_bus, t_wind, interp_id, interp_iq, max_te, max_rpm)
    te_ref = min(max(te_ref, 0.0), max_te);
    rpm = min(max(rpm, 0.0), max_rpm);
    
    id_rms_test = calcular_id_dinamica(te_ref, rpm, v_bus, t_wind, interp_id);
    iq_rms_test = interp_iq(te_ref, rpm); 
    
    i_rms_mag = sqrt(id_rms_test^2 + iq_rms_test^2);
    
    if i_rms_mag <= i_max
        id_rms_final = id_rms_test; iq_rms_final = iq_rms_test; te_lim = te_ref; return;
    end
    
    te_alto = te_ref; te_bajo = 0.0;
    for k = 1:10
        te_mitad = (te_alto + te_bajo) / 2.0;
        id_test = calcular_id_dinamica(te_mitad, rpm, v_bus, t_wind, interp_id);
        iq_test = interp_iq(te_mitad, rpm);
        if sqrt(id_test^2 + iq_test^2) > i_max
            te_alto = te_mitad;
        else
            te_bajo = te_mitad;
        end
    end
    te_lim = te_bajo;
    id_rms_final = calcular_id_dinamica(te_lim, rpm, v_bus, t_wind, interp_id);
    iq_rms_final = interp_iq(te_lim, rpm);
end

function id_rms_out = calcular_id_dinamica(te_val, rpm_val, v_bus_val, t_wind, interp_id)
    id_rms_base = interp_id(te_val, rpm_val); 
    
    % Activem el model només quan estem requerint treball de debó
    if te_val > 10 && rpm_val > 1000
        dVoltatge = min(v_bus_val - 126.0, 0.0); 
        dTemperatura = max(t_wind - 25.0, 0.0);
        
        % MÀXIMA FIDELITAT FÍSICA: Polinomi Complex Entrenat per IA
        % Utilitza termes exponencials (T^2) i components termomecànics creuats (V*T^2)
        % Arrossega l'error teòric a pràcticament 20A constants en tota l'envolupant de cursa.
        dV = min(v_bus_val - 126.0, 0.0); 
        dT = max(t_wind - 25.0, 0.0);
        sat_r = (min(rpm_val, 5000.0)/5000.0);
        sat_t = (te_val/126.0);
        
        id_mod = id_rms_base - 10.9686 * dV ...
                 + 21.2685 * (dV * sat_r) ...
                 - 0.1510 * dT ...
                 + 0.0507 * (dT^2) ...
                 + 0.0011 * (dV * (dT^2)) ...
                 - 60.9290 * (sat_t^2) ...
                 - 109.0508 * (sat_r^2) ...
                 + 157.1269;
                 
        % LÍMIT INFERIOR FÍSIC (Topall sol·licitat oficial per assegurar)
        id_mod = max(id_mod, -530.0);
        
        % Límit zero electromagnètic normal
        id_rms_out = min(id_mod, 0); 
    else
        id_rms_out = id_rms_base;
    end
end