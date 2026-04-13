function [Tcu_new, Tfe_new, Tout_k, Qcool_k, Tin_new] = thermal_motor_step(Tcu_old, Tfe_old, rpm_k, I_rms_k, T_in_k, dt, v_vehicle, AcAire, AcAire_ref, AcAigua, AcAigua_ref)
% THERMAL_MOTOR_STEP  Pas únic del model tèrmic M3 circuit tancat (M1+M2)
%
%   Model: M3_CIRCUIT_vDEF_OGv4 (identificat amb ANSYS + dades banc de mesura)
%   Circuit tancat: Tout_motor → Radiador (M2) → Tin(k+1)
%
%   Inputs:
%       Tcu_old    - Temp bobinat (coure) actual [°C]
%       Tfe_old    - Temp estator (ferro) actual [°C]
%       rpm_k      - Velocitat angular [rpm]
%       I_rms_k    - Corrent RMS de fase [A]  ← del motor entregat
%       T_in_k     - Temp entrada refrigerant actual [°C]
%       dt         - Pas de temps [s]
%       v_vehicle  - Velocitat del vehicle [m/s]
%       AcAire     - Àrea de contacte costat aire del radiador [m²]
%       AcAire_ref - Àrea de referència costat aire (calibratge ANSYS) [m²]
%       AcAigua    - Àrea de contacte costat aigua del radiador [m²]
%       AcAigua_ref- Àrea de referència costat aigua (calibratge ANSYS) [m²]
%
%   Outputs:
%       Tcu_new  - Nova temp bobinat [°C]
%       Tfe_new  - Nova temp estator [°C]
%       Tout_k   - Temp sortida refrigerant motor [°C]
%       Qcool_k  - Potència dissipada pel refrigerant [W]
%       Tin_new  - Nova temp entrada refrigerant (circuit tancat) [°C]

    %% --- 1. PARÀMETRES FÍSICS — MODEL M3 CIRCUIT (identificats) ---
    % ── Motor (M1) ──────────────────────────────────────────────────────────
    C_cu      = 807.2;          % [J/K]    Capacitat tèrmica coure
    C_fe      = 32952.1;        % [J/K]    Capacitat tèrmica ferro
    rho_f     = 1070.0;         % [kg/m³]  Densitat refrigerant (glicol 50%)
    cp_f      = 3350.0;         % [J/kg·K] Calor específica refrigerant
    mdot      = 0.0001 * rho_f; %          = 0.107 kg/s (6 L/min)
    T_amb     = 25.0;           % [°C]     Temp ambient motor
    R_fase    = 0.0027;         % [Ω/fase] Resistència de fase (datasheet, fix)
    R_cufe    = 0.0823;         % [K/W]    Resistència tèrmica Cu↔Fe
    k_fe      = 0.099459;       % [W/rpm]  Pèrdues ferro
    T0        = 20.586;         % [°C]     Temp referència pèrdues
    PLOSS_MIN = 50.0;           % [W]      Pèrdues mínimes estàtiques

    % Paràmetres identificats per fmincon (Model M1v10 - VALIDAT)
    P_scale   = 2.9908;         % Factor escala pèrdues totals
    Alpha     = 0.1629;         % Fracció pèrdues absorbides pel coure
    R_amb     = 0.0203;         % [K/W]  Resistència Fe↔ambient
    R_fewat   = 0.01805;        % [K/W]  Resistència Fe↔water interface
    alpha_eff = 0.00729;        % [1/°C] Coef. temp. resistivitat coure

    % ── Circuit: constant de temps primera ordre ──────────────────────────
    tau_circ  = 60.0;           % [s]   Constant de temps circuit refrigerant

    % ── Radiador (M2) ─────────────────────────────────────────────────────
    A_coef      = 0.423595;     % Coef. calibrat ANSYS
    A_exp       = 0.176056;     % Exponent velocitat ANSYS
    Ta_ambient  = 25.0;         % [°C] Temp ambient AIRE

    %% --- 2. DERIVATS ---
    R_tot = R_fewat + 1.0 / (mdot * cp_f);

    %% --- 3. PÈRDUES (MODEL M1 – Irms) ---
    % Pèrdues Joule (3 fases, resistència depenent de temperatura)
    P_joule = 3.0 * R_fase * (1.0 + alpha_eff * (Tcu_old - T0)) * I_rms_k^2;
    % Pèrdues ferro (proporcionals a rpm)
    P_ferro = k_fe * abs(rpm_k);
    % Pèrdues totals (escalades)
    Ploss_k = max(PLOSS_MIN, P_scale * (P_joule + P_ferro));

    %% --- 4. FLUXES DE CALOR ---
    Q_int = (Tcu_old - Tfe_old) / R_cufe;
    Q_ext = (Tfe_old - T_in_k)  / R_tot;
    Q_amb = (Tfe_old - T_amb)   / R_amb;

    %% --- 5. SORTIDA REFRIGERANT ---
    Tout_k  = T_in_k + Q_ext / (mdot * cp_f);
    Qcool_k = mdot * cp_f * (Tout_k - T_in_k);

    %% --- 6. ACTUALITZACIÓ NODES TÈRMICS (Euler explícit) ---
    Tcu_new = Tcu_old + (Alpha * Ploss_k - Q_int)                          / C_cu * dt;
    Tfe_new = Tfe_old + ((1 - Alpha) * Ploss_k + Q_int - Q_ext - Q_amb)   / C_fe * dt;

    %% --- 7. RADIADOR (M2) + CIRCUIT (primera ordre) ---
    % Escalatge geomètric respecte al radiador de referència
    escala_aire  = AcAire  / AcAire_ref;
    escala_aigua = AcAigua / AcAigua_ref;
    escala_geom  = sqrt(escala_aire * escala_aigua);

    % Eficiència radiador (limitat a 1 per seguretat)
    v_eff = max(v_vehicle, 0.0);
    Av    = min(A_coef * v_eff^A_exp * escala_geom, 1.0);

    % Temperatura sortida del radiador (= nova Tin del circuit)
    Tw_rad_out = Tout_k - Av * (Tout_k - Ta_ambient);

    % Circuit primera ordre: Tin(k+1) = Tin(k) + dt/tau * (Tw_rad_out - Tin(k))
    tau_safe = max(tau_circ, 1e-3);
    Tin_new  = T_in_k + (dt / tau_safe) * (Tw_rad_out - T_in_k);

end
