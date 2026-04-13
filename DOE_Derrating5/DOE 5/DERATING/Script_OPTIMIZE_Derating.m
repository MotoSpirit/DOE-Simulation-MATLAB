%% OPTIMITZACIÓ DE DERATING TÈRMIC - MotoSpirit
% Aquest script utilitza la mateixa interfície que el DOE 5 per triar una configuració
% i després optimitza automàticament les corbes de derating per minimitzar el temps.

clear; clc;

% Afegir carpetes al Path resolent a partir del directori actual
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, '..', '..', 'MATLAB POCA'));
base_pwd = fullfile(script_dir, '..', '..');
ef_dir = dir(fullfile(base_pwd, 'EFI*')); 
if ~isempty(ef_dir), addpath(fullfile(base_pwd, ef_dir(1).name)); end
addpath(script_dir);

%% 1. LLANÇAR INTERFÍCIE DE CONFIGURACIÓ
launch_config_ui();

function launch_config_ui()
    screen = get(0, 'ScreenSize');
    fw = 1100; fh = 950;
    px = (screen(3)-fw)/2; py = (screen(4)-fh)/2;
    fig = uifigure('Name', 'OPTIMITZADOR DE DERATING - MotoSpirit', 'Position', [px py fw fh], 'Color', [0.94 0.94 0.94]);
    
    main_panel = uipanel(fig, 'Title', 'PANEL D''OPTIMITZACIÓ (TRIEU REFERÈNCIA)', 'FontSize', 16, 'FontWeight', 'bold', ...
        'Position', [10 10 fw-20 fh-20], 'BackgroundColor', 'w');
    
    % --- COPIA DE LA SECCIÓ 1: BATERIA ---
    uipanel(main_panel, 'Title', '1. Configuració de Bateria', 'Position', [20 730 fw-60 210], 'FontSize', 14, 'FontWeight', 'bold');
    uipanel(main_panel, 'Title', 'Tipus de Cel·la', 'Position', [40 615 280 165]);
    chk_sa88  = uicheckbox(main_panel, 'Text', 'SA88 (Cell 1)', 'Position', [60 870 200 22], 'Value', false);
    chk_sa124 = uicheckbox(main_panel, 'Text', 'SA124 (Cell 2)', 'Position', [60 840 200 22], 'Value', false);
    chk_tenp  = uicheckbox(main_panel, 'Text', 'Tenpower (Cell 3)', 'Position', [60 810 200 22], 'Value', true);
    
    uipanel(main_panel, 'Title', 'Sèries (S)', 'Position', [340 615 220 165]);
    ns_vals = {29, 30, 31, 32}; chk_ns = {};
    for i=1:4, chk_ns{i} = uicheckbox(main_panel, 'Text', string(ns_vals{i}), 'Position', [360 870-(i-1)*35 150 22], 'Value', ns_vals{i}==30); end

    uipanel(main_panel, 'Title', 'Paral·lels (P)', 'Position', [580 615 480 165]);
    uilabel(main_panel, 'Text', 'Rang SA88 (6-11):', 'Position', [600 875 150 22], 'FontWeight', 'bold');
    np_sa88 = {6, 7, 8, 9, 10, 11}; chk_np88 = {};
    for i=1:6, col=ifElse(i<=4,0,1); row=ifElse(i<=4,i-1,i-5); chk_np88{i}=uicheckbox(main_panel,'Text',string(np_sa88{i}),'Position',[610+col*80 850-row*28 80 22],'Value',false); end
    uilabel(main_panel, 'Text', 'Rang 124/TenP (14-20):', 'Position', [800 875 200 22], 'FontWeight', 'bold');
    np_high = {14, 15, 16, 17, 18, 19, 20}; chk_npHigh = {};
    for i=1:7, col=ifElse(i<=4,0,1); row=ifElse(i<=4,i-1,i-5); chk_npHigh{i}=uicheckbox(main_panel,'Text',string(np_high{i}),'Position',[810+col*90 850-row*28 80 22],'Value',np_high{i}==20); end
    
    % --- COPIA DE LA SECCIÓ 2: MOTO ---
    uipanel(main_panel, 'Title', '2. Motor, Transmissió i Escalat', 'Position', [20 580 fw-60 145], 'FontSize', 14, 'FontWeight', 'bold');
    uipanel(main_panel, 'Title', 'Transmissió', 'Position', [40 460 280 110]);
    chk_caja    = uicheckbox(main_panel, 'Text', 'Caixa de Canvis', 'Position', [60 670 120 22], 'Value', true);
    dd_caja     = uidropdown(main_panel, 'Items', {'Vilanova', 'Motospirit'}, 'Position', [175 670 130 22], 'Value', 'Motospirit');
    chk_directa = uicheckbox(main_panel, 'Text', 'Directa', 'Position', [60 640 120 22], 'Value', false);
    dd_dir      = uidropdown(main_panel, 'Items', {'Vilanova', 'Motospirit'}, 'Position', [175 640 130 22], 'Value', 'Vilanova');
    
    uipanel(main_panel, 'Title', 'Potència Caixa (%)', 'Position', [340 460 350 110]);
    pwr_vals = {-10, 0, 5, 10, 15, 20, 25, 30}; chk_pwr_c = {};
    for i=1:8, col=ifElse(i<=4,0,1); row=ifElse(i<=4,i-1,i-5); chk_pwr_c{i}=uicheckbox(main_panel,'Text',string(pwr_vals{i}),'Position',[360+col*90 670-row*30 80 22],'Value',pwr_vals{i}==30); end
    
    uipanel(main_panel, 'Title', 'Potència Directa (%)', 'Position', [710 460 350 110]);
    chk_pwr_d = {};
    for i=1:8, col=ifElse(i<=4,0,1); row=ifElse(i<=4,i-1,i-5); chk_pwr_d{i}=uicheckbox(main_panel,'Text',string(pwr_vals{i}),'Position',[730+col*90 670-row*30 80 22],'Value',pwr_vals{i}==30); end

    % --- SECCIÓ 3: FINESTRA DE RPM DE REFERÈNCIA ---
    uipanel(main_panel, 'Title', '3. Finestra de RPM de Referència', 'Position', [20 260 fw-60 315], 'FontSize', 14, 'FontWeight', 'bold');
    uipanel(main_panel, 'Title', 'RPM Mínimes (Reducció)', 'Position', [40 290 280 270]);
    rmin_vals = num2cell(2500:200:4100); chk_rmin = {};
    for i=1:length(rmin_vals), col=ceil(i/5)-1; row=mod(i-1,5); chk_rmin{i}=uicheckbox(main_panel,'Text',string(rmin_vals{i}),'Position', [60+col*100 505-row*35 80 22], 'Value', rmin_vals{i}==3500); end
    uipanel(main_panel, 'Title', 'RPM Màximes (Upshift)', 'Position', [340 290 720 270]);
    rmax_vals = num2cell(3000:200:7000); chk_rmax = {};
    for i=1:length(rmax_vals), col=ceil(i/5)-1; row=mod(i-1,5); chk_rmax{i}=uicheckbox(main_panel,'Text',string(rmax_vals{i}),'Position', [360+col*110 505-row*35 100 22], 'Value', rmax_vals{i}==4800); end

    % --- SECCIÓ 4: PARÀMETRES D'OPTIMITZACIÓ I SEGURETAT ---
    uipanel(main_panel, 'Title', '4. Paràmetres de Seguretat i Optimització', 'Position', [20 110 fw-60 145], 'FontSize', 14, 'FontWeight', 'bold');
    
    uilabel(main_panel, 'Text', 'Límit Seguretat Motor (°C):', 'Position', [40 180 180 22], 'FontWeight', 'bold');
    ef_t_safe_mot = uieditfield(main_panel, 'numeric', 'Position', [220 180 60 22], 'Value', 145);
    
    uilabel(main_panel, 'Text', 'Límit Seguretat Bateria (°C):', 'Position', [40 145 180 22], 'FontWeight', 'bold');
    ef_t_safe_bat = uieditfield(main_panel, 'numeric', 'Position', [220 145 60 22], 'Value', 70);
    
    uilabel(main_panel, 'Text', 'Tª Inici Derating Guess (°C):', 'Position', [320 180 180 22]);
    ef_t_start_mot = uieditfield(main_panel, 'numeric', 'Position', [500 180 60 22], 'Value', 120);
    
    uilabel(main_panel, 'Text', 'Precisió Cerca (dt):', 'Position', [320 145 120 22]);
    ef_dt_search = uieditfield(main_panel, 'numeric', 'Position', [440 145 60 22], 'Value', 0.2);
    
    uilabel(main_panel, 'Text', 'Info: dt=0.2 és ultra-ràpid. La verificació final sempre serà a 0.01s.', ...
        'Position', [610 145 450 22], 'FontColor', [0.4 0.4 0.4], 'FontAngle', 'italic');

    uibutton(main_panel, 'Text', 'START PARAMETRIC OPTIMIZATION', 'Position', [(fw-500)/2-10 25 500 80], ...
        'FontSize', 22, 'FontWeight', 'bold', 'BackgroundColor', [0.1 0.4 0.8], 'FontColor', 'w', ...
        'ButtonPushedFcn', @(btn,event) start_optimization(fig, chk_sa88, chk_sa124, chk_tenp, chk_caja, chk_directa, chk_pwr_c, chk_pwr_d, chk_ns, chk_np88, chk_npHigh, chk_rmin, chk_rmax, dd_caja, dd_dir, ef_t_safe_mot, ef_t_safe_bat, ef_t_start_mot, ef_dt_search));
end

function start_optimization(fig, c88, c124, cten, ctx, cdir, cpwr_c, cpwr_d, cns, cnp88, cnpH, crmin, crmax, dc, dd, e_sm, e_sb, e_stm, e_dt)
    % 1. Determinar configuració única
    s = struct();
    if c88.Value, s.cell=1; elseif c124.Value, s.cell=2; else, s.cell=3; end
    s.ns = 30; for i=1:length(cns), if cns{i}.Value, s.ns=str2double(cns{i}.Text); break; end; end
    if s.cell==1, cur_np=cnp88; else, cur_np=cnpH; end
    s.np = 20; for i=1:length(cur_np), if cur_np{i}.Value, s.np=str2double(cur_np{i}.Text); break; end; end
    if ctx.Value, s.tx=true; s.pwr=30; for i=1:length(cpwr_c), if cpwr_c{i}.Value, s.pwr=str2double(cpwr_c{i}.Text); break; end; end; s.motor=dc.Value;
    else, s.tx=false; s.pwr=30; for i=1:length(cpwr_d), if cpwr_d{i}.Value, s.pwr=str2double(cpwr_d{i}.Text); break; end; end; s.motor=dd.Value; end
    s.rmin = 3500; for i=1:length(crmin), if crmin{i}.Value, s.rmin=str2double(crmin{i}.Text); break; end; end
    s.rmax = 4800; for i=1:length(crmax), if crmax{i}.Value, s.rmax=str2double(crmax{i}.Text); break; end; end

    % Valors de seguretat i dt
    s.T_safe_mot = e_sm.Value;
    s.T_safe_bat = e_sb.Value;
    s.search_dt  = e_dt.Value;

    % 2. Carregar dades base
    load('Parametres_Base_Moto.mat', 'p_base', 'p_caixa', 'p_dir');
    o_vil = detectImportOptions('Dades_Corba_Motor.xlsx','Sheet','Dades_Motor_Vilanova');
    t_vil = readtable('Dades_Corba_Motor.xlsx', o_vil);
    f_vil = @(rpm) interp1(t_vil.w_rpm, t_vil.Parell, rpm, 'linear', 'extrap');
    o_mot = detectImportOptions('Dades_Corba_Motor.xlsx','Sheet','Dades_Motor_Motospirit');
    t_mot = readtable('Dades_Corba_Motor.xlsx', o_mot);
    f_mot = @(rpm) interp1(t_mot.w_rpm, t_mot.Parell, rpm, 'linear', 'extrap');
    
    % 3. INITIAL GUESS PARAMÈTRIC (MODEL DE POTÈNCIA)
    % x(1) = T_start_m, x(2) = Alpha_m (1.0=lin, >1=concave)
    % x(3) = T_start_b, x(4) = Alpha_b
    x0 = [e_stm.Value, 1.5, 60, 1.5]; 
    
    d_opt = uiprogressdlg(fig, 'Title', 'Optimització d''Alta Eficiència...', 'Message', 'Calibrant corba de potència per a la màxima velocitat...');
    
    % Solver options - Més laxes per velocitat bruta
    options = optimset('Display','iter','TolX',0.2,'TolFun',0.5);
    
    fprintf('\n>>> Iniciant optimització de MODEL DE POTÈNCIA (%s)...\n', s.motor);
    fprintf('Limits: Motor <= %d°C, Bateria <= %d°C\n', s.T_safe_mot, s.T_safe_bat);

    % Run optimization
    [x_opt, fval] = fminsearch(@(x) objective_function(x, s, p_base, p_caixa, p_dir, f_vil, f_mot), x0, options);
    
    % Reconstruct Final (Invisible al Canut)
    derat_opt = generate_power_curve(x_opt, s.T_safe_mot, s.T_safe_bat);
    
    % Run final sim amb alta precisió
    s.derat_cfg = derat_opt;
    final_res = run_7_laps(s, p_base, p_caixa, p_dir, f_vil, f_mot, 0.01); 
    
    close(d_opt);
    
    % Print report
    fprintf('\n=========================================\n');
    fprintf('RESULTATS DE L''OPTIMITZACIÓ EFICIENT\n');
    fprintf('=========================================\n');
    fprintf('Mode: Funció de Potència [k = 1 - (deltaT/range)^alpha]\n');
    fprintf('-----------------------------------------\n');
    fprintf('MOTOR:   Inici a %.1f°C, Alpha = %.2f\n', x_opt(1), x_opt(2));
    fprintf('BATERIA: Inici a %.1f°C, Alpha = %.2f\n', x_opt(3), x_opt(4));
    fprintf('-----------------------------------------\n');
    fprintf('Temps total: %.2f s (Laps: %s)\n', final_res.temps_total, num2str(final_res.laps_time_array, '%.1f '));
    fprintf('Tª Max Assolida: Motor %.1f°C / Bat %.1f°C\n', final_res.T_max_mot, final_res.bat_temp_fin);
    fprintf('\nVECTOR FINAL MOTO (mot_T, mot_k):\n');
    fprintf('[%s]\n', num2str(derat_opt.mot_T, '%g,'));
    fprintf('[%s]\n', num2str(derat_opt.mot_k, '%.3f,'));
    fprintf('=========================================\n');
    
    msgbox(sprintf('Optimització Ràpida Finalitzada!\nTemps: %.2f s\nVeure Command Window per als vectors.', final_res.temps_total), 'Èxit');
end

function d_cfg = generate_power_curve(x, safe_m, safe_b)
    % Aquesta funció fa la "màgia" per ser compatible amb el codi base
    % Motor
    t_start_m = x(1); alpha_m = max(0.5, min(5, x(2)));
    tm = linspace(t_start_m, safe_m, 51);
    km = 1 - ((tm - t_start_m) ./ (safe_m - t_start_m)).^alpha_m;
    d_cfg.mot_T = [0, t_start_m-0.01, tm, safe_m+0.01, 200];
    d_cfg.mot_k = [1, 1, km, 0, 0];
    
    % Bateria
    t_start_b = x(3); alpha_b = max(0.5, min(5, x(4)));
    tb = linspace(t_start_b, safe_b, 51);
    kb = 1 - ((tb - t_start_b) ./ (safe_b - t_start_b)).^alpha_b;
    d_cfg.bat_T = [0, t_start_b-0.01, tb, safe_b+0.01, 100];
    d_cfg.bat_k = [1, 1, kb, 0, 0];
end

function cost = objective_function(x, s, p_base, p_caixa, p_dir, f_vil, f_mot)
    % Penalitzar valors irreals d'Alpha
    if x(2) < 0.3 || x(2) > 5 || x(4) < 0.3 || x(4) > 5
        cost = 1e6; return;
    end
    % Penalitzar T_start que superen el límit de seguretat
    if x(1) >= s.T_safe_mot - 1 || x(3) >= s.T_safe_bat - 1
        cost = 500000; return;
    end
    
    % Generar corba de potència
    s.derat_cfg = generate_power_curve(x, s.T_safe_mot, s.T_safe_bat);
    
    try
        res = run_7_laps(s, p_base, p_caixa, p_dir, f_vil, f_mot, s.search_dt);
        if res.T_max_mot > s.T_safe_mot + 0.1 || res.bat_temp_fin > s.T_safe_bat + 0.1 || res.failed_bat
            cost = 1000000 + (res.T_max_mot - s.T_safe_mot)*2000;
        else
            cost = res.temps_total;
        end
    catch
        cost = 2000000;
    end
end

function rmec = run_7_laps(s, p_base, p_caixa, p_dir, f_vil, f_mot, dt)
    % Re-implementation of Script 5 logic but isolated
    par = p_base;
    if s.tx, f=fieldnames(p_caixa); for j=1:length(f), par.(f{j})=p_caixa.(f{j}); end; tx_str='CAIXA'; else, f=fieldnames(p_dir); for j=1:length(f), par.(f{j})=p_dir.(f{j}); end; tx_str='DIRECTA'; end
    par.M_total = p_base.Massa_moto_nua + p_base.M_pilot + par.extra_mass + battery(s.ns, s.np, s.cell, []);
    if strcmp(s.motor, 'Vilanova'), f_m = f_vil; else, f_m = f_mot; end
    f_esc = @(rpm) f_m(rpm) * (1 + s.pwr/100);
    
    volta_ideal_refs = readtable('Volta_Ideal_MOTOSPIRIT.xlsx');
    distancia_lap = volta_ideal_refs.Distancia_m(end);
    t_norm_refs = linspace(0, 1, 8);
    T_in_refs   = [28.4, 33.2, 34.8, 35.6, 36.2, 36.5, 36.6, 36.4];
    T_motor_actual = T_in_refs(1); T_bat_actual = 25; Tfe_actual = T_in_refs(1)-2;
    SOC_actual = 0.95; % Start slightly below 100%
    
    dt_bat = 0.5; num_voltes_bat = 7;
    V_all=[]; I_all=[]; SOC_all=[]; T_bat_all=[]; Tcu_all=[]; temps_1v = [];
    failed = false;
    
    cond_ini = struct('v', 0, 'd', 0, 'T_bat_vec', 25, 'T_bat_t', 0, 'SOC', 0.95);

    for volta = 1:num_voltes_bat
        t_in_start = (volta-1)/7; t_in_end = volta/7;
        d_ref = linspace(0, distancia_lap, 50)';
        T_ref = interp1(t_norm_refs, T_in_refs, linspace(t_in_start, t_in_end, 50)', 'pchip');
        
        cond_ini.T_cu = T_motor_actual; cond_ini.T_fe = Tfe_actual;
        cond_ini.T_in_vec = T_ref; cond_ini.T_in_d = d_ref;
        cond_ini.derating = s.derat_cfg;
        
        rmec_v = simulacio_moto_canut(par, dt, f_esc, s.rmin, s.rmax, 1, cond_ini);
        
        T_dyn = rmec_v.parell_motor; T_dyn(T_dyn < 0) = 0; rmec_v.parell_motor = T_dyn;
        temps_1v(volta) = rmec_v.temps_total;
        
        [em, ei] = calcular_rendiment(rmec_v.rpm, rmec_v.parell_motor);
        P_b1 = (rmec_v.parell_motor(:) .* (rmec_v.rpm(:)*2*pi/60)) ./ (max(em(:),1)/100 .* max(ei(:),1)/100);
        t_mec = (0:length(P_b1)-1)*dt; t_syn = (0:dt_bat:rmec_v.temps_total)';
        P_b1_s = interp1(t_mec, P_b1, t_syn, 'linear', 0);
        
        [~, ~, ~, fail_v, Vh, Ih, SOCh, Th] = battery_1volta(s.ns, s.np, s.cell, P_b1_s, T_bat_actual, SOC_actual);
        if fail_v, failed=true; break; end
        
        SOC_actual = SOCh(end); T_bat_actual = Th(end);
        T_motor_actual = rmec_v.T_cu_final; Tfe_actual = rmec_v.T_fe_final;
        
        Tcu_all = [Tcu_all; rmec_v.T_winding]; 
        T_bat_all = [T_bat_all; Th];
        V_all = [V_all; Vh]; I_all = [I_all; Ih];
        
        if rmec_v.factor_derat(end) <= 0.01, failed=true; break; end
        
        cond_ini.v = rmec_v.velocitat_kmh(end) / 3.6; % De km/h a m/s
        cond_ini.d = rmec_v.distancia(end);
        cond_ini.T_bat_vec = Th; cond_ini.T_bat_t = (0:length(Th)-1)'*dt_bat;
        cond_ini.SOC = SOC_actual;
    end
    
    rmec = rmec_v; 
    rmec.nom_configuracio = 'OPTIMITZAT';
    rmec.temps_total = sum(temps_1v);
    rmec.failed_bat = failed;
    rmec.SOC_fin = SOC_actual * 100;
    rmec.T_max_mot = max(Tcu_all);
    rmec.bat_temp_fin = T_bat_actual;
    rmec.temps_1_volta = temps_1v(1);
    rmec.laps_time_array = temps_1v;
    % Minimal fields for dashboard
    rmec.brand = char(ifElse(s.cell==1,'SA88',ifElse(s.cell==2,'SA124','TenP')));
    rmec.Ns = s.ns; rmec.Np = s.np; rmec.scaling = s.pwr; rmec.RMin = s.rmin; rmec.RMax = s.rmax;
    rmec.M_total = par.M_total; rmec.motor = s.motor; rmec.dt = dt;
    rmec.P_batt_7v = zeros(size(V_all)); % Placeholder
    rmec.T_winding_7v = Tcu_all; rmec.factor_derat_7v = zeros(size(Tcu_all));
    rmec.rpm_7v = zeros(size(Tcu_all)); rmec.trq_7v = zeros(size(Tcu_all));
    rmec.P_mech_7v = zeros(size(V_all)); 
    rmec.applied_derat = s.derat_cfg;
    rmec.bat_status = ifElse(failed, 'FALLADA', 'OK');
    rmec.parell_motor = 0; rmec.rpm = 0; % Dummy for dashboard init
    rmec.Ah_1v = 0; rmec.consum_Ah = 0; rmec.consum_kWh = 0;
end

function res = ifElse(c, t, f), if c, res=t; else, res=f; end; end

function Dashboard_DOE_Integrated(res_all, f_vil, f_mot, derat_c, derat_d)
    % Just reuse the same function name but specialized or empty for now
    % Best would be to add the script5 dashboard code at the end
    all_b={}; all_ns=[]; all_np=[]; all_sc=[]; all_rmin=[]; all_rmax=[];
    for i=1:length(res_all), r=res_all{i}; all_b{end+1}=r.brand; all_ns(end+1)=r.Ns; all_np(end+1)=r.Np; all_sc(end+1)=r.scaling; all_rmin(end+1)=r.RMin; all_rmax(end+1)=r.RMax; end
    ub=unique(all_b); urmin=sort(unique(all_rmin)); urmax=sort(unique(all_rmax));
    fig = uifigure('Name', 'Dashboard OPTIMITZACIÓ', 'Position', [50 50 1200 850]);
    tg=uitabgroup(fig,'Position', [20 20 1160 810]);
    t1=uitab(tg,'Title','Resum Optimització');
    % ... (Minimal Dashboard code)
    uilabel(t1, 'Text', 'Optimització Finalitzada!', 'Position', [100 700 400 50], 'FontSize', 24, 'FontWeight', 'bold');
end
