function [Pack_Weight_kg, T_pack_end, status_str, failed_this_lap, V_hist, I_hist, SOC_hist, T_hist, R_hist, D_flag] = battery_1volta(Ns, Np, Cell_Type, P_watts_sim, T_init_bat, SOC_init)
% =========================================================================
% FUNCTION: Single Battery Pack Simulation FOR 1 LAP
% Permet especificar T_init_bat i SOC_init
% =========================================================================

% Si no es dóna el perfil de potència, només retornem el pes
if nargin < 4 || isempty(P_watts_sim)
    cfg = battery_config(Cell_Type);
    Pack_Weight_kg = (Ns * Np * cfg.Weight_g) / 1000;

    if nargout > 1
        T_pack_end = NaN; status_str = 'NO_PROFILE'; failed_this_lap = false;
        V_hist = []; I_hist = []; SOC_hist = []; T_hist = []; R_hist = []; D_flag = [];
    end
    return;
end

if nargin < 5 || isnan(T_init_bat)
    T_init_bat = 25;
end
if nargin < 6
    SOC_init = NaN;
end

%% --- 1. CONFIGURACIÓ DE L'USUARI (PARÀMETRES FIXOS) ---
R_conn_mOhm = 2;        % Resistència de connexió per cel·la (mOhm)
ignore_time_sec = 5;    % Segons inicials on es permet ignorar el derating (redüït per 1 volta)
delta_t = 0.5;          % Pas de temps de la simulació (segons)

Max_Pack_Voltage = 126; 
Max_Allowed_Temp = 90; 
Cell_Cp = 900;          

%% --- 2. CARREGAR EL PERFIL DE POTÈNCIA ---
num_steps = length(P_watts_sim);

%% --- 3. DADES DE LES CEL·LES (LUTs) ---
% Assegurem l'accés als mòduls compartits a l'arrel de DOE 5
if isempty(which('battery_config'))
    this_dir = fileparts(mfilename('fullpath'));
    root_doe  = fullfile(this_dir, '..');
    if isfolder(root_doe), addpath(root_doe); end
end

cfg = battery_config(Cell_Type);
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
cell_name       = cfg.cell_name;


Max_Allowed_Cell_Voltage = Max_Pack_Voltage / Ns;
if isnan(SOC_init)
    Initial_SOC = min(1, interp1(Voc_LUT_current, SOC_LUT, Max_Allowed_Cell_Voltage, 'linear', 'extrap'));
else
    Initial_SOC = SOC_init;
end
Min_Pack_V = min(Voc_LUT_current) * Ns; 

%% --- 4. SIMULACIÓ ÚNICA ---
Max_Pack_I = Max_I_cell * Np;
Max_Charge_Pack_I = Max_Charge_I_cell * Np; 
Pack_Capacity_As = Capacity_Ah * Np * 3600;
Pack_Weight_kg = (Ns * Np * Cell_Weight_g) / 1000;

SOC = zeros(num_steps, 1); V_pack = zeros(num_steps, 1);
I_pack = zeros(num_steps, 1); T_pack = zeros(num_steps, 1); 
R_pack_history = zeros(num_steps, 1); P_real_history = zeros(num_steps, 1);
Derating_Flag = false(num_steps, 1); 

SOC(1) = Initial_SOC; T_pack(1) = T_init_bat;     
failed_this_lap = false;
failure_cause = '';
failure_time = 0;

for t = 1:num_steps
    f_T = interp1(Temp_LUT, R_Mult_T, T_pack(t), 'linear', 'extrap');
    f_SOC = interp1(SOC_R_LUT, R_Mult_SOC, SOC(t), 'linear', 'extrap');
    
    Effective_Cell_R_mOhm = (R_mOhm_Nominal * f_T * f_SOC) + R_conn_mOhm;
    R_pack = (Effective_Cell_R_mOhm / 1000) * (Ns / Np); 
    R_pack_history(t) = R_pack * 1000; 
    
    Voc_pack = interp1(SOC_LUT, Voc_LUT_current, SOC(t), 'linear', 'extrap') * Ns;
    
    I_v_min = (Voc_pack - Min_Pack_V) / R_pack; 
    I_v_max = (Voc_pack - Max_Pack_Voltage) / R_pack; 
    I_lim_desc = min(Max_Pack_I, I_v_min);
    I_lim_charge = max(-Max_Charge_Pack_I, I_v_max);
    
    P_max_desc = I_lim_desc * (Voc_pack - I_lim_desc * R_pack);
    P_min_charge = I_lim_charge * (Voc_pack - I_lim_charge * R_pack);
    
    P_req = P_watts_sim(t);
    if P_req > P_max_desc
        P_req = P_max_desc; Derating_Flag(t) = true; 
    elseif P_req < P_min_charge
        P_req = P_min_charge; Derating_Flag(t) = true; 
    end
    P_real_history(t) = P_req;
    
    discriminant = Voc_pack^2 - 4 * R_pack * P_req;
    if discriminant < 0; discriminant = 0; end 
    I_pack(t) = (Voc_pack - sqrt(discriminant)) / (2 * R_pack);
    V_pack(t) = Voc_pack - (I_pack(t) * R_pack);
    
    if t < num_steps
        dU_dT = interp1(SOC_LUT, dU_dT_LUT, SOC(t), 'linear', 'extrap');
        P_heat = ((I_pack(t)^2) * R_pack) + (-I_pack(t) * (T_pack(t)+273.15) * Ns * dU_dT);
        T_pack(t+1) = T_pack(t) + (P_heat * delta_t) / (Pack_Weight_kg * Cell_Cp);
        SOC(t+1) = SOC(t) - (I_pack(t) * delta_t) / Pack_Capacity_As;
        
        if T_pack(t+1) > Max_Allowed_Temp
            failed_this_lap = true; 
            failure_cause = sprintf('Excés de temperatura (%.1f ºC)', T_pack(t+1));
            failure_time = t * delta_t;
            num_steps = t; 
            V_pack=V_pack(1:t); I_pack=I_pack(1:t); SOC=SOC(1:t); T_pack=T_pack(1:t); 
            R_pack_history=R_pack_history(1:t); Derating_Flag=Derating_Flag(1:t);
            break;
        end
        if SOC(t+1) <= 0
            failed_this_lap = true; 
            failure_cause = 'Bateria esgotada (SOC = 0%)';
            failure_time = t * delta_t;
            num_steps = t; 
            V_pack=V_pack(1:t); I_pack=I_pack(1:t); SOC=SOC(1:t); T_pack=T_pack(1:t); 
            R_pack_history=R_pack_history(1:t); Derating_Flag=Derating_Flag(1:t);
            break;
        end
    end
end

start_eval_idx = max(1, round(ignore_time_sec / delta_t));
if length(Derating_Flag) >= start_eval_idx
    real_derating = any(Derating_Flag(start_eval_idx:end));
else
    real_derating = any(Derating_Flag);
end

%% --- 5. RESULTATS PER CONSOLA I TÍTOL ---
T_pack_end = T_pack(end);

if failed_this_lap
    status_str = sprintf('❌ FALLIDA: %s a t=%.1fs', failure_cause, failure_time);
elseif real_derating
    status_str = '⚠️ DERATING';
else
    status_str = '✅ CORRECTE';
end

V_hist = V_pack;
I_hist = I_pack;
SOC_hist = SOC;
T_hist = T_pack;
R_hist = R_pack_history;
D_flag = Derating_Flag;

end
