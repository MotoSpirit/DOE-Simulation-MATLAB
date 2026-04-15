% function resultat = simulacio_moto_canut(parametres, dt, funcio_parell, rpm_min, rpm_max)
% 
% %% BLOC 1 - CARREGAR DADES
% taula_seg   = readtable('zones_motorland.xlsx', 'Sheet', 'Segments');
% taula_gas   = readtable('zones_motorland.xlsx', 'Sheet', 'Factor_Gas');
% volta_ideal = readtable('Volta_Ideal_MOTOSPIRIT.xlsx');
% 
% metres_ref  = volta_ideal.Distancia_m;
% vel_ref     = volta_ideal.Speed_m_s;
% alt_ref     = volta_ideal.Altitud_m_;
% gas_ref     = taula_gas.Factor_Gas;
% metres_gas  = taula_gas.Metre;
% 
% pendent_ref     = (gradient(alt_ref) ./ max(gradient(metres_ref), 1e-6)) * 100;
% distancia_total = metres_ref(end);
% 
% %% BLOC 2 - PARÀMETRES I INICIALITZACIÓ
% M      = parametres.M_total;
% Cd     = parametres.Cd;
% A      = parametres.Area_Frontal;
% rho    = parametres.rho;
% Cr     = parametres.Coeficient_rodadura;
% R_roda = parametres.Radi_roda;
% rend   = parametres.Rendiment_total;
% g      = 9.81;
% 
% % Ratios de transmissió per cada marxa
% if isfield(parametres, 'Ratio_primera')
%     ratios = parametres.Ratio_primaria .* ...
%              [parametres.Ratio_primera, parametres.Ratio_segona, parametres.Ratio_tercera, ...
%               parametres.Ratio_quarta,  parametres.Ratio_cinquena] .* ...
%              parametres.Ratio_secundaria;
% else
%     ratios = parametres.Ratio_primaria;
% end
% 
% % Pre-assignar arrays
% n_max     = 20000;
% res_temps = zeros(n_max, 1);
% res_vel   = zeros(n_max, 1);
% res_rpm   = zeros(n_max, 1);
% res_gas   = zeros(n_max, 1);
% res_mode  = zeros(n_max, 1);
% res_dist  = zeros(n_max, 1);
% res_marxa = zeros(n_max, 1);
% 
% % Condicions inicials
% v_actual = interp1(metres_ref, vel_ref, 0, 'linear', 'extrap');
% t_actual = 0;
% d_actual = 0;
% idx      = 0;
% 
% % Marxa inicial segons velocitat (la més petita possible dins del rang)
% marxa_actual = 1;
% for m = 1:length(ratios)
%     rpm_test = (v_actual * ratios(m) * 60) / (2 * pi * R_roda);
%     if rpm_test >= rpm_min && rpm_test <= rpm_max
%         marxa_actual = m;
%         break;
%     end
% end
% ratio_t = ratios(marxa_actual);
% 
% % Canvi de marxa
% t_bloqueig       = 0.5;
% t_sense_empenyer = 0.08;
% canvi_en_curs    = false;
% t_inici_canvi    = 0;
% 
% %% BLOC 3 - BUCLE PRINCIPAL
% while d_actual < distancia_total
% 
%     % Comprovar si hem d'acabar el bloqueig de canvi
%     if canvi_en_curs && (t_actual - t_inici_canvi) >= t_bloqueig
%         canvi_en_curs = false;
%     end
% 
%     % Consultar mode d'aquest metre
%     mode_actual = 'FISICA';
%     for j = 1:height(taula_seg)
%         if d_actual >= taula_seg.Metre_Inici(j) && ...
%            d_actual <= taula_seg.Metre_Final(j)
%             mode_actual = taula_seg.Mode{j};
%             break;
%         end
%     end
% 
%     if strcmp(mode_actual, 'COPIA')
%         % --- MODE CÒPIA ---
%         v_actual   = interp1(metres_ref, vel_ref, d_actual, 'linear', 'extrap');
%         gas_actual = interp1(metres_gas, gas_ref, d_actual, 'linear', 'extrap');
% 
%         % Assegurar que la marxa és coherent (mai 1a en CÒPIA si hi ha caixa de canvis)
%         if length(ratios) > 1
%             for m = 2:length(ratios)
%                 rpm_test = (v_actual * ratios(m) * 60) / (2 * pi * R_roda);
%                 if rpm_test >= rpm_min && rpm_test <= rpm_max
%                     marxa_actual = m;
%                     ratio_t      = ratios(marxa_actual);
%                     break;
%                 end
%             end
%         end
% 
%     else
%         % --- MODE FÍSICA ---
% 
%         % Forces resistents
%         angle  = atan(interp1(metres_ref, pendent_ref, d_actual, 'linear', 'extrap') / 100);
%         f_grav = M * g * sin(angle);
%         f_roll = M * g * cos(angle) * Cr;
%         f_aero = 0.5 * rho * Cd * A * v_actual^2;
%         f_res  = f_grav + f_roll + f_aero;
% 
%         % Força del motor (zero els primers 0.08s del canvi)
%         if canvi_en_curs && (t_actual - t_inici_canvi) < t_sense_empenyer
%             f_motor    = 0;
%             gas_actual = 0;
%         else
%             gas_actual = interp1(metres_gas, gas_ref, d_actual, 'linear', 'extrap');
%             gas_actual = min(max(gas_actual, 0), 1);
%             rpm_actual = (v_actual * ratio_t * 60) / (2 * pi * R_roda);
%             parell_max = funcio_parell(max(rpm_actual, 100));
%             f_motor    = parell_max * gas_actual * ratio_t * rend / R_roda;
%         end
% 
%         % Acceleració i nova velocitat
%         accel    = (f_motor - f_res) / M;
%         v_actual = max(v_actual + accel * dt, 0.1);
%     end
% 
%     % RPM actuals
%     rpm_actual = (v_actual * ratio_t * 60) / (2 * pi * R_roda);
% 
%     % Canvi de marxes (només si hi ha caixa de canvis i no estem en mig d'un canvi)
%     if length(ratios) > 1 && ~canvi_en_curs
%         if rpm_actual > rpm_max && marxa_actual < length(ratios)
%             marxa_actual  = marxa_actual + 1;
%             ratio_t       = ratios(marxa_actual);
%             canvi_en_curs = true;
%             t_inici_canvi = t_actual;
%         elseif rpm_actual < rpm_min && marxa_actual > 2
%             marxa_actual  = marxa_actual - 1;
%             ratio_t       = ratios(marxa_actual);
%             canvi_en_curs = true;
%             t_inici_canvi = t_actual;
%         end
%     end
% 
%     % Avançar posició i temps
%     d_actual = d_actual + v_actual * dt;
%     t_actual = t_actual + dt;
% 
%     % Guardar resultats
%     idx = idx + 1;
%     if idx > n_max
%         error('Array ple: augmenta n_max o redueix dt');
%     end
%     res_temps(idx) = t_actual;
%     res_vel(idx)   = v_actual;
%     res_rpm(idx)   = rpm_actual;
%     res_gas(idx)   = gas_actual;
%     res_mode(idx)  = double(strcmp(mode_actual, 'FISICA'));
%     res_dist(idx)  = d_actual;
%     res_marxa(idx) = marxa_actual;
% 
% end
% 
% %% BLOC 4 - RESULTATS
% idx_valid = 1:idx;
% 
% resultat.temps_total   = t_actual;
% resultat.temps         = res_temps(idx_valid);
% resultat.velocitat_kmh = res_vel(idx_valid) * 3.6;
% resultat.rpm           = res_rpm(idx_valid);
% resultat.gas           = res_gas(idx_valid);
% resultat.mode          = res_mode(idx_valid);
% resultat.distancia     = res_dist(idx_valid);
% resultat.marxa         = res_marxa(idx_valid);
% 
% end
% 
% --------------------------------------------------------------------------------------------------------

% function resultat = simulacio_moto_canut(parametres, dt, funcio_parell, rpm_min, rpm_max)
% 
% %% BLOC 1 - CARREGAR DADES
% taula_seg   = readtable('zones_motorland.xlsx', 'Sheet', 'Segments');
% taula_gas   = readtable('zones_motorland.xlsx', 'Sheet', 'Factor_Gas');
% taula_rec   = readtable('zones_motorland.xlsx', 'Sheet', 'Rectes_Frenada');
% volta_ideal = readtable('Volta_Ideal_MOTOSPIRIT.xlsx');
% 
% metres_ref  = volta_ideal.Distancia_m;
% vel_ref     = volta_ideal.Speed_m_s;
% alt_ref     = volta_ideal.Altitud_m_;
% gas_ref     = taula_gas.Factor_Gas;
% metres_gas  = taula_gas.Metre;
% 
% pendent_ref     = (gradient(alt_ref) ./ max(gradient(metres_ref), 1e-6)) * 100;
% distancia_total = metres_ref(end);
% 
% %% BLOC 2 - PARÀMETRES I INICIALITZACIÓ
% M      = parametres.M_total;
% Cd     = parametres.Cd;
% A      = parametres.Area_Frontal;
% rho    = parametres.rho;
% Cr     = parametres.Coeficient_rodadura;
% R_roda = parametres.Radi_roda;
% rend   = parametres.Rendiment_total;
% g      = 9.81;
% 
% if isfield(parametres, 'Ratio_primera')
%     ratios = parametres.Ratio_primaria .* ...
%              [parametres.Ratio_primera, parametres.Ratio_segona, parametres.Ratio_tercera, ...
%               parametres.Ratio_quarta,  parametres.Ratio_cinquena] .* ...
%              parametres.Ratio_secundaria;
% else
%     ratios = parametres.Ratio_primaria;
% end
% 
% n_max     = 20000;
% res_temps = zeros(n_max, 1);
% res_vel   = zeros(n_max, 1);
% res_rpm   = zeros(n_max, 1);
% res_gas   = zeros(n_max, 1);
% res_mode  = zeros(n_max, 1);
% res_dist  = zeros(n_max, 1);
% res_marxa = zeros(n_max, 1);
% 
% v_actual = interp1(metres_ref, vel_ref, 0, 'linear', 'extrap');
% t_actual = 0;
% d_actual = 0;
% idx      = 0;
% 
% marxa_actual = 1;
% for m = 1:length(ratios)
%     rpm_test = (v_actual * ratios(m) * 60) / (2 * pi * R_roda);
%     if rpm_test >= rpm_min && rpm_test <= rpm_max
%         marxa_actual = m;
%         break;
%     end
% end
% ratio_t = ratios(marxa_actual);
% 
% t_bloqueig       = 0.5;
% t_sense_empenyer = 0.08;
% canvi_en_curs    = false;
% t_inici_canvi    = 0;
% 
% copia_activa  = false;
% copia_seg_idx = 0;
% copia_rec_idx = 0;
% 
% %% BLOC 3 - BUCLE PRINCIPAL
% while d_actual < distancia_total
% 
%     if canvi_en_curs && (t_actual - t_inici_canvi) >= t_bloqueig
%         canvi_en_curs = false;
%     end
% 
%     %% DETERMINAR MODE
%     if copia_activa
%         d_final_seg = taula_seg.Metre_Final(copia_seg_idx);
%         if d_actual > d_final_seg
%             copia_activa  = false;
%             copia_seg_idx = 0;
%             copia_rec_idx = 0;
%         end
%         mode_actual = 'COPIA';
% 
%     else
%         mode_actual = 'FISICA';
% 
%         v_kmh = v_actual * 3.6;
%         for k = 1:height(taula_rec)
%             d_ini_rec = taula_rec.Metre_Inici_Recta(k);
%             d_fin_rec = taula_rec.Metre_Final_Recta(k);
% 
%             if d_actual < d_ini_rec || d_actual > d_fin_rec
%                 continue;
%             end
% 
%             pendent_rec = taula_rec.Pendent(k);
%             v_ini_rec   = taula_rec.V_Inici_Recta(k);
%             d_ini_extrap = taula_rec.Metre_Inici_Recta(k);
%             v_recta_kmh = v_ini_rec + pendent_rec * (d_actual - d_ini_extrap);
% 
%             if v_kmh >= v_recta_kmh
%                 copia_activa  = true;
%                 copia_seg_idx = taula_rec.Segment(k);
%                 copia_rec_idx = k;
%                 mode_actual   = 'COPIA';
%                 break;
%             end
%         end
%     end
% 
%     %% FÍSICA O CÒPIA
%     if strcmp(mode_actual, 'COPIA')
%         v_ideal    = interp1(metres_ref, vel_ref, d_actual, 'linear', 'extrap');
%         gas_actual = interp1(metres_gas, gas_ref, d_actual, 'linear', 'extrap');
% 
%         if v_actual > v_ideal && copia_rec_idx > 0
%             % Frenar amb la pendent de la recta de frenada fins arribar a la ideal
%             pendent_rec_ms = taula_rec.Pendent(copia_rec_idx) / 3.6; % km/h/m → m/s/m
%             v_actual = v_actual + pendent_rec_ms * v_actual * dt;
%             v_actual = max(v_actual, v_ideal);
%         else
%             % Ja per sota o igual → copiar directament
%             v_actual = v_ideal;
%         end
% 
%         if length(ratios) > 1
%             for m = 2:length(ratios)
%                 rpm_test = (v_actual * ratios(m) * 60) / (2 * pi * R_roda);
%                 if rpm_test >= rpm_min && rpm_test <= rpm_max
%                     marxa_actual = m;
%                     ratio_t      = ratios(marxa_actual);
%                     break;
%                 end
%             end
%         end
% 
%     else
%         %% MODE FÍSICA
%         angle  = atan(interp1(metres_ref, pendent_ref, d_actual, 'linear', 'extrap') / 100);
%         f_grav = M * g * sin(angle);
%         f_roll = M * g * cos(angle) * Cr;
%         f_aero = 0.5 * rho * Cd * A * v_actual^2;
%         f_res  = f_grav + f_roll + f_aero;
% 
%         if canvi_en_curs && (t_actual - t_inici_canvi) < t_sense_empenyer
%             f_motor    = 0;
%             gas_actual = 0;
%         else
%             gas_actual = interp1(metres_gas, gas_ref, d_actual, 'linear', 'extrap');
%             gas_actual = min(max(gas_actual, 0), 1);
%             rpm_actual = (v_actual * ratio_t * 60) / (2 * pi * R_roda);
%             parell_max = funcio_parell(max(rpm_actual, 100));
%             f_motor    = parell_max * gas_actual * ratio_t * rend / R_roda;
%         end
% 
%         accel    = (f_motor - f_res) / M;
%         v_actual = max(v_actual + accel * dt, 0.1);
%     end
% 
%     %% RPM I CANVI DE MARXES
%     rpm_actual = (v_actual * ratio_t * 60) / (2 * pi * R_roda);
% 
%     if length(ratios) > 1 && ~canvi_en_curs
%         if rpm_actual > rpm_max && marxa_actual < length(ratios)
%             marxa_actual  = marxa_actual + 1;
%             ratio_t       = ratios(marxa_actual);
%             canvi_en_curs = true;
%             t_inici_canvi = t_actual;
%         elseif rpm_actual < rpm_min && marxa_actual > 2
%             marxa_actual  = marxa_actual - 1;
%             ratio_t       = ratios(marxa_actual);
%             canvi_en_curs = true;
%             t_inici_canvi = t_actual;
%         end
%     end
% 
%     %% AVANÇAR
%     d_actual = d_actual + v_actual * dt;
%     t_actual = t_actual + dt;
% 
%     idx = idx + 1;
%     if idx > n_max
%         error('Array ple: augmenta n_max o redueix dt');
%     end
%     res_temps(idx) = t_actual;
%     res_vel(idx)   = v_actual;
%     res_rpm(idx)   = rpm_actual;
%     res_gas(idx)   = gas_actual;
%     res_mode(idx)  = double(strcmp(mode_actual, 'FISICA'));
%     res_dist(idx)  = d_actual;
%     res_marxa(idx) = marxa_actual;
% end
% 
% %% BLOC 4 - RESULTATS
% idx_valid = 1:idx;
% resultat.temps_total   = t_actual;
% resultat.temps         = res_temps(idx_valid);
% resultat.velocitat_kmh = res_vel(idx_valid) * 3.6;
% resultat.rpm           = res_rpm(idx_valid);
% resultat.gas           = res_gas(idx_valid);
% resultat.mode          = res_mode(idx_valid);
% resultat.distancia     = res_dist(idx_valid);
% resultat.marxa         = res_marxa(idx_valid);
% 
% %% V_MAX TEÒRICA
% ratio_final = ratios(end);
% v_low = 0.1; v_high = 120;
% for iter = 1:100
%     v_mid   = (v_low + v_high) / 2;
%     rpm_mid = (v_mid * ratio_final * 60) / (2 * pi * R_roda);
%     parell  = funcio_parell(max(rpm_mid, 100));
%     f_motor = parell * ratio_final * rend / R_roda;
% resultat.v_max_kmh = ((v_low + v_high) / 2) * 3.6;
% 
% end

function resultat = simulacio_moto_canut(parametres, dt, funcio_parell_base, rpm_min, rpm_max, num_voltes, cond_ini)

% Verificació que els mòduls elèctrics standalone són accessibles al path de MATLAB.
% Normalment els afegeix Script_DOE_5.m a l'inici. Si no, intentem trobar-los.
if isempty(which('calcular_id_dinamica'))
    this_dir = fileparts(mfilename('fullpath'));
    candidate = fullfile(this_dir, '..', '..', 'LIMITS MOTOR VOLTAGE');
    if isfolder(candidate)
        addpath(candidate);
    else
        error('simulacio_moto_canut: No es troba calcular_id_dinamica.m.\nAfegeix la carpeta LIMITS MOTOR VOLTAGE al path de MATLAB.');
    end
end
if isempty(which('radiador_params'))
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'MODEL TERMIC MOTOR'));
end

%% BLOC 1 - CARREGAR DADES
taula_seg   = readtable('zones_motorland.xlsx', 'Sheet', 'Segments');
taula_gas_moto = readtable('zones_motorland.xlsx', 'Sheet', 'Factor_Gas_Motospirit');
taula_gas_vila = readtable('zones_motorland.xlsx', 'Sheet', 'Factor_Gas_Vilanova');

if isfield(parametres, 'Ratio_primera')
    % Config: CAIXA -> Motospirit
    gas_ref    = taula_gas_moto.Factor_Gas_MOTOSPIRIT;
    metres_gas = taula_gas_moto.Metre;
else
    % Config: DIRECTE -> Vilanova
    gas_ref    = taula_gas_vila.Factor_Gas_VILANOVA;
    metres_gas = taula_gas_vila.Metre;
end

taula_rec   = readtable('zones_motorland.xlsx', 'Sheet', 'Rectes_Frenada');
volta_ideal = readtable('Volta_Ideal_MOTOSPIRIT.xlsx');

metres_ref  = volta_ideal.Distancia_m;
vel_ref     = volta_ideal.Speed_m_s;
alt_ref     = volta_ideal.Altitud_m_;
% gas_ref and metres_gas are assigned above based on configuration


pendent_ref     = (gradient(alt_ref) ./ max(gradient(metres_ref), 1e-6)) * 100;
distancia_lap   = metres_ref(end);
distancia_total = distancia_lap * num_voltes;

%% BLOC 2 - PARÀMETRES I INICIALITZACIÓ
M      = parametres.M_total;
Cd     = parametres.Cd;
A      = parametres.Area_Frontal;
rho    = parametres.rho;
Cr     = parametres.Coeficient_rodadura;
R_roda = parametres.Radi_roda;
rend   = parametres.Rendiment_total;
g      = 9.81;

if isfield(parametres, 'Ratio_primera')
    ratios = parametres.Ratio_primaria .* ...
             [parametres.Ratio_primera, parametres.Ratio_segona, parametres.Ratio_tercera, ...
              parametres.Ratio_quarta,  parametres.Ratio_cinquena] .* ...
             parametres.Ratio_secundaria;
else
    ratios = parametres.Ratio_primaria;
end

% Masses equivalents per marxa (M_total + inèrcies rotacionals reduïdes)
if isfield(parametres, 'Ratio_primera')
    % Moto amb caixa de canvis
    masses_eq = M + [parametres.massa_efectiva1, parametres.massa_efectiva2, ...
                     parametres.massa_efectiva3, parametres.massa_efectiva4, ...
                     parametres.massa_efectiva5];
else
    % Moto sense caixa
    masses_eq = M + parametres.massa_efectiva;
end

% --- GESTIÓ DE CONDICIONS INICIALS TÈRMIQUES (Real-Time Derating) ---
if nargin < 7 || isempty(cond_ini)
    T_cu = 28.4; 
    T_fe = 26.4;
    T_in_k = 28.4;       % Temperatura entrada refrigerant (circuit tancat M3)
    T_in_vec = [28.4]; T_in_t = [0];  % Mantingut com a fallback per compatibilitat
    T_bat_actual = 25;
else
    T_cu = cond_ini.T_cu;
    T_fe = cond_ini.T_fe;
    T_in_vec  = cond_ini.T_in_vec;
    if isfield(cond_ini, 'T_in_d')
        T_in_d = cond_ini.T_in_d;
        T_in_t = []; 
    else
        T_in_t = cond_ini.T_in_t;
    end
    % Temperatura inicial refrigerant: si ve propagada de la volta anterior, usar-la
    % (evita el salt brusc que apareix si es re-inicialitza des del perfil estàtic)
    if isfield(cond_ini, 'T_in_start')
        T_in_k = cond_ini.T_in_start;
    else
        T_in_k = T_in_vec(1);
    end
    
    if isfield(cond_ini, 'T_bat_start')
        T_bat_actual = cond_ini.T_bat_start;
    elseif isfield(cond_ini, 'T_bat_vec')
        T_bat_actual = cond_ini.T_bat_vec(1);
    else
        T_bat_actual = 25;
    end
    
    if isfield(cond_ini, 'v_start')
        v_start_manual = cond_ini.v_start;
    else
        v_start_manual = NaN;
    end
end
factor_derating_k = 1.0;

% ── PARÀMETRES RADIADOR M3 (geometria per al model de circuit tancat) ────────
[AcAire, AcAigua, AcAire_ref, AcAigua_ref] = radiador_params();


% --- GESTIÓ DE MODEL DE BATERIA INTEGRAT ---
if nargin >= 7 && isfield(cond_ini, 'Cell_Type')
    bat_cell_type = cond_ini.Cell_Type;
    bat_Ns = cond_ini.Ns;
    bat_Np = cond_ini.Np;
    interp_id = cond_ini.interp_id;
    interp_iq = cond_ini.interp_iq;
    if isfield(cond_ini, 'F_inv'), F_inv = cond_ini.F_inv; else, F_inv = []; end
    if isfield(cond_ini, 'F_mot'), F_mot = cond_ini.F_mot; else, F_mot = []; end
else
    bat_cell_type = 3; % Tenpower per defecte
    bat_Ns = 30; bat_Np = 18;
    interp_id = []; interp_iq = [];
    F_inv = []; F_mot = [];
end

% LUTs i variables (Model Mestre)
if isempty(which('battery_config'))
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'BATERIA'));
end
cfg = battery_config(bat_cell_type);

SOC_LUT         = cfg.SOC_LUT;
dU_dT_LUT       = cfg.dU_dT_LUT;
Temp_LUT        = cfg.Temp_LUT;
R_Mult_T        = cfg.R_Mult_T;
SOC_R_LUT       = cfg.SOC_R_LUT;
R_Mult_SOC      = cfg.R_Mult_SOC;
Voc_LUT_current = cfg.Voc_LUT;
R_mOhm_Nominal  = cfg.R_mOhm;
Capacity_Ah     = cfg.Cap_Ah;
Cell_Weight_g   = cfg.Weight_g;
Max_I_cell      = cfg.Max_I;
Max_Charge_I_cell = cfg.Max_C;


Max_Allowed_Cell_Voltage = 126 / bat_Ns;
if nargin >= 7 && isfield(cond_ini, 'SOC_start') && ~isnan(cond_ini.SOC_start)
    SOC_actual = cond_ini.SOC_start;
else
    SOC_actual = min(1, interp1(Voc_LUT_current, SOC_LUT, Max_Allowed_Cell_Voltage, 'linear', 'extrap'));
end
R_conn_mOhm = 2;
Pack_Capacity_As = Capacity_Ah * bat_Np * 3600;
Pack_Weight_kg = (bat_Ns * bat_Np * Cell_Weight_g) / 1000;
Cell_Cp = 900;

Voc_pack_init = interp1(SOC_LUT, Voc_LUT_current, SOC_actual, 'linear', 'extrap') * bat_Ns;
V_batt_actual = Voc_pack_init; 
V_bus_filtered = V_batt_actual;
alpha_vbus = 0.2; % Retard del filtre pas baix per evitar "chattering"

% NOTA: El filtre EWMA de potència (tau=0.5s) ha estat eliminat.
% El circuit de Thévenin (quadràtica Voc/R_pack) ja calcula el punt
% de treball instantani per si sol — no cal cap filtratge addicional.
% Usar P_elec_inst directament evita la subestimació del voltage sag,
% dels pics de corrent i de l'estrès tèrmic a la bateria.


n_max          = 250000; % Augmentat per 7 voltes
res_temps      = zeros(n_max, 1);
res_vel        = zeros(n_max, 1);
res_rpm        = zeros(n_max, 1);
res_gas        = zeros(n_max, 1);
res_mode       = zeros(n_max, 1);
res_dist       = zeros(n_max, 1);
res_marxa      = zeros(n_max, 1);
res_parell_mot = zeros(n_max, 1);
res_parell_dem = zeros(n_max, 1);
res_parell_res = zeros(n_max, 1);
res_accel      = zeros(n_max, 1);

% Historials Bateria i Tèrmics
res_V_batt     = zeros(n_max, 1);
res_I_batt     = zeros(n_max, 1);
res_SOC        = zeros(n_max, 1);
res_Tbat       = zeros(n_max, 1);


% Historials tèrmics i derating
res_Tcu        = zeros(n_max, 1);
res_Tout       = zeros(n_max, 1);
res_Tin        = zeros(n_max, 1);  % Temperatura entrada refrigerant (circuit tancat M3)
res_Irms       = zeros(n_max, 1);  % Corrent RMS de fase motor (A)
res_Id         = zeros(n_max, 1);  % Corrent Id (A)
res_Iq         = zeros(n_max, 1);  % Corrent Iq (A)
res_Qcool      = zeros(n_max, 1);
res_derat      = zeros(n_max, 1);
res_kmot       = zeros(n_max, 1);
res_kbat       = zeros(n_max, 1);

if ~isnan(v_start_manual)
    v_actual = v_start_manual;
else
    v_actual = interp1(metres_ref, vel_ref, 0, 'linear', 'extrap');
end
t_actual = 0;
d_actual = 0;
idx      = 0;

marxa_actual = 1;
for m = 1:length(ratios)
    rpm_test = (v_actual * ratios(m) * 60) / (2 * pi * R_roda);
    if rpm_test >= rpm_min && rpm_test <= rpm_max
        marxa_actual = m;
        break;
    end
end
ratio_t = ratios(marxa_actual);

t_bloqueig       = 0.5;
t_sense_empenyer = 0.08;
canvi_en_curs    = false;
t_inici_canvi    = 0;

copia_activa  = false;
copia_seg_idx = 0;
copia_rec_idx = 0;
lap_actual    = 1;
temps_1_volta = 0;

%% BLOC 3 - BUCLE PRINCIPAL
while d_actual < distancia_total

    if canvi_en_curs && (t_actual - t_inici_canvi) >= t_bloqueig
        canvi_en_curs = false;
    end

    % Massa equivalent de la marxa actual
    M_eq = masses_eq(min(marxa_actual, length(masses_eq)));

    % Distància relativa a la volta actual
    d_volta = d_actual - (lap_actual - 1) * distancia_lap;
    
    % Si hem passat de volta, resetejar copia_activa i passar a la següent
    if d_volta >= distancia_lap
        if lap_actual == 1
            temps_1_volta = t_actual;
        end
        lap_actual = lap_actual + 1;
        d_volta = d_actual - (lap_actual - 1) * distancia_lap;
        copia_activa = false; % Reset al inici de volta
    end

    %% DETERMINAR MODE
    if copia_activa
        d_final_seg = taula_seg.Metre_Final(copia_seg_idx);
        if d_volta > d_final_seg
            copia_activa  = false;
            copia_seg_idx = 0;
            copia_rec_idx = 0;
        end
        mode_actual = 'COPIA';

    else
        mode_actual = 'FISICA';

        v_kmh = v_actual * 3.6;
        for k = 1:height(taula_rec)
            d_ini_rec    = taula_rec.Metre_Inici_Recta(k);
            d_fin_rec    = taula_rec.Metre_Final_Recta(k);

            if d_volta < d_ini_rec || d_volta > d_fin_rec
                continue;
            end

            pendent_rec  = taula_rec.Pendent(k);
            v_ini_rec    = taula_rec.V_Inici_Recta(k);
            d_ini_extrap = taula_rec.Metre_Inici_Recta(k);
            v_recta_kmh  = v_ini_rec + pendent_rec * (d_volta - d_ini_extrap);

            if v_kmh >= v_recta_kmh
                copia_activa  = true;
                copia_seg_idx = taula_rec.Segment(k);
                copia_rec_idx = k;
                mode_actual   = 'COPIA';
                break;
            end
        end
    end

    %% FÍSICA O CÒPIA
    if strcmp(mode_actual, 'COPIA')

        v_anterior = v_actual;
        v_ideal    = interp1(metres_ref, vel_ref, d_volta, 'linear', 'extrap');
        gas_actual = interp1(taula_gas_moto.Metre, taula_gas_moto.Factor_Gas_MOTOSPIRIT, d_volta, 'linear', 'extrap');

        if v_actual > v_ideal && copia_rec_idx > 0
            pendent_rec_ms = taula_rec.Pendent(copia_rec_idx) / 3.6;
            v_actual = v_actual + pendent_rec_ms * v_actual * dt;
            v_actual = max(v_actual, v_ideal);
        else
            v_actual = v_ideal;
        end

        % Parell motor equivalent en mode CÒPIA (amb M_eq)
        accel_copia   = (v_actual - v_anterior) / dt;
        angle_copia   = atan(interp1(metres_ref, pendent_ref, d_volta, 'linear', 'extrap') / 100);
        f_aero_copia  = 0.5 * rho * Cd * A * v_actual^2;
        f_roll_copia  = M * g * cos(angle_copia) * Cr;
        f_grav_copia  = M * g * sin(angle_copia);
        f_res_copia   = f_aero_copia + f_roll_copia + f_grav_copia;
        f_motor_copia = M_eq * accel_copia + f_res_copia;
        parell_demanat_copia = (f_motor_copia * R_roda* rend) / (ratio_t);
        
        parell_demanat_final = parell_demanat_copia;
        
        % Restricció de voltatge fins i tot en mode còpia per consistència elèctrica:
        rpm_actual   = (v_actual * ratio_t * 60) / (2 * pi * R_roda);
        if ~isempty(interp_id) && parell_demanat_copia > 0
            [~, ~, parell_motor] = limitar_corriente_y_tension(parell_demanat_copia, rpm_actual, 610.0, V_bus_filtered, T_cu, interp_id, interp_iq, 126.0, 6000.0);
        else
            parell_motor = parell_demanat_copia;
        end

        % Marxa coherent
        if length(ratios) > 1
            for m = 2:length(ratios)
                rpm_test = (v_actual * ratios(m) * 60) / (2 * pi * R_roda);
                if rpm_test >= rpm_min && rpm_test <= rpm_max
                    marxa_actual = m;
                    ratio_t      = ratios(marxa_actual);
                    break;
                end
            end
        end

    else
        %% MODE FÍSICA
        angle  = atan(interp1(metres_ref, pendent_ref, d_volta, 'linear', 'extrap') / 100);
        f_grav = M * g * sin(angle);
        f_roll = M * g * cos(angle) * Cr;
        f_aero = 0.5 * rho * Cd * A * v_actual^2;
        f_res  = f_grav + f_roll + f_aero;

        if canvi_en_curs && (t_actual - t_inici_canvi) < t_sense_empenyer
            gas_actual   = 0;
            parell_motor = 0;
        else
            gas_actual   = interp1(metres_gas, gas_ref, d_volta, 'linear', 'extrap');
            gas_actual   = min(max(gas_actual, 0), 1);
            rpm_actual   = (v_actual * ratio_t * 60) / (2 * pi * R_roda);
            % APLICA DERATING AL PARELL MÀXIM DISPONIBLE
            parell_demanat = funcio_parell_base(max(rpm_actual, 100)) * factor_derating_k * gas_actual;
            parell_demanat_final = parell_demanat;
            
            % --- NOU: LIMITADOR DE PARELL (VOLTAGE-LIMITED TORQUE) ---
            if ~isempty(interp_id) && parell_demanat > 0
                [~, ~, parell_motor] = limitar_corriente_y_tension(parell_demanat, rpm_actual, 610.0, V_bus_filtered, T_cu, interp_id, interp_iq, 126.0, 6000.0);
            else
                parell_motor = parell_demanat;
            end
            
            f_motor      = parell_motor * ratio_t * rend / R_roda;
        end

        % Acceleració amb massa equivalent
        accel    = (f_motor - f_res) / M_eq;
        v_actual = max(v_actual + accel * dt, 0.1);
    end

    %% PARELL RESISTIU (sempre, independentment del mode)
    angle_r    = atan(interp1(metres_ref, pendent_ref, d_volta, 'linear', 'extrap') / 100);
    f_aero_r   = 0.5 * rho * Cd * A * v_actual^2;
    f_roll_r   = M * g * cos(angle_r) * Cr;
    f_grav_r   = M * g * sin(angle_r);
    parell_res = (f_aero_r + f_roll_r + f_grav_r) * R_roda;

    %% RPM I CANVI DE MARXES
    rpm_actual = (v_actual * ratio_t * 60) / (2 * pi * R_roda);

    if length(ratios) > 1 && ~canvi_en_curs
        if rpm_actual > rpm_max && marxa_actual < length(ratios)
            marxa_actual  = marxa_actual + 1;
            ratio_t       = ratios(marxa_actual);
            canvi_en_curs = true;
            t_inici_canvi = t_actual;
        elseif rpm_actual < rpm_min && marxa_actual > 2
            marxa_actual  = marxa_actual - 1;
            ratio_t       = ratios(marxa_actual);
            canvi_en_curs = true;
            t_inici_canvi = t_actual;
        end
    end

    %% AVANÇAR ESTAT DINÀMIC
    d_actual = d_actual + v_actual * dt;
    t_actual = t_actual + dt;

    %% ACTUALITZACIÓ CINEMÀTICA ELÈCTRICA I BATERIA
    % 1. Potència Elèctrica Consumida (instantània)
    rpm_actual_rads = rpm_actual * 2 * pi / 60;
    P_mech = parell_motor * rpm_actual_rads;
    if P_mech >= 0
        if ~isempty(F_inv) && ~isempty(F_mot)
            % Obtenir eficiència de l'inversor i del motor a aquest punt operatiu
            em_k = max(F_mot(max(0, rpm_actual), max(0, parell_motor)), 1) / 100;
            ei_k = max(F_inv(max(0, rpm_actual), max(0, parell_motor)), 1) / 100;
            P_elec_inst = P_mech / (em_k * ei_k);
        else
            P_elec_inst = P_mech / 0.90; % Proxy genèric si no hi ha dades 
        end
    else
        P_elec_inst = 0; % Desactivem regeneració (el motor no carrega la bateria)
    end
    
    % Potència instantània — sense filtratge: la quadràtica de Thévenin és el model dinàmic natiu.
    P_elec = P_elec_inst;
    
    % 2. Dinàmica Instantània de la Bateria
    f_T = interp1(Temp_LUT, R_Mult_T, T_bat_actual, 'linear', 'extrap');
    f_SOC = interp1(SOC_R_LUT, R_Mult_SOC, SOC_actual, 'linear', 'extrap');
    Effective_Cell_R_mOhm = (R_mOhm_Nominal * f_T * f_SOC) + R_conn_mOhm;
    R_pack = (Effective_Cell_R_mOhm / 1000) * (bat_Ns / bat_Np);
    
    Voc_pack = interp1(SOC_LUT, Voc_LUT_current, SOC_actual, 'linear', 'extrap') * bat_Ns;
    
    discriminant = Voc_pack^2 - 4 * R_pack * P_elec;
    if discriminant < 0; discriminant = 0; end 
    I_batt = (Voc_pack - sqrt(discriminant)) / (2 * R_pack);
    V_batt_actual = Voc_pack - (I_batt * R_pack);
    
    % Avançar i filtrar estats
    SOC_actual = SOC_actual - (I_batt * dt) / Pack_Capacity_As;
    V_bus_filtered = (alpha_vbus * V_batt_actual) + ((1 - alpha_vbus) * V_bus_filtered);
    
    %% MODEL TÈRMIC I DERATING (REAL-TIME)
    
    % 1. T_in del circuit tancat M3 — ja actualitzat al final de l'iteració anterior (T_in_k)
    %    (El perfil de T_in del cond_ini ja no s'usa com a força: només la initial condition)
    
    % 2. Irms del motor — calculada a partir del parell ENTREGAT (parell_motor)
    %    usant les LUT Id/Iq del limitador de voltatge (punts de treball reals)
    if ~isempty(interp_id) && parell_motor > 0
        rpm_clamp = min(max(rpm_actual, 0.0), 6000.0);
        trq_clamp = min(max(parell_motor, 0.0), 126.0);  % Clamp per LUT Iq
        % Id: usem el polinomi IA dinàmic per consistència amb el model elèctric
        id_k = calcular_id_dinamica(parell_motor, rpm_actual, V_bus_filtered, T_cu, interp_id);
        iq_k = interp_iq(trq_clamp, rpm_clamp);
        I_rms_k = sqrt(id_k^2 + iq_k^2);
    else
        I_rms_k = 0.0;
        id_k = 0.0;
        iq_k = 0.0;
    end
    
    % 3. Velocitat vehicle [m/s] per al model M2 del radiador
    v_vehicle_ms = v_actual;   % v_actual ja és en m/s
    
    % 4. Pas tèrmic motor — Model M3 circuit tancat (Irms + radiador dinàmic)
    [T_cu, T_fe, Tout_k, Qcool_k, T_in_k] = thermal_motor_step( ...
        T_cu, T_fe, rpm_actual, I_rms_k, T_in_k, dt, ...
        v_vehicle_ms, AcAire, AcAire_ref, AcAigua, AcAigua_ref);
    
    % (El model M3 de radiador dinàmic actualitza T_in_k a cada pas de temps)
    
    % 3. Pas tèrmic Bateria
    dU_dT = interp1(SOC_LUT, dU_dT_LUT, SOC_actual, 'linear', 'extrap');
    P_heat_bat = ((I_batt^2) * R_pack) + (-I_batt * (T_bat_actual+273.15) * bat_Ns * dU_dT);
    T_bat_actual = T_bat_actual + (P_heat_bat * dt) / (Pack_Weight_kg * Cell_Cp);

    
    % 4. Factor Derating instantani (Centralitzat via cond_ini)
    if isfield(cond_ini, 'derating') && isstruct(cond_ini.derating)
        T_mot_pts = cond_ini.derating.mot_T;  k_mot_pts = cond_ini.derating.mot_k;
        T_bat_pts = cond_ini.derating.bat_T;  k_bat_pts = cond_ini.derating.bat_k;
        
        % Comprovar si el derating està activat per a cada sistema
        if isfield(cond_ini.derating, 'active_mot'), dm_act = cond_ini.derating.active_mot; else, dm_act = true; end
        if isfield(cond_ini.derating, 'active_bat'), db_act = cond_ini.derating.active_bat; else, db_act = true; end
    else
        % Fallback - Valors per defecte si no s'especifica
        T_mot_pts = [0, 120, 130, 140, 145, 200]; k_mot_pts = [1.0, 1.0, 0.75, 0.4, 0.0, 0.0];
        T_bat_pts = [0,  60,  65,  70,  75, 100]; k_bat_pts = [1.0, 1.0, 0.85, 0.5, 0.0, 0.0];
        dm_act = true; db_act = true;
    end
    
    if dm_act
        k_mot = interp1(T_mot_pts, k_mot_pts, T_cu,   'linear', 'extrap');
    else
        k_mot = 1.0;
    end
    
    if db_act
        k_bat = interp1(T_bat_pts, k_bat_pts, T_bat_actual,'linear', 'extrap');
    else
        k_bat = 1.0;
    end
    
    factor_derating_k = max(0, min(1, min(k_mot, k_bat)));

    %% GUARDAR RESULTATS
    idx = idx + 1;
    if idx > n_max
        error('Array ple: augmenta n_max o redueix dt');
    end
    res_temps(idx)      = t_actual;
    res_vel(idx)        = v_actual;
    res_rpm(idx)        = rpm_actual;
    res_gas(idx)        = gas_actual;
    res_mode(idx)       = double(strcmp(mode_actual, 'FISICA'));
    res_dist(idx)       = d_actual;
    res_marxa(idx)      = marxa_actual;
    res_parell_dem(idx) = parell_demanat_final;
    res_parell_mot(idx) = parell_motor;
    res_parell_res(idx) = parell_res;
    res_accel(idx)      = accel;
    
    % Historial tèrmic i bateria
    res_Tcu(idx)        = T_cu;
    res_Tout(idx)       = Tout_k;
    res_Tin(idx)        = T_in_k;  % Tin dinàmic del circuit tancat M3
    res_Irms(idx)       = I_rms_k; % Corrent RMS de fase
    res_Id(idx)         = id_k;    % Component d (flux)
    res_Iq(idx)         = iq_k;    % Component q (parell)
    res_Qcool(idx)      = Qcool_k;
    res_derat(idx)      = factor_derating_k;
    
    res_V_batt(idx)     = V_batt_actual;
    res_I_batt(idx)     = I_batt;
    res_SOC(idx)        = SOC_actual;
    res_Tbat(idx)       = T_bat_actual;
    res_derat(idx)      = factor_derating_k;
    res_kmot(idx)       = k_mot;
    res_kbat(idx)       = k_bat;

end

%% BLOC 4 - RESULTATS
idx_valid = 1:idx;
resultat.temps_total     = t_actual;
resultat.temps           = res_temps(idx_valid);
resultat.velocitat_kmh   = res_vel(idx_valid) * 3.6;
resultat.rpm             = res_rpm(idx_valid);
resultat.gas             = res_gas(idx_valid);
resultat.mode            = res_mode(idx_valid);
resultat.distancia       = res_dist(idx_valid);
resultat.marxa           = res_marxa(idx_valid);
resultat.parell_demanat  = res_parell_dem(idx_valid);
resultat.parell_motor    = res_parell_mot(idx_valid);  % N·m al cigonyal
resultat.parell_resistiu = res_parell_res(idx_valid);  % N·m a la roda
resultat.acceleracio     = res_accel(idx_valid);
resultat.num_voltes      = num_voltes;
resultat.temps_1_volta   = temps_1_volta;

% Señales térmicas y bateria passades a la sortida
resultat.T_winding     = res_Tcu(idx_valid);
resultat.T_cool_out    = res_Tout(idx_valid);
resultat.T_cool_in     = res_Tin(idx_valid);   % Tin dinàmic M3 (per dashboard i propagació)
resultat.I_rms         = res_Irms(idx_valid);  % Corrent RMS de fase motor [A]
resultat.Id            = res_Id(idx_valid);    % Corrent d (flux) [A]
resultat.Iq            = res_Iq(idx_valid);    % Corrent q (parell) [A]
resultat.Q_cool        = res_Qcool(idx_valid);
resultat.factor_derat  = res_derat(idx_valid);
resultat.k_mot_all     = res_kmot(idx_valid);
resultat.k_bat_all     = res_kbat(idx_valid);
resultat.T_cu_final    = T_cu;
resultat.T_fe_final    = T_fe;
resultat.T_in_final    = T_in_k;               % Propagar a la volta següent

resultat.V_batt        = res_V_batt(idx_valid);
resultat.I_batt        = res_I_batt(idx_valid);
resultat.SOC           = res_SOC(idx_valid);
resultat.T_bat         = res_Tbat(idx_valid);
resultat.SOC_final     = SOC_actual;
resultat.T_bat_final   = T_bat_actual;

%% V_MAX TEÒRICA
ratio_final = ratios(end);
v_low = 0.1; v_high = 120;
for iter = 1:100
    v_mid   = (v_low + v_high) / 2;
    rpm_mid = (v_mid * ratio_final * 60) / (2 * pi * R_roda);
    parell  = funcio_parell_base(max(rpm_mid, 100));
    f_motor = parell * ratio_final * rend / R_roda;
    f_res   = 0.5 * rho * Cd * A * v_mid^2 + M * g * Cr;
    if f_motor > f_res, v_low = v_mid; else, v_high = v_mid; end
    if (v_high - v_low) < 0.01, break; end
end
resultat.v_max_kmh = ((v_low + v_high) / 2) * 3.6;

end

% =========================================================================
% FUNCIONS ELÈCTRIQUES — Standalone (font única de veritat):
%   DOE 5/LIMITS MOTOR VOLTAGE/calcular_id_dinamica.m
%   DOE 5/LIMITS MOTOR VOLTAGE/limitar_corriente_y_tension.m
%
% NO definir còpies locals aquí. Si cal modificar el model elèctric,
% edita ÚNICAMENT els fitxers anteriors i tots els scripts s'actualitzen.
% =========================================================================

% FI DE L'ARXIU