%% CONFIGURACIÓ INTERACTIVA DEL DOE 5 - ESTUDI ALTA RESOLUCIÓ RPM
clear; clc;

% Afegir carpetes al Path resolent a partir del directori actual
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'BATERIA'));
addpath(fullfile(script_dir, 'EFICIENCIA'));
addpath(fullfile(script_dir, 'FÍSICA', 'matlabdefinitiu'));
addpath(fullfile(script_dir, 'LIMITS MOTOR VOLTAGE'));
addpath(fullfile(script_dir, 'MODEL TERMIC MOTOR'));
addpath(script_dir);

%% 1. LLANÇAR INTERFÍCIE DE CONFIGURACIÓ
launch_config_ui();

function launch_config_ui()
    % Obtenir dimensions pantalla per centrar
    screen = get(0, 'ScreenSize');
    fw = 1150; fh = 850;
    px = (screen(3)-fw)/2; py = (screen(4)-fh)/2;
    
    fig = uifigure('Name', 'Configuració DOE 5 - Alta Resolució RPM', 'Position', [px py fw fh], 'Color', [0.94 0.94 0.94]);
    
    % Panell Principal amb marge constant
    main_p = uipanel(fig, 'Title', 'PANEL DE CONTROL DE SIMULACIÓ (DOE)', 'FontSize', 18, 'FontWeight', 'bold', ...
        'Position', [20 20 fw-40 fh-40], 'BackgroundColor', 'w');
    
    m = 20; % Marge interior
    pw = (fw - 40 - 3*m)/2; % Amplada panells
    
    % --- SECCIÓ 1: BATERIA (Dalt, Ample complet) ---
    s1 = uipanel(main_p, 'Title', '1. CONFIGURACIÓ DE BATERIA', 'Position', [m 610 fw-40-2*m 200], 'FontSize', 14, 'FontWeight', 'bold');
    
    % Tipus Cel·la
    uic1 = uipanel(s1, 'Title', 'Tipus de Cel·la', 'Position', [15 15 280 155]);
    chk_sa88  = uicheckbox(uic1, 'Text', 'SA88', 'Position', [20 110 200 22], 'Value', false);
    chk_sa124 = uicheckbox(uic1, 'Text', 'SA124', 'Position', [20 80 200 22], 'Value', false);
    chk_tenp  = uicheckbox(uic1, 'Text', 'Tenpower', 'Position', [20 50 200 22], 'Value', true);
    
    % Sèries
    uic2 = uipanel(s1, 'Title', 'Sèries (S)', 'Position', [315 15 220 155]);
    ns_vals = {29, 30, 31, 32}; chk_ns = {};
    for i=1:4, chk_ns{i} = uicheckbox(uic2, 'Text', string(ns_vals{i}), 'Position', [20 110-(i-1)*30 150 22], 'Value', ns_vals{i}==30); end

    % Paral·lels
    uic3 = uipanel(s1, 'Title', 'Paral·lels (P)', 'Position', [555 15 500 155]);
    uilabel(uic3, 'Text', 'SA88 (6-11):', 'Position', [20 115 150 22], 'FontWeight', 'bold');
    np_sa88 = {6, 7, 8, 9, 10, 11}; chk_np88 = {};
    for i=1:6
        col = ifElse(i<=3, 0, 1); row = ifElse(i<=3, i-1, i-4);
        chk_np88{i} = uicheckbox(uic3, 'Text', string(np_sa88{i}), 'Position', [25+col*80 90-row*25 80 22], 'Value', false);
    end
    uilabel(uic3, 'Text', '124 / TenP (14-20):', 'Position', [200 115 150 22], 'FontWeight', 'bold');
    np_high = {14, 15, 16, 17, 18, 19, 20}; chk_npHigh = {};
    for i=1:7
        col = ifElse(i<=4, 0, 1); row = ifElse(i<=4, i-1, i-5);
        chk_npHigh{i} = uicheckbox(uic3, 'Text', string(np_high{i}), 'Position', [205+col*85 90-row*25 80 22], 'Value', np_high{i}==20);
    end
    
    % --- SECCIÓ 2: MOTO I TRANSMISSIÓ (Mig) ---
    s2 = uipanel(main_p, 'Title', '2. MOTOR, TRANSMISSIÓ I ESCALAT', 'Position', [m 395 fw-40-2*m 210], 'FontSize', 14, 'FontWeight', 'bold');
    
    % Transmissió
    uic4 = uipanel(s2, 'Title', 'Elecció Transmissió', 'Position', [15 15 320 175]);
    chk_caja    = uicheckbox(uic4, 'Text', 'Caixa de Canvis', 'Position', [20 130 130 22], 'Value', true, 'FontWeight', 'bold');
    dd_caja     = uidropdown(uic4, 'Items', {'Vilanova', 'Motospirit'}, 'Position', [160 130 130 22], 'Value', 'Motospirit');
    
    chk_directa = uicheckbox(uic4, 'Text', 'Directe (1 Gear)', 'Position', [20 90 130 22], 'Value', true, 'FontWeight', 'bold');
    dd_dir      = uidropdown(uic4, 'Items', {'Vilanova', 'Motospirit'}, 'Position', [160 90 130 22], 'Value', 'Vilanova');
    
    % Potència Caixa
    uic5 = uipanel(s2, 'Title', 'Potència Caixa (%)', 'Position', [355 15 340 175]);
    pwr_vals = {-10, 0, 5, 10, 15, 20, 25, 30, 35, 40}; chk_pwr_c = {};
    for i=1:8
        col = ifElse(i<=4, 0, 1); row = ifElse(i<=4, i-1, i-5);
        chk_pwr_c{i} = uicheckbox(uic5, 'Text', string(pwr_vals{i}), 'Position', [30+col*100 130-row*35 80 22], 'Value', pwr_vals{i}==30);
    end
    
    % Potència Directa
    uic6 = uipanel(s2, 'Title', 'Potència Directa (%)', 'Position', [715 15 340 175]);
    chk_pwr_d = {};
    for i=1:8
        col = ifElse(i<=4, 0, 1); row = ifElse(i<=4, i-1, i-5);
        chk_pwr_d{i} = uicheckbox(uic6, 'Text', string(pwr_vals{i}), 'Position', [30+col*100 130-row*35 80 22], 'Value', pwr_vals{i}==30);
    end

    % --- SECCIÓ 3: FINESTRA RPM (Baix) ---
    s3 = uipanel(main_p, 'Title', '3. ESTUDI DE FINESTRA DE RPM (SALT 200 RPM)', 'Position', [m 180 fw-40-2*m 210], 'FontSize', 14, 'FontWeight', 'bold');
    
    % RPM Min
    uic7 = uipanel(s3, 'Title', 'RPM Mínimes (Reducció)', 'Position', [15 15 280 175]);
    rmin_vals = num2cell(2500:200:4100); chk_rmin = {};
    for i=1:length(rmin_vals)
        col = ceil(i/3)-1; row = mod(i-1,3);
        chk_rmin{i} = uicheckbox(uic7, 'Text', string(rmin_vals{i}), 'Position', [20+col*85 130-row*35 80 22], 'Value', rmin_vals{i}==3500);
    end
    
    % RPM Max
    uic8 = uipanel(s3, 'Title', 'RPM Màximes (Upshift / End)', 'Position', [315 15 740 165]);
    rmax_vals = num2cell(3000:200:7000); chk_rmax = {};
    for i=1:length(rmax_vals)
        col = ceil(i/3)-1; row = mod(i-1,3);
        chk_rmax{i} = uicheckbox(uic8, 'Text', string(rmax_vals{i}), 'Position', [20+col*100 120-row*35 100 22], 'Value', rmax_vals{i}==4800);
    end

    % --- SECCIÓ 4: CONFIGURACIÓ DERATING (Nou) ---
    s4 = uipanel(main_p, 'Title', '4. ESTAT DEL DERATING TÈRMIC', 'Position', [m 100 fw-40-2*m 75], 'FontSize', 14, 'FontWeight', 'bold');
    chk_derat_mot = uicheckbox(s4, 'Text', 'DERATING MOTOR ACTIU', 'Position', [150 15 300 30], 'Value', true, 'FontSize', 15, 'FontWeight', 'bold', 'FontColor', [0.6 0.2 0]);
    chk_derat_bat = uicheckbox(s4, 'Text', 'DERATING BATERIA ACTIU', 'Position', [650 15 300 30], 'Value', true, 'FontSize', 15, 'FontWeight', 'bold', 'FontColor', [0 0.4 0.6]);

    % BOTÓ D'EXECUCIÓ
    uibutton(main_p, 'Text', 'RUN SIMULATION', 'Position', [(fw-40-600)/2 20 600 70], ...
        'FontSize', 24, 'FontWeight', 'bold', 'BackgroundColor', [0.1 0.5 0.1], 'FontColor', 'w', ...
        'ButtonPushedFcn', @(btn,event) start_doe(fig, chk_sa88, chk_sa124, chk_tenp, chk_caja, chk_directa, chk_pwr_c, chk_pwr_d, chk_ns, chk_np88, chk_npHigh, chk_rmin, chk_rmax, dd_caja, dd_dir, chk_derat_mot, chk_derat_bat));
end

function start_doe(fig, c88, c124, cten, ctx, cdir, cpwr_c, cpwr_d, cns, cnp88, cnpH, crmin, crmax, dc, dd, cd_mot, cd_bat)
    %% CONFIGURACIÓ DERATING (font única — s'usa a la simulació i al resum)
    % Corba OPTIMITZADA per a CAIXA (Model de Potència T_start=116.0, Alpha=1.53)
    derat_c = struct('mot_T', [0,125.852,125.862,126.245,126.628,127.011,127.393,127.776,128.159,128.542,128.924,129.307, 129.69,130.073,130.455,130.838,131.221,131.604,131.986,132.369,132.752,133.135,133.517,  133.9,134.283,134.666,135.048,135.431,135.814,136.197,136.579,136.962,137.345,137.728, 138.11,138.493,138.876,139.259,139.641,140.024,140.407, 140.79,141.172,141.555,141.938,142.321,142.703,143.086,143.469,143.852,144.234,144.617,    145, 145.01,    200,], ...
                     'mot_k', [1.000,1.000,1.000,0.997,0.992,0.986,0.978,0.969,0.960,0.949,0.938,0.926,0.913,0.899,0.885,0.870,0.855,0.839,0.822,0.805,0.787,0.769,0.750,0.731,0.712,0.692,0.671,0.650,0.629,0.607,0.585,0.562,0.539,0.515,0.491,0.467,0.443,0.417,0.392,0.366,0.340,0.314,0.287,0.260,0.232,0.204,0.176,0.148,0.119,0.089,0.060,0.030,0.000,0.000,0.000,], ...
                     'bat_T', [0, 60, 65, 70, 75, 100], ...
                     'bat_k', [1.0, 1.0, 0.85, 0.5, 0, 0]);
    
    % Corba OPTIMITZADA per a DIRECTE (Model de Potència T_start=105.7, Alpha=1.51)
    derat_d = struct('mot_T', [0,119.99,   120, 120.5,   121, 121.5,   122, 122.5,   123, 123.5,   124, 124.5,   125, 125.5,   126, 126.5,   127, 127.5,   128, 128.5,   129, 129.5,   130, 130.5,   131, 131.5,   132, 132.5,   133, 133.5,   134, 134.5,   135, 135.5,   136, 136.5,   137, 137.5,   138, 138.5,   139, 139.5,   140, 140.5,   141, 141.5,   142, 142.5,   143, 143.5,   144, 144.5,   145,145.01,   200,], ...
                     'mot_k', [1.000,1.000,1.000,0.997,0.992,0.985,0.977,0.968,0.958,0.948,0.936,0.924,0.911,0.897,0.882,0.867,0.852,0.836,0.819,0.802,0.784,0.766,0.747,0.728,0.708,0.688,0.667,0.646,0.625,0.603,0.581,0.558,0.535,0.512,0.488,0.464,0.439,0.414,0.389,0.363,0.337,0.311,0.284,0.257,0.230,0.202,0.174,0.146,0.118,0.089,0.059,0.030,0.000,0.000,0.000,], ...
                     'bat_T', [0, 62.19, 62.2, 64.15, 66.1, 68.05, 70, 70.01, 100], ...
                     'bat_k', [1.0, 1.0, 1.0, 0.817, 0.598, 0.339, 0, 0, 0]);

    sel_cells=[]; if c88.Value, sel_cells(end+1)=1; end; if c124.Value, sel_cells(end+1)=2; end; if cten.Value, sel_cells(end+1)=3; end
    sel_tx=[]; if ctx.Value, sel_tx(end+1)=1; end; if cdir.Value, sel_tx(end+1)=0; end
    
    sel_pwr_c=[]; for i=1:length(cpwr_c), if cpwr_c{i}.Value, sel_pwr_c(end+1)=str2double(cpwr_c{i}.Text); end; end
    sel_pwr_d=[]; for i=1:length(cpwr_d), if cpwr_d{i}.Value, sel_pwr_d(end+1)=str2double(cpwr_d{i}.Text); end; end
    
    sel_ns=[]; for i=1:length(cns), if cns{i}.Value, sel_ns(end+1)=str2double(cns{i}.Text); end; end
    sel_np88=[]; for i=1:length(cnp88), if cnp88{i}.Value, sel_np88(end+1)=str2double(cnp88{i}.Text); end; end
    sel_npH=[]; for i=1:length(cnpH), if cnpH{i}.Value, sel_npH(end+1)=str2double(cnpH{i}.Text); end; end
    sel_rmin=[]; for i=1:length(crmin), if crmin{i}.Value, sel_rmin(end+1)=str2double(crmin{i}.Text); end; end
    sel_rmax=[]; for i=1:length(crmax), if crmax{i}.Value, sel_rmax(end+1)=str2double(crmax{i}.Text); end; end
    
    derat_active_mot = cd_mot.Value;
    derat_active_bat = cd_bat.Value;
    
    if isempty(sel_cells), return; end
    sim_queue = {};
    for c=sel_cells
        if c==1, cur_np = sel_np88; else, cur_np = sel_npH; end
        for ns=sel_ns, for np=cur_np, for tx=sel_tx
            % Triar el llistat de potències segons la transmissió
            if tx==1, cur_pwr = sel_pwr_c; else, cur_pwr = sel_pwr_d; end
            
            for p=cur_pwr
                for rmin=sel_rmin, for rmax=sel_rmax
                    if rmax <= rmin + 200, continue; end
                    % Determinar motor segons tx
                    if tx==1, m_sheet = dc.Value; d_cfg = derat_c; else, m_sheet = dd.Value; d_cfg = derat_d; end
                    
                    % Afegir flags d'activació a la config de derating
                    d_cfg.active_mot = derat_active_mot;
                    d_cfg.active_bat = derat_active_bat;
                    
                    s=struct('cell',c,'ns',ns,'np',np,'tx',logical(tx),'pwr',p,'rmin',rmin,'rmax',rmax, 'motor', m_sheet, 'derat_cfg', d_cfg); 
                    sim_queue{end+1}=s;
                end; end
            end
        end; end; end
    end
    
    total_sims = length(sim_queue);
    d = uiprogressdlg(fig, 'Title', 'Simulant...', 'Cancelable', 'on');
    load('Parametres_Base_Moto.mat', 'p_base', 'p_caixa', 'p_dir');
    
    % Pre-carregar ambdues corbes de motor
    try
        o_vil = detectImportOptions('Dades_Corba_Motor.xlsx','Sheet','Dades_Motor_Vilanova');
        t_vil = readtable('Dades_Corba_Motor.xlsx', o_vil);
        f_vil = @(rpm) interp1(t_vil.w_rpm, t_vil.Parell, rpm, 'linear', 'extrap');
        
        o_mot = detectImportOptions('Dades_Corba_Motor.xlsx','Sheet','Dades_Motor_Motospirit');
        t_mot = readtable('Dades_Corba_Motor.xlsx', o_mot);
        f_mot = @(rpm) interp1(t_mot.w_rpm, t_mot.Parell, rpm, 'linear', 'extrap');
    catch
        % Fallback si alguna falta o error
        disp('Error carregant un dels fulls de motor. Assegura''t que existeixen.');
    end
    
    % Pre-carregar LUTs d'ID i IQ per al limitador de voltatge
    try
        script_dir_local = fileparts(mfilename('fullpath'));
        % Ara LIMITS MOTOR VOLTAGE és una carpeta veïna directa del Script_DOE_5 a "DOE 5"
        LUT_path = fullfile(script_dir_local, 'LIMITS MOTOR VOLTAGE');
        
        raw_id = readmatrix(fullfile(LUT_path, 'Mapa_Final_ID.xlsx'));
        raw_iq = readmatrix(fullfile(LUT_path, 'Mapa_Final_IQ.xlsx'));
        
        axis_rpm = linspace(0, 6000, 64);
        axis_te = linspace(0, 126, 64);
        [Te_grid, RPM_grid] = ndgrid(axis_te, axis_rpm);
        
        LUT_Id = raw_id(end-63:end, end-63:end) / sqrt(2);
        LUT_Iq = raw_iq(end-63:end, end-63:end) / sqrt(2);
        
        interp_id = griddedInterpolant(Te_grid, RPM_grid, LUT_Id, 'linear', 'linear');
        interp_iq = griddedInterpolant(Te_grid, RPM_grid, LUT_Iq, 'linear', 'linear');
    catch ME
        fprintf('Advertència: No s''ahan trobat Mapa_Final_ID/IQ.xlsx a %s.\n', LUT_path);
        interp_id = []; interp_iq = [];
    end
    
    % PRE-CARREGAR EFICIÈNCIES (MOTOR I INVERSOR)
    try
        eff_path = fullfile(script_dir_local, 'EFICIENCIA', 'EffInversoriMotor.xlsx');
        opts = detectImportOptions(eff_path);
        if isprop(opts, 'VariableNamingRule'), opts.VariableNamingRule = 'preserve'; end
        d_eff = readtable(eff_path, opts);
        F_inv = scatteredInterpolant(d_eff{:,1}, d_eff{:,2}, d_eff{:,3}, 'linear', 'nearest');
        F_mot = scatteredInterpolant(d_eff{:,1}, d_eff{:,2}, d_eff{:,4}, 'linear', 'nearest');
    catch
        fprintf('Advertència: No es pot carregar EffInversoriMotor.xlsx\n');
        F_inv = []; F_mot = [];
    end
    
    resultats = {}; dt = 0.01; dt_bat = 0.5; num_voltes_bat = 7;
    for i=1:total_sims
        if d.CancelRequested, break; end
        s = sim_queue{i}; d.Value = (i-1)/total_sims;
        par = p_base;
        if s.tx, f=fieldnames(p_caixa); for j=1:length(f), par.(f{j})=p_caixa.(f{j}); end; tx_str='CAIXA'; else, f=fieldnames(p_dir); for j=1:length(f), par.(f{j})=p_dir.(f{j}); end; tx_str='DIRECTA'; end
        par.M_total = p_base.Massa_moto_nua + p_base.M_pilot + par.extra_mass + battery(s.ns, s.np, s.cell, []);
        
        % Escollir motor correcte
        if strcmp(s.motor, 'Vilanova'), f_m = f_vil; else, f_m = f_mot; end
        f_esc = @(rpm) f_m(rpm) * (1 + s.pwr/100);
        try
            %% PARÀMETRES I INICIALITZACIÓ 7 VOLTES
            volta_ideal_refs = readtable('Volta_Ideal_MOTOSPIRIT.xlsx');
            distancia_lap = volta_ideal_refs.Distancia_m(end);
            
            t_norm_refs = linspace(0, 1, 8); % Normalitzat de la volta 0 a la 7
            T_in_refs   = 25.0 * ones(1, 8); % Temperatura entrant constant a 25 graus
            T_motor_actual = 25.0;           % Temp inicial motor igual a Tin
            T_bat_actual   = 25;           % Temp inicial bateria
            SOC_actual     = NaN;          % Es calcularà a battery_1volta
            Tfe_actual     = T_in_refs(1) - 2.0; % Temp estator inicial
            factor_derating = 1.0;
            v_actual_ms    = 0;          % Sortida des de parat (0 km/h)
            
            % Arrays per acumular 7 voltes
            rpm_7v_all = []; trq_7v_all = []; parell_mot_all = []; parell_dem_all = [];
            P_batt_all = []; V_all = []; I_all = []; SOC_all = []; T_bat_all = [];
            Tcu_all = []; Tout_all = []; Qcool_all = []; T_in_all = [];
            Irms_all = [];  % Corrent RMS de fase motor [A]
            Id_all = [];    % Corrent Id [A]
            Iq_all = [];    % Corrent Iq [A]
            derat_7v_all = [];
            kmot_7v_all = [];
            kbat_7v_all = [];
            gas_7v_all = [];
            mode_7v_all = [];
            temps_1v_llista = zeros(1, num_voltes_bat);
            Ah_1v_llista = zeros(1, num_voltes_bat);
            kWh_1v_llista = zeros(1, num_voltes_bat);
            
            vel_7v_all = []; dist_7v_all = [];
            vel_laps_cell = cell(1, num_voltes_bat);
            dist_laps_cell = cell(1, num_voltes_bat);
            marxa_7v_all = []; marxa_laps_cell = cell(1, num_voltes_bat);
            V_batt_int_all = []; I_batt_int_all = []; SOC_int_all = []; % MODEL INTEGRAT
            
            failed_bat_total = false;
            
            % Inicializació per a la primera volta
            cond_ini = struct(); % <-- RESET MÀGIC D'ESTAT PER A EVITAR FUITES
            T_bat_vec_volta = T_bat_actual; 
            T_bat_t_volta = 0;
            d_lap_start = 0; % Monitor de distància per normalitzar l'overlay
            
            for volta = 1:num_voltes_bat
                
                % 1. Preparar condicions inicials (Real-Time Derating)
                d_1v_ref = linspace(0, distancia_lap, 100)'; % Perfil per distància
                t_in_start = (volta-1) / num_voltes_bat;
                t_in_end   = volta / num_voltes_bat;
                t_norm_local = linspace(t_in_start, t_in_end, length(d_1v_ref))';
                T_in_volta_ref = interp1(t_norm_refs, T_in_refs, t_norm_local, 'pchip', 'extrap');
                
                cond_ini.T_cu = T_motor_actual;
                cond_ini.T_fe = Tfe_actual;
                cond_ini.T_bat_vec = T_bat_vec_volta;
                cond_ini.T_bat_t = T_bat_t_volta;
                cond_ini.T_in_vec = T_in_volta_ref;
                cond_ini.T_in_d = d_1v_ref; % Usarem distància per suavitat
                cond_ini.derating = s.derat_cfg; % Passar config específica d'aquesta config
                
                % Variables clau pel model elèctric de la bateria a simulacio_moto_canut
                cond_ini.Ns = s.ns;
                cond_ini.Np = s.np;
                cond_ini.Cell_Type = s.cell;
                cond_ini.interp_id = interp_id;
                cond_ini.interp_iq = interp_iq;
                cond_ini.F_inv = F_inv;
                cond_ini.F_mot = F_mot;
                cond_ini.v_start = v_actual_ms;
                
                % 2. Dinàmica d'1 volta amb real-time derating
                rmec_v = simulacio_moto_canut(par, dt, f_esc, s.rmin, s.rmax, 1, cond_ini);
                
                % Corregir parells negatius si n'hi hagués
                T_dyn = rmec_v.parell_motor; T_dyn(T_dyn < 0) = 0; rmec_v.parell_motor = T_dyn;
                t_lap = rmec_v.temps_total;
                temps_1v_llista(volta) = t_lap;
                
                % 3. Calcular potència elèctrica demandada (per post-processat bateria)
                [em, ei] = calcular_rendiment(rmec_v.rpm, rmec_v.parell_motor);
                P_b1 = (rmec_v.parell_motor(:) .* (rmec_v.rpm(:)*2*pi/60)) ./ (max(em(:),1)/100 .* max(ei(:),1)/100);
                P_b1(rmec_v.parell_motor < 0) = 0;
                
                % 4. Sincronitzar als dt de bateria
                t_mec = (0:length(P_b1)-1)*dt; 
                t_syn = (0:dt_bat:t_lap)';
                P_b1_s = interp1(t_mec, P_b1, t_syn, 'linear', 0);
                
                % 5. Model de Bateria (1 volta)
                [~, Tf, st, fail_v, Vh, Ih, SOCh, Th] = battery_1volta(s.ns, s.np, s.cell, P_b1_s, T_bat_actual, SOC_actual);
                if fail_v, failed_bat_total = true; end
                
                % Càlcul Consum per a aquesta volta (Integració numèrica)
                Ah_1v_llista(volta) = trapz(Ih) * (dt_bat/3600);
                kWh_1v_llista(volta) = trapz(Vh .* Ih) * (dt_bat/3600/1000);
                
                SOC_actual = SOCh(end);
                T_bat_actual = Th(end);
                
                % Preparar T_bat per a la SEGÜENT volta (com a vector pel derating)
                T_bat_vec_volta = Th;
                T_bat_t_volta = (0:length(Th)-1)' * dt_bat;
                
                % Acumular senyals bateria
                if volta < num_voltes_bat
                    V_all = [V_all; Vh(1:end-1)]; I_all = [I_all; Ih(1:end-1)];
                    SOC_all = [SOC_all; SOCh(1:end-1)]; T_bat_all = [T_bat_all; Th(1:end-1)];
                    P_batt_all = [P_batt_all; P_b1_s(1:end-1)];
                else
                    V_all = [V_all; Vh]; I_all = [I_all; Ih];
                    SOC_all = [SOC_all; SOCh]; T_bat_all = [T_bat_all; Th];
                    P_batt_all = [P_batt_all; P_b1_s];
                end
                
                % 6. Actualitzar estat motor per la següent volta
                T_motor_actual = rmec_v.T_cu_final;
                Tfe_actual     = rmec_v.T_fe_final;
                
                % Acumular senyals mecàniques i tèrmiques (de simulacio_moto_canut)
                v1 = rmec_v.velocitat_kmh(:); d1 = rmec_v.distancia(:);
                vel_laps_cell{volta} = v1; 
                dist_laps_cell{volta} = d1; % La distància ja està normalitzada (0..1100) per cada LAP
                
                % T_in real: ara ve del circuit tancat M3 (dinàmic), no del perfil estàtic
                if isfield(rmec_v, 'T_cool_in')
                    T_in_v_real = rmec_v.T_cool_in(:);
                else
                    % Fallback per compatibilitat (no hauria de passar)
                    d_1v_real = rmec_v.distancia(:);
                    T_in_v_real = interp1(cond_ini.T_in_d, cond_ini.T_in_vec, d_1v_real, 'linear', 'extrap');
                end
                
                if volta < num_voltes_bat
                    rpm_7v_all = [rpm_7v_all; rmec_v.rpm(1:end-1)];
                    trq_7v_all = [trq_7v_all; rmec_v.parell_motor(1:end-1)];
                    parell_mot_all = [parell_mot_all; rmec_v.parell_motor(1:end-1)];
                    if isfield(rmec_v, 'parell_demanat')
                        parell_dem_all = [parell_dem_all; rmec_v.parell_demanat(1:end-1)];
                    else
                        parell_dem_all = [parell_dem_all; rmec_v.parell_motor(1:end-1)];
                    end
                    Tcu_all = [Tcu_all; rmec_v.T_winding(1:end-1)];
                    Tout_all = [Tout_all; rmec_v.T_cool_out(1:end-1)];
                    Qcool_all = [Qcool_all; rmec_v.Q_cool(1:end-1)];
                    T_in_all = [T_in_all; T_in_v_real(1:end-1)];
                    if isfield(rmec_v,'I_rms'), Irms_all = [Irms_all; rmec_v.I_rms(1:end-1)]; end
                    if isfield(rmec_v,'Id'),    Id_all   = [Id_all;   rmec_v.Id(1:end-1)];    end
                    if isfield(rmec_v,'Iq'),    Iq_all   = [Iq_all;   rmec_v.Iq(1:end-1)];    end
                    vel_7v_all = [vel_7v_all; v1(1:end-1)];
                    dist_7v_all = [dist_7v_all; d1(1:end-1) + d_lap_start];
                    derat_7v_all = [derat_7v_all; rmec_v.factor_derat(1:end-1)];
                    kmot_7v_all = [kmot_7v_all; rmec_v.k_mot_all(1:end-1)];
                    kbat_7v_all = [kbat_7v_all; rmec_v.k_bat_all(1:end-1)];
                    marxa_7v_all = [marxa_7v_all; rmec_v.marxa(1:end-1)];
                    gas_7v_all = [gas_7v_all; rmec_v.gas(1:end-1)];
                    mode_7v_all = [mode_7v_all; rmec_v.mode(1:end-1)];
                else
                    rpm_7v_all = [rpm_7v_all; rmec_v.rpm];
                    trq_7v_all = [trq_7v_all; rmec_v.parell_motor];
                    parell_mot_all = [parell_mot_all; rmec_v.parell_motor];
                    if isfield(rmec_v, 'parell_demanat')
                        parell_dem_all = [parell_dem_all; rmec_v.parell_demanat];
                    else
                        parell_dem_all = [parell_dem_all; rmec_v.parell_motor];
                    end
                    Tcu_all = [Tcu_all; rmec_v.T_winding];
                    Tout_all = [Tout_all; rmec_v.T_cool_out];
                    Qcool_all = [Qcool_all; rmec_v.Q_cool];
                    T_in_all = [T_in_all; T_in_v_real];
                    if isfield(rmec_v,'I_rms'), Irms_all = [Irms_all; rmec_v.I_rms]; end
                    if isfield(rmec_v,'Id'),    Id_all   = [Id_all;   rmec_v.Id];    end
                    if isfield(rmec_v,'Iq'),    Iq_all   = [Iq_all;   rmec_v.Iq];    end
                    vel_7v_all = [vel_7v_all; v1];
                    dist_7v_all = [dist_7v_all; d1 + d_lap_start];
                    derat_7v_all = [derat_7v_all; rmec_v.factor_derat];
                    kmot_7v_all = [kmot_7v_all; rmec_v.k_mot_all(:)];
                    kbat_7v_all = [kbat_7v_all; rmec_v.k_bat_all(:)];
                    marxa_7v_all = [marxa_7v_all; rmec_v.marxa(:)];
                    gas_7v_all = [gas_7v_all; rmec_v.gas(:)];
                    mode_7v_all = [mode_7v_all; rmec_v.mode(:)];
                end
                marxa_laps_cell{volta} = rmec_v.marxa;
                
                % Acumular senyals del model de bateria INTEGRAT
                if isfield(rmec_v, 'V_batt')
                    if volta < num_voltes_bat
                        V_batt_int_all = [V_batt_int_all; rmec_v.V_batt(1:end-1)];
                        I_batt_int_all = [I_batt_int_all; rmec_v.I_batt(1:end-1)];
                        SOC_int_all    = [SOC_int_all;    rmec_v.SOC(1:end-1)];
                    else
                        V_batt_int_all = [V_batt_int_all; rmec_v.V_batt];
                        I_batt_int_all = [I_batt_int_all; rmec_v.I_batt];
                        SOC_int_all    = [SOC_int_all;    rmec_v.SOC];
                    end
                end
                
                d_lap_start = d_lap_start + rmec_v.distancia(end); % Pròxima volta comença acumulant a la dist total
                
                % Actualitzar condicions inicials per a la propera volta
                cond_ini.v = rmec_v.velocitat_kmh(end) / 3.6; % Velocitat final lap anterior (m/s)
                v_actual_ms = cond_ini.v;                     % Propagar per la següent volta
                cond_ini.d = rmec_v.distancia(end);           % Distància final lap anterior
                
                % --- CLAU: propagar SOC i T_bat del model integrat ---
                % Sense això, cada volta reinicia des de SOC=100% i el voltatge no baixa
                if isfield(rmec_v, 'SOC_final')
                    cond_ini.SOC_start = rmec_v.SOC_final;
                end
                if isfield(rmec_v, 'T_bat_final')
                    cond_ini.T_bat_start = rmec_v.T_bat_final;
                end
                
                % --- CLAU M3: propagar T_in_final del circuit tancat ---
                % Sense això, cada volta re-inicialitza Tin des del perfil estàtic
                % (causava el salt brusc de temperatura a l'inici de cada volta)
                if isfield(rmec_v, 'T_in_final')
                    cond_ini.T_in_start = rmec_v.T_in_final;
                end
                
                % Condició de fallida crítica
                if failed_bat_total || rmec_v.factor_derat(end) <= 0.01
                    failed_bat_total = true; break;
                end
            end
            
            % --- FI DEL BUCLE DE 7 VOLTES ---
            rmec = rmec_v; % Prendre darreres estructures
            brand_name = ifElse(s.cell==1,'SA88',ifElse(s.cell==2,'SA124','TenPower'));
            
            % Informació derating al nom
            derat_str = '';
            if ~s.derat_cfg.active_mot, derat_str = [derat_str ' [M-OFF]']; end
            if ~s.derat_cfg.active_bat, derat_str = [derat_str ' [B-OFF]']; end
            
            rmec.nom_configuracio = sprintf('%s, %dS%dP, %s, %s, %+d%%, (%d-%d rpm)%s', brand_name, s.ns, s.np, tx_str, s.motor, s.pwr, s.rmin, s.rmax, derat_str);
            rmec.temps_1_volta = temps_1v_llista(1); 
            rmec.temps_total = sum(temps_1v_llista(temps_1v_llista > 0)); % Suma efectiva
            rmec.laps_time_array = temps_1v_llista; % GUARDO TEMPS PER VOLTA
            rmec.laps_Ah_array = Ah_1v_llista; % GUARDO CONSUM Ah PER VOLTA
            rmec.laps_kWh_array = kWh_1v_llista; % GUARDO CONSUM kWh PER VOLTA
            
            rmec.bat_status = st; rmec.bat_temp_fin = T_bat_actual; rmec.failed_bat = failed_bat_total;
            rmec.SOC_fin = SOC_actual * 100;
            rmec.RMin = s.rmin; rmec.RMax = s.rmax;
            rmec.M_total = par.M_total; rmec.TX = tx_str; rmec.scaling = s.pwr;
            rmec.is_caja = s.tx; % Camp requerit pel Dashboard Pro
            rmec.cell_type = s.cell; rmec.Ns = s.ns; rmec.Np = s.np;
            rmec.motor = s.motor;
            rmec.applied_derat = s.derat_cfg;
            
            idx_1v = round(temps_1v_llista(1)/dt_bat) + 1;
            if length(I_all) < idx_1v, idx_1v = length(I_all); end
            rmec.Ah_1v = trapz(I_all(1:idx_1v))*(dt_bat/3600);
            rmec.consum_Ah = trapz(I_all)*(dt_bat/3600); rmec.consum_kWh = trapz(V_all.*I_all)*(dt_bat/3600/1000);
            rmec.brand = char(ifElse(s.cell==1,'SA88',ifElse(s.cell==2,'SA124','TenP')));
            rmec.dt = dt;
            
            rmec.velocitat_kmh_7v = vel_7v_all;
            rmec.distancia_7v = dist_7v_all;
            rmec.laps_vel = vel_laps_cell;
            rmec.laps_dist = dist_laps_cell;
            rmec.marxa_laps = marxa_laps_cell;
            rmec.total_canvis_race = sum(abs(diff(marxa_7v_all)) ~= 0);
            
            rmec.P_batt_7v = P_batt_all; 
            rmec.T_winding_7v = Tcu_all; rmec.T_cool_out_7v = Tout_all; rmec.T_cool_in_7v = T_in_all; rmec.Q_cool_7v = Qcool_all;
            rmec.I_rms_7v = Irms_all;   % Corrent RMS de fase motor (7 voltes) [A]
            rmec.Id_7v    = Id_all;      % Corrent Id (7 voltes) [A]
            rmec.Iq_7v    = Iq_all;      % Corrent Iq (7 voltes) [A]
            rmec.rpm_7v = rpm_7v_all; rmec.trq_7v = trq_7v_all; rmec.T_max_mot = max(Tcu_all);
            rmec.factor_derat_7v = derat_7v_all;
            rmec.k_mot_7v = kmot_7v_all;
            rmec.k_bat_7v = kbat_7v_all;
            rmec.gas_7v = gas_7v_all;
            rmec.mode_7v = mode_7v_all;
            rmec.parell_demanat_7v = parell_dem_all; % NOU: Parell demanat sense limitació de voltatge
            
            % MODEL BATERIA INTEGRAT (dt=0.01s, física inline a simulacio_moto_canut)
            rmec.V_batt_7v     = V_batt_int_all;
            rmec.I_batt_int_7v = I_batt_int_all;
            rmec.SOC_int_7v    = SOC_int_all;
            
            % Adaptació pels gràfics
            rmec.Rendiment_total = par.Rendiment_total;
            rmec.parell_motor = parell_mot_all; rmec.rpm = rpm_7v_all;
            t_syn_global = (0:length(P_batt_all)-1)' * dt_bat;
            Pm_lap_all = parell_mot_all .* (rpm_7v_all*2*pi/60);
            t_mec_global = (0:length(Pm_lap_all)-1)' * dt;
            Pm1_s_all = interp1(t_mec_global, Pm_lap_all, t_syn_global, 'linear', 0);
            rmec.P_mech_7v = Pm1_s_all;
            rmec.P_wheel_7v = Pm1_s_all * par.Rendiment_total;

            
            % Calcular factor derating global al final (usant la config d'aquesta sim)
            k_mot_end = interp1(s.derat_cfg.mot_T, s.derat_cfg.mot_k, max(Tcu_all), 'linear', 'extrap');
            f_mot_end = max(0, min(1, k_mot_end)); 
            k_bat_end = interp1(s.derat_cfg.bat_T, s.derat_cfg.bat_k, max(T_bat_all), 'linear', 'extrap');
            f_bat_end = max(0, min(1, k_bat_end));
            rmec.k_mot_fin = f_mot_end; rmec.k_bat_fin = f_bat_end;
            rmec.applied_derat = s.derat_cfg; % Guardar per dashboard
            
            % Referències d'espai
            v_ref=[1422.1; 1263.6; 824.5; 1500.1]; L_ref=sum(v_ref);
            L_sim=rmec_v.distancia(end); rat=L_sim/L_ref; % de l'última volta
            d1=v_ref(1)*rat; d2=(v_ref(1)+v_ref(2))*rat; d3=(v_ref(1)+v_ref(2)+v_ref(3))*rat;
            [~,idx1]=min(abs(rmec_v.distancia-d1)); [~,idx2]=min(abs(rmec_v.distancia-d2)); [~,idx3]=min(abs(rmec_v.distancia-d3));
            rmec.S1=rmec_v.temps(idx1); rmec.S2=rmec_v.temps(idx2)-rmec_v.temps(idx1);
            rmec.S3=rmec_v.temps(idx3)-rmec_v.temps(idx2); rmec.S4=rmec.temps_1_volta-rmec_v.temps(idx3);
            
            resultats{end+1} = rmec;
        catch ME
            disp(['ERROR a la configuració: ', s.cell]);
            disp(ME.message);
            for iStack=1:numel(ME.stack)
                disp(ME.stack(iStack));
            end
            uialert(fig, sprintf('Error: %s\nMira la finestra de comandes de Matlab.', ME.message), 'Error Simulant');
        end
    end
    if ~isempty(resultats)
        n = length(resultats);
        % Pre-equipar arrays per col·leccionar dades
        c_conf = cell(n,1); c_mot = cell(n,1); c_derat_m = cell(n,1); c_derat_b = cell(n,1);
        m_mass = zeros(n,1); m_rmin = zeros(n,1); m_rmax = zeros(n,1); m_vmax = zeros(n,1);
        m_t1v = zeros(n,1); m_tmax_m = zeros(n,1); m_ah1v = zeros(n,1); m_ah7v = zeros(n,1);
        m_kwh = zeros(n,1); m_tmax_b = zeros(n,1); m_soc = zeros(n,1); c_falla = cell(n,1);
        m_kmot = zeros(n,1); m_kbat = zeros(n,1); c_der_act_m = cell(n,1); c_der_act_b = cell(n,1);
        c_cfg_m = cell(n,1); c_cfg_b = cell(n,1);

        for k=1:n
            r = resultats{k}; 
            str_mot = sprintf('T=[%s] K=[%s]', num2str(r.applied_derat.mot_T, '%g,'), num2str(r.applied_derat.mot_k, '%.2f,'));
            str_bat = sprintf('T=[%s] K=[%s]', num2str(r.applied_derat.bat_T, '%g,'), num2str(r.applied_derat.bat_k, '%.2f,'));

            c_conf{k} = r.nom_configuracio;
            c_mot{k} = r.motor;
            c_derat_m{k} = str_mot;
            c_derat_b{k} = str_bat;
            m_mass(k) = r.M_total;
            m_rmin(k) = r.RMin; m_rmax(k) = r.RMax;
            m_vmax(k) = max(r.velocitat_kmh);
            m_t1v(k) = r.temps_1_volta; m_tmax_m(k) = r.T_max_mot;
            m_ah1v(k) = r.Ah_1v; m_ah7v(k) = r.consum_Ah; m_kwh(k) = r.consum_kWh; 
            m_tmax_b(k) = r.bat_temp_fin;
            m_soc(k) = r.SOC_fin;
            if r.failed_bat, c_falla{k} = 'SÍ'; else, c_falla{k} = 'NO'; end
            m_kmot(k) = r.k_mot_fin;
            m_kbat(k) = r.k_bat_fin;
            if r.k_mot_fin < 1, c_der_act_m{k} = 'SÍ'; else, c_der_act_m{k} = 'NO'; end
            if r.k_bat_fin < 1, c_der_act_b{k} = 'SÍ'; else, c_der_act_b{k} = 'NO'; end
            
            if isfield(r.applied_derat, 'active_mot') && ~r.applied_derat.active_mot, c_cfg_m{k} = 'OFF'; else, c_cfg_m{k} = 'ON'; end
            if isfield(r.applied_derat, 'active_bat') && ~r.applied_derat.active_bat, c_cfg_b{k} = 'OFF'; else, c_cfg_b{k} = 'ON'; end
        end
        
        T_excel = table(c_conf, c_mot, c_cfg_m, c_cfg_b, c_derat_m, c_derat_b, m_mass, m_rmin, m_rmax, m_vmax, ...
            m_t1v, m_tmax_m, m_ah1v, m_ah7v, m_kwh, m_tmax_b, m_soc, c_falla, m_kmot, m_kbat, ...
            c_der_act_m, c_der_act_b, 'VariableNames', { ...
            'Configuracio', 'Corba_Motor', 'Derat_Mot_Cfg', 'Derat_Bat_Cfg', 'Corba_Derat_Mot', 'Corba_Derat_Bat', 'Massa_kg', ...
            'RPM_Min', 'RPM_Max', 'V_Max_kmh', 'Temps_Volta_s', 'Temp_Max_Motor', ...
            'Consum_Ah_1V', 'Consum_Ah_7V', 'Consum_kWh', 'Temp_Max_Bat', 'SOC_Final', ...
            'Falla', 'Derating_Mot_Factor_V7', 'Derating_Bat_Factor_V7', ...
            'Derat_Mot_Actiu', 'Derat_Bat_Actiu'});
        
        % Afegim les voltes d'una en una
        for v = 1:7
            T_excel.(sprintf('Consum_Ah_V%d', v)) = cellfun(@(x) x.laps_Ah_array(v), resultats)';
            T_excel.(sprintf('Consum_kWh_V%d', v)) = cellfun(@(x) x.laps_kWh_array(v), resultats)';
        end
            
        writetable(T_excel, 'Resultats_DOE_5_RPM.xlsx');
    end
    save('Dades_DOE_Complet.mat', 'resultats', 'f_vil', 'f_mot', 'derat_c', 'derat_d');
    close(d);
    
    Dashboard_DOE_Integrated(resultats, f_vil, f_mot, derat_c, derat_d, '', p_base, p_caixa, p_dir);
    close(fig);
end

function res = ifElse(c, t, f), if c, res=t; else, res=f; end; end
