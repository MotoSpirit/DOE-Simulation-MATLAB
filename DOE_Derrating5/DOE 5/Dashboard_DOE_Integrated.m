function Dashboard_DOE_Integrated(res_all, f_vil, f_mot, derat_c, derat_d, export_folder, p_base, p_caixa, p_dir)
    % Dashboard d'anàlisi de resultats del DOE 5 - Versió Professional
    
    % --- GESTIÓ PARÀMETRES OPCIONALS (compatibilitat retroactiva) ---
    if nargin < 6, export_folder = ''; end
    if nargin < 7, p_base = struct(); end
    if nargin < 8, p_caixa = struct(); end
    if nargin < 9, p_dir = struct(); end
    
    % --- EXTRACCIÓ DE METADADES PER A FILTRES ---
    all_b={}; all_tx={}; all_pwr=[]; all_rmin=[]; all_rmax=[];
    for i=1:length(res_all)
        r = res_all{i};
        % Bateria (brand)
        if isfield(r, 'brand'), all_b{end+1} = r.brand; else, all_b{end+1} = 'Unknown'; end
        
        % Transmissió (is_caja) - Robustesa
        if isfield(r, 'is_caja')
            val_tx = ifElse(r.is_caja, 'Caixa', 'Directe');
        elseif isfield(r, 'TX')
            val_tx = ifElse(strcmpi(r.TX, 'CAIXA'), 'Caixa', 'Directe');
        else
            val_tx = ifElse(contains(r.nom_configuracio, 'Caixa', 'IgnoreCase', true), 'Caixa', 'Directe');
        end
        all_tx{end+1} = val_tx;
        
        % Altres
        if isfield(r, 'scaling'), all_pwr(end+1) = r.scaling; else, all_pwr(end+1) = 0; end
        if isfield(r, 'RMin'), all_rmin(end+1) = r.RMin; else, all_rmin(end+1) = 0; end
        if isfield(r, 'RMax'), all_rmax(end+1) = r.RMax; else, all_rmax(end+1) = 0; end
    end
    ub = unique(all_b); 
    utx = unique(all_tx);
    upwr = sort(unique(all_pwr));
    urmin = sort(unique(all_rmin));
    urmax = sort(unique(all_rmax));
    
    fig = uifigure('Name', 'PRO DASHBOARD - Anàlisi Powertrain', 'Position', [50 50 1250 880], 'Color', [0.96 0.96 0.96]);
    
    % --- COLUMNA ESQUERRA: FILTRES I ACCIONS ---
    left_p = uipanel(fig, 'Position', [15 15 260 850], 'BackgroundColor', 'w', 'Title', 'PANEL DE CONTROL', 'FontWeight', 'bold');
    
    % Panel Accions - ampliat per acomodar tots els botons
    act_p = uipanel(left_p, 'Title', 'Accions de Sessió', 'Position', [10 510 240 335]);
    
    % Botó gran destacat: EXPORTAR TOT
    uibutton(act_p, 'Text', char(0x1F680) + " EXPORTAR TOT", 'Position', [10 290 220 35], ...
        'BackgroundColor', [0.0 0.55 0.27], 'FontColor', 'w', 'FontWeight', 'bold', 'FontSize', 13, ...
        'ButtonPushedFcn', @(btn,event) export_everything());
    
    % Separador visual
    uilabel(act_p, 'Text', '--- individuals ---', 'Position', [10 268 220 18], ...
        'FontSize', 8, 'FontColor', [0.6 0.6 0.6], 'HorizontalAlignment', 'center');

    uibutton(act_p, 'Text', char(0x1F4BE) + " GUARDAR SESSIÓ (.MAT)", 'Position', [10 232 220 28], ...
        'BackgroundColor', [0.1 0.4 0.7], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) save_session_data(res_all, f_vil, f_mot, derat_c, derat_d));
        
    uibutton(act_p, 'Text', char(0x1F4CA) + " EXPORTAR EXCEL (.XLSX)", 'Position', [10 196 220 28], ...
        'BackgroundColor', [0.1 0.6 0.2], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) export_to_excel());
    
    uibutton(act_p, 'Text', char(0x1F4F8) + " EXPORTAR GRÀFICS PNG", 'Position', [10 160 220 28], ...
        'BackgroundColor', [0.5 0.1 0.5], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) export_all_plots());
    
    uibutton(act_p, 'Text', char(0x1F4CB) + " GUARDAR PARÀMETRES", 'Position', [10 124 220 28], ...
        'BackgroundColor', [0.6 0.35 0.1], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) save_params_file());
    
    uibutton(act_p, 'Text', char(0x1F4E4) + " GENERAR POWERPOINT", 'Position', [10 88 220 28], ...
        'BackgroundColor', [0.3 0.1 0.5], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) generate_pptx());
    
    % Label carpeta d'exportació
    if ~isempty(export_folder)
        [~, fold_nm] = fileparts(export_folder);
        lbl_folder_txt = sprintf('\U0001F4C1 %s', fold_nm);
    else
        lbl_folder_txt = '\U0001F4C1 Carpeta: (no definida)';
    end
    uilabel(act_p, 'Text', lbl_folder_txt, 'Position', [5 8 230 72], ...
        'FontSize', 8, 'WordWrap', 'on', 'FontColor', [0.3 0.3 0.3]);

    % FILTRES DINÀMICS
    filt_p = uipanel(left_p, 'Title', 'Filtres de Cerca', 'Position', [10 250 240 350]);
    yloc = 410;
    
    % Sub-filtre Bateria
    uilabel(filt_p, 'Text', 'Bateries:', 'FontWeight', 'bold', 'Position', [10 yloc 200 20]);
    chk_b = {}; 
    for i=1:length(ub)
        yloc = yloc - 22;
        chk_b{i} = uicheckbox(filt_p, 'Text', ub{i}, 'Position', [20 yloc 200 22], 'Value', true, 'ValueChangedFcn', @filter_changed);
    end
    
    % Sub-filtre Transmissió
    yloc = yloc - 30;
    uilabel(filt_p, 'Text', 'Transmissions:', 'FontWeight', 'bold', 'Position', [10 yloc 200 20]);
    chk_tx = {};
    for i=1:length(utx)
        yloc = yloc - 22;
        chk_tx{i} = uicheckbox(filt_p, 'Text', utx{i}, 'Position', [20 yloc 200 22], 'Value', true, 'ValueChangedFcn', @filter_changed);
    end
    
    % Sub-filtre Potència
    yloc = yloc - 30;
    uilabel(filt_p, 'Text', 'Potències (%):', 'FontWeight', 'bold', 'Position', [10 yloc 200 20]);
    chk_p = {};
    for i=1:length(upwr)
        col = mod(i-1,2); if col==0 && i>1, yloc = yloc - 20; end
        chk_p{i} = uicheckbox(filt_p, 'Text', [num2str(upwr(i)) '%'], 'Position', [20+col*90 yloc-22 80 20], 'Value', true, 'ValueChangedFcn', @filter_changed);
    end
    yloc = yloc - 40;
    
    % Sub-filtre RPM
    uilabel(filt_p, 'Text', 'Window RPM:', 'FontWeight', 'bold', 'Position', [10 yloc 200 20]);
    yloc = yloc - 25;
    uilabel(filt_p, 'Text', 'Min:', 'Position', [20 yloc 40 20]);
    dd_rmin = uidropdown(filt_p, 'Items', [{'Tots'}, string(urmin)], 'Position', [60 yloc 60 22], 'ValueChangedFcn', @filter_changed);
    uilabel(filt_p, 'Text', 'Max:', 'Position', [135 yloc 40 20]);
    dd_rmax = uidropdown(filt_p, 'Items', [{'Tots'}, string(urmax)], 'Position', [175 yloc 60 22], 'ValueChangedFcn', @filter_changed);

    % LLISTA DE RESULTATS ACTIUS
    uilabel(left_p, 'Text', 'Simulacions Selectores:', 'FontWeight', 'bold', 'Position', [15 225 200 20]);
    lst_conf = uilistbox(left_p, 'Position', [10 10 240 215], 'Multiselect', 'on', 'ValueChangedFcn', @plot_update);
    
    targs_full = {}; % Contingut filtrat actual
    
    % --- COSS CENTRAL: TAB GROUP ---
    tg = uitabgroup(fig, 'Position', [290 15 945 850]);
    
    % Creació de pestanyes (mateixa funcionalitat)
    % Pestanyes de Potència (Composta: Comparatiu + Individual)
    t1a=uitab(tg,'Title','Batt Power'); 
    ax_pb_c=uiaxes(t1a,'Position', [60 460 830 340]); title(ax_pb_c, 'Comparatiu Batt'); grid(ax_pb_c,'on');
    ax_pb_1=uiaxes(t1a,'Position', [60 60 400 340]);  grid(ax_pb_1,'on');
    ax_pb_2=uiaxes(t1a,'Position', [490 60 400 340]); grid(ax_pb_2,'on');
    xlabel(ax_pb_c, 'Distància (m)'); ylabel(ax_pb_c, 'Potència (kW)');
    xlabel(ax_pb_1, 'Distància (m)'); ylabel(ax_pb_1, 'Potència (kW)');
    xlabel(ax_pb_2, 'Distància (m)'); ylabel(ax_pb_2, 'Potència (kW)');

    t1b=uitab(tg,'Title','Engine power'); 
    ax_pm_c=uiaxes(t1b,'Position', [60 460 830 340]); title(ax_pm_c, 'Comparatiu Engine'); grid(ax_pm_c,'on');
    ax_pm_1=uiaxes(t1b,'Position', [60 60 400 340]);  grid(ax_pm_1,'on');
    ax_pm_2=uiaxes(t1b,'Position', [490 60 400 340]); grid(ax_pm_2,'on');
    xlabel(ax_pm_c, 'Distància (m)'); ylabel(ax_pm_c, 'Potència (kW)');
    xlabel(ax_pm_1, 'Distància (m)'); ylabel(ax_pm_1, 'Potència (kW)');
    xlabel(ax_pm_2, 'Distància (m)'); ylabel(ax_pm_2, 'Potència (kW)');

    t1c=uitab(tg,'Title','Wheel Power'); 
    ax_pw_c=uiaxes(t1c,'Position', [60 460 830 340]); title(ax_pw_c, 'Comparatiu Wheel'); grid(ax_pw_c,'on');
    ax_pw_1=uiaxes(t1c,'Position', [60 60 400 340]);  grid(ax_pw_1,'on');
    ax_pw_2=uiaxes(t1c,'Position', [490 60 400 340]); grid(ax_pw_2,'on');
    xlabel(ax_pw_c, 'Distància (m)'); ylabel(ax_pw_c, 'Potència (kW)');
    xlabel(ax_pw_1, 'Distància (m)'); ylabel(ax_pw_1, 'Potència (kW)');
    xlabel(ax_pw_2, 'Distància (m)'); ylabel(ax_pw_2, 'Potència (kW)');
    
    t2=uitab(tg,'Title','Battery Deep');
    ax_v=uiaxes(t2,'Position',[60 560 400 220]); title(ax_v,'Voltatge'); ax_i=uiaxes(t2,'Position',[480 560 400 220]); title(ax_i,'Corrent');
    ax_soc=uiaxes(t2,'Position',[60 310 400 220]); title(ax_soc,'SOC (%)'); ax_tmp=uiaxes(t2,'Position',[480 310 400 220]); title(ax_tmp,'Temp. Bateria');
    ax_res=uiaxes(t2,'Position',[60 60 820 220]); title(ax_res,'Resistència Interna');
    xlabel(ax_v, 'Distància (m)'); ylabel(ax_v, 'Voltatge (V)');
    xlabel(ax_i, 'Distància (m)'); ylabel(ax_i, 'Corrent (A)');
    xlabel(ax_soc, 'Distància (m)'); ylabel(ax_soc, 'SOC (%)');
    xlabel(ax_tmp, 'Distància (m)'); ylabel(ax_tmp, 'Temperatura (\circC)');
    xlabel(ax_res, 'Distància (m)'); ylabel(ax_res, 'Resistència (\Omega)');
    
    t4=uitab(tg,'Title','Motor Analysis');
    ax_trq=uiaxes(t4,'Position',[60 640 820 170]); title(ax_trq,'Parell Motor'); ylabel(ax_trq,'Parell (N\cdotm)'); xlabel(ax_trq,'Distància (m)');
    ax_rpm=uiaxes(t4,'Position',[60 460 820 170]); title(ax_rpm,'RPM Motor');    ylabel(ax_rpm,'RPM'); xlabel(ax_rpm,'Distància (m)');
    ax_idq=uiaxes(t4,'Position',[60 40 400 400]);  title(ax_idq, 'DQ Current Locus (I_q vs I_d)'); xlabel(ax_idq, 'I_d (A)'); ylabel(ax_idq, 'I_q (A)');
    ax_cur=uiaxes(t4,'Position',[480 40 400 400]); title(ax_cur,'Torque vs RPM Envelope'); xlabel(ax_cur, 'RPM'); ylabel(ax_cur, 'Parell (N\cdotm)');

    t6=uitab(tg,'Title','Thermal Motor');
    ax_dyn  = uiaxes(t6,'Position',[60 660 820 155]); title(ax_dyn, 'Dynamic Profile (RPM / I_{rms})');
    xlabel(ax_dyn,'Distància (m)');
    ax_tcu  = uiaxes(t6,'Position',[60 500 820 148]); title(ax_tcu, 'Temperature Winding');
    ax_tcl  = uiaxes(t6,'Position',[60 340 820 148]); title(ax_tcl, 'Coolant Temperatures');
    ax_irms = uiaxes(t6,'Position',[60 180 820 148]); title(ax_irms,'I_{rms} Phase Current (A)');
    ax_qf   = uiaxes(t6,'Position',[60 20  820 148]); title(ax_qf,  'Dissipation Q (W)');
    xlabel(ax_tcu,'Distància (m)'); ylabel(ax_tcu,'T_{wind} (\circC)');
    xlabel(ax_tcl,'Distància (m)'); ylabel(ax_tcl,'T (\circC)');
    xlabel(ax_irms,'Distància (m)'); ylabel(ax_irms,'I_{rms} (A)');
    xlabel(ax_qf,'Distància (m)'); ylabel(ax_qf,'Q (W)');
    
    t3=uitab(tg,'Title','Technical Summary');
    uit_res=uitable(t3,'Position',[20 20 900 780],'ColumnName',{'Configuració','Corba','Massa','V Max','T 1V','Window','T Mot Max','Ah(1V)','Ah(7V)','kWh','Estat'});

    t7=uitab(tg,'Title','Race Laps');
    ax_lt = uiaxes(t7,'Position',[60 500 820 300]); title(ax_lt,'Time per Lap (s)');
    xlabel(ax_lt, 'Volta'); ylabel(ax_lt, 'Temps (s)');
    uit_laps=uitable(t7,'Position',[20 20 900 450],'ColumnName',{'Configuració', 'Mètrica', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'Total'});

    t8=uitab(tg,'Title','Derating Map');
    ax_dmot = uiaxes(t8,'Position', [60 520 820 260]); title(ax_dmot,'Motor Derating Factor (k)');
    ax_dbat = uiaxes(t8,'Position', [60 280 820 230]); title(ax_dbat,'Battery Derating Factor (k)');
    xlabel(ax_dmot, 'Distància (m)'); ylabel(ax_dmot, 'Derating Factor (K)');
    xlabel(ax_dbat, 'Distància (m)'); ylabel(ax_dbat, 'Derating Factor (K)');
    uit_derat_specs = uitable(t8, 'Position', [60 20 820 240]);

    t9 = uitab(tg, 'Title', 'Velocity Prof.');
    ax_v7v = uiaxes(t9, 'Position', [60 180 820 600]); title(ax_v7v, 'Profile Velocity');
    xlabel(ax_v7v, 'Distància (m)'); ylabel(ax_v7v, 'Velocitat (km/h)');
    sld_v7v = uislider(t9, 'Position', [100 100 720 3], 'Limits', [0 1500]);
    uilabel(t9, 'Text', 'Ventana tiempo (150s):', 'Position', [100 120 300 20], 'FontWeight', 'bold');

    t10 = uitab(tg, 'Title', 'Lap Overlay');
    ax_v1v = uiaxes(t10, 'Position', [60 60 830 720]); title(ax_v1v, 'Speed Lap-to-Lap Overlay');
    xlabel(ax_v1v, 'Distància Relativa (m)'); ylabel(ax_v1v, 'Velocitat (km/h)');

    t11 = uitab(tg, 'Title', 'Gear Shifts');
    ax_gears = uiaxes(t11, 'Position', [60 180 830 620]); title(ax_gears, 'Gears Lap-to-Lap Overlay');
    xlabel(ax_gears, 'Distància Relativa (m)'); ylabel(ax_gears, 'Marxa');
    lbl_gears = uilabel(t11, 'Text', 'Canvis: -', 'Position', [60 100 400 40], 'FontSize', 18, 'FontWeight', 'bold', 'FontColor', [0.6 0.1 0.1]);

    t12 = uitab(tg, 'Title', '⚡ Torque Limits');
    ax_trq_cmp = uiaxes(t12, 'Position', [60 470 820 340]); 
    title(ax_trq_cmp, 'Parell Demanat vs Entregat (N·m)');
    xlabel(ax_trq_cmp, 'Distància (m)'); ylabel(ax_trq_cmp, 'Parell (N·m)');
    ax_vlim    = uiaxes(t12, 'Position', [60 240 820 210]);
    title(ax_vlim, 'Tensió Bus (V) - Filtrada');
    xlabel(ax_vlim, 'Distància (m)'); ylabel(ax_vlim, 'V_{bus} (V)');
    ax_trqdiff = uiaxes(t12, 'Position', [60 30 820 190]);
    title(ax_trqdiff, 'Diferència Parell Perdut per Limitació (N·m)');
    xlabel(ax_trqdiff, 'Distància (m)'); ylabel(ax_trqdiff, '\DeltaParell (N·m)');

    axs = [ax_pb_c, ax_pb_1, ax_pb_2, ax_pm_c, ax_pm_1, ax_pm_2, ax_pw_c, ax_pw_1, ax_pw_2, ax_v, ax_i, ax_soc, ax_tmp, ax_res, ax_trq, ax_rpm, ax_idq, ax_cur, ax_tcu, ax_dyn, ax_tcl, ax_irms, ax_qf, ax_lt, ax_dmot, ax_dbat, ax_v7v, ax_v1v, ax_gears, ax_trq_cmp, ax_vlim, ax_trqdiff];

    % --- FUNCIONS DE LÒGICA ---

    function filter_changed(~,~)
        % Obtenir valors seleccionats de tots els sub-filtres
        sel_b = {}; for i=1:length(chk_b), if chk_b{i}.Value, sel_b{end+1}=chk_b{i}.Text; end; end
        sel_tx = {}; for i=1:length(chk_tx), if chk_tx{i}.Value, sel_tx{end+1}=chk_tx{i}.Text; end; end
        sel_p = []; for i=1:length(chk_p), if chk_p{i}.Value, sel_p(end+1)=str2double(chk_p{i}.Text(1:end-1)); end; end
        
        r_min = dd_rmin.Value; r_max = dd_rmax.Value;
        
        targs_full = {}; noms = {}; 
        for i=1:length(res_all)
            r = res_all{i};
            tx_name = ifElse(r.is_caja, 'Caixa', 'Directe');
            
            % Match AND
            m_b = any(strcmp(r.brand, sel_b));
            m_tx = any(strcmp(tx_name, sel_tx));
            m_p = any(r.scaling == sel_p);
            m_rm = ifElse(strcmp(r_min,'Tots'), true, r.RMin == str2double(r_min));
            m_rx = ifElse(strcmp(r_max,'Tots'), true, r.RMax == str2double(r_max));
            
            if m_b && m_tx && m_p && m_rm && m_rx
                targs_full{end+1} = r; noms{end+1} = r.nom_configuracio; 
            end
        end
        lst_conf.Items = noms;
        lst_conf.Value = noms; 
        plot_update();
    end

    function plot_update(~,~)
        sel = lst_conf.Value; if isempty(sel), sel={}; end
        if ischar(sel), sel={sel}; end
        targs = {};
        for i=1:length(targs_full)
            if any(strcmp(targs_full{i}.nom_configuracio, sel)), targs{end+1} = targs_full{i}; end
        end
        
        % Reset ejes
        for a = axs
            if a == ax_dyn
                yyaxis(a,'left'); cla(a); yyaxis(a,'right'); cla(a); yyaxis(a,'left');
            else
                cla(a);
            end
            hold(a,'on'); grid(a,'on'); a.Title.FontSize = 14;
            a.XAxis.Exponent = 0; % Evitar notació científica 10^4 a l'eix X
        end
        % Estil específic per la pestanya de Torque Limits
        ax_trq_cmp.YLabel.String = 'Parell (N·m)';
        ax_vlim.YLabel.String    = 'V_{bus} (V)';
        yline(ax_vlim, 126, '--k', 'V_{nom}=126V', 'LabelHorizontalAlignment','left', 'HandleVisibility','off');
        ax_trqdiff.YLabel.String = '\DeltaParell perdut (N·m)';
        
        if isempty(targs), uit_res.Data={}; uit_laps.Data={}; return; end
        
        data=cell(length(targs),11); data_laps=cell(length(targs)*3,10);
        cmap = lines(max(7, length(targs))); sty={'-','--',':','-.'};
        
        for k=1:length(targs)
            try
                r = targs{k}; c = cmap(k,:); s = sty{mod(k-1,4)+1};
                
                % Distància i eixos comuns (Motor Sampling: dt, Battery Sampling: 0.5s)
                if isfield(r, 'distancia_7v') && ~isempty(r.distancia_7v)
                    tt = r.distancia_7v(:)'; % Assegurem que és vector fila com abans
                else
                    % Fallback per simulacions processades abans del canvi a distància
                    tt = (0:length(r.T_winding_7v)-1) * r.dt;
                end
                
                % tp necessita mapar el temps 0.5s a distància
                t_tp_temps = (0:length(r.P_batt_7v)-1) * 0.5;
                t_tt_temps = (0:length(tt)-1) * r.dt;
                
                if length(t_tp_temps) > 1 && length(t_tt_temps) > 1
                    t_tp_temps_sat = min(max(t_tp_temps, t_tt_temps(1)), t_tt_temps(end));
                    tp = interp1(t_tt_temps, tt, t_tp_temps_sat, 'linear', 'extrap');
                else
                    tp = t_tp_temps; % Fallback
                end

                % 1. Power Analysis (ax_pb_c, ax_pm_c, ax_pw_c)
                plot(ax_pb_c, tp, r.P_batt_7v/1000, 'Color', c, 'LineWidth', 1.2, 'DisplayName', r.nom_configuracio);
                plot(ax_pm_c, tp, r.P_mech_7v/1000, 'Color', c, 'LineWidth', 1.2, 'DisplayName', r.nom_configuracio);
                
                if isfield(r, 'P_wheel_7v')
                    pw_data = r.P_wheel_7v;
                else
                    eff = ifElse(r.is_caja, 0.78, 0.90); 
                    if isfield(r, 'Rendiment_total'), eff = r.Rendiment_total; end
                    pw_data = r.P_mech_7v * eff;
                end
                plot(ax_pw_c, tp, pw_data/1000, 'Color', c, 'LineWidth', 1.2, 'DisplayName', r.nom_configuracio);

                % Línies de Potència Equivalent (Mitjana)
                p_eq_b = mean(r.P_batt_7v)/1000;
                p_eq_m = mean(r.P_mech_7v)/1000;
                p_eq_w = mean(pw_data)/1000;
                
                % Stagger labels in comparison to avoid piling up
                v_align = ifElse(mod(k,2)==0, 'top', 'bottom');
                yline(ax_pb_c, p_eq_b, '--', 'Color', c, 'Label', sprintf('P_{eq}=%.2fkW', p_eq_b), 'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', 'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', v_align);
                yline(ax_pm_c, p_eq_m, '--', 'Color', c, 'Label', sprintf('P_{eq}=%.2fkW', p_eq_m), 'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', 'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', v_align);
                yline(ax_pw_c, p_eq_w, '--', 'Color', c, 'Label', sprintf('P_{eq}=%.2fkW', p_eq_w), 'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', 'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', v_align);

                % Plot Individual (si és el primer o segon seleccionat)
                if k == 1
                    plot(ax_pb_1, tp, r.P_batt_7v/1000, 'Color', c, 'LineWidth', 1.2); title(ax_pb_1, r.nom_configuracio, 'FontSize', 9);
                    plot(ax_pm_1, tp, r.P_mech_7v/1000, 'Color', c, 'LineWidth', 1.2); title(ax_pm_1, r.nom_configuracio, 'FontSize', 9);
                    plot(ax_pw_1, tp, pw_data/1000,    'Color', c, 'LineWidth', 1.2); title(ax_pw_1, r.nom_configuracio, 'FontSize', 9);
                    yline(ax_pb_1, p_eq_b, '--', 'Color', 'k', 'Label', sprintf('P_{eq}=%.2fkW', p_eq_b), 'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', 'LabelHorizontalAlignment', 'right');
                    yline(ax_pm_1, p_eq_m, '--', 'Color', 'k', 'Label', sprintf('P_{eq}=%.2fkW', p_eq_m), 'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', 'LabelHorizontalAlignment', 'right');
                    yline(ax_pw_1, p_eq_w, '--', 'Color', 'k', 'Label', sprintf('P_{eq}=%.2fkW', p_eq_w), 'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', 'LabelHorizontalAlignment', 'right');
                elseif k == 2
                    plot(ax_pb_2, tp, r.P_batt_7v/1000, 'Color', c, 'LineWidth', 1.2); title(ax_pb_2, r.nom_configuracio, 'FontSize', 9);
                    plot(ax_pm_2, tp, r.P_mech_7v/1000, 'Color', c, 'LineWidth', 1.2); title(ax_pm_2, r.nom_configuracio, 'FontSize', 9);
                    plot(ax_pw_2, tp, pw_data/1000,    'Color', c, 'LineWidth', 1.2); title(ax_pw_2, r.nom_configuracio, 'FontSize', 9);
                    yline(ax_pb_2, p_eq_b, '--', 'Color', 'k', 'Label', sprintf('P_{eq}=%.2fkW', p_eq_b), 'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', 'LabelHorizontalAlignment', 'right');
                    yline(ax_pm_2, p_eq_m, '--', 'Color', 'k', 'Label', sprintf('P_{eq}=%.2fkW', p_eq_m), 'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', 'LabelHorizontalAlignment', 'right');
                    yline(ax_pw_2, p_eq_w, '--', 'Color', 'k', 'Label', sprintf('P_{eq}=%.2fkW', p_eq_w), 'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', 'LabelHorizontalAlignment', 'right');
                end




                % 2. Battery Analysis (ax_v, ax_i, ax_soc, ax_tmp, ax_res)
                % Prioritzem les dades d'ALTA RESOLUCIÓ (100Hz) gravades de la simulació
                if isfield(r, 'V_batt_7v') && ~isempty(r.V_batt_7v)
                    tv_high = tt(1:length(r.V_batt_7v));
                    plot(ax_v,   tv_high, r.V_batt_7v,     'Color', c, 'DisplayName', r.nom_configuracio);
                    plot(ax_i,   tv_high, r.I_batt_int_7v, 'Color', c, 'DisplayName', r.nom_configuracio);
                    plot(ax_soc, tv_high, r.SOC_int_7v*100, 'Color', c, 'DisplayName', r.nom_configuracio);
                    
                    % La temperatura i resistència solen venir del model tèrmic de bateria (0.5s)
                    [~,~,~,~,~,~,~,T_b,R_b]=battery(r.Ns,r.Np,r.cell_type,r.P_batt_7v); 
                    tb = tp(1:min(length(tp), length(T_b)));
                    plot(ax_tmp, tb, T_b, 'Color', c, 'DisplayName', r.nom_configuracio);
                    plot(ax_res, tb, R_b, 'Color', c, 'DisplayName', r.nom_configuracio);
                else
                    % Fallback per a simulacions antigues: re-simular a 0.5s
                    [~,~,~,~,V,I,SOC_v,T_b,R_b]=battery(r.Ns,r.Np,r.cell_type,r.P_batt_7v); 
                    tb = tp(1:min(length(tp), length(V)));
                    plot(ax_v,tb,V,'Color',c,'DisplayName',r.nom_configuracio);
                    plot(ax_i,tb,I,'Color',c,'DisplayName',r.nom_configuracio);
                    plot(ax_soc,tb,SOC_v*100,'Color',c,'DisplayName',r.nom_configuracio);
                    tb_t = tp(1:min(length(tp), length(T_b)));
                    plot(ax_tmp, tb_t, T_b, 'Color', c, 'DisplayName', r.nom_configuracio);
                    plot(ax_res, tb_t, R_b, 'Color', c, 'DisplayName', r.nom_configuracio);
                end
                
                % 3. Motor Analysis (ax_trq, ax_rpm, ax_idq, ax_cur)
                tmec = tt(1:length(r.parell_motor));
                plot(ax_trq,tmec,r.parell_motor,'Color',c,'DisplayName',r.nom_configuracio);
                plot(ax_rpm,tmec,r.rpm,'Color',c,'DisplayName',r.nom_configuracio);
                if isfield(r, 'Id_7v') && isfield(r, 'Iq_7v') && ~isempty(r.Id_7v)
                    n_idq = min(length(r.Id_7v), length(r.Iq_7v));
                    plot(ax_idq, r.Id_7v(1:n_idq), r.Iq_7v(1:n_idq), 'Color', c, 'DisplayName', r.nom_configuracio);
                end
                wrpm = 0:100:7500;
                if strcmp(r.motor, 'Vilanova'), f_base = f_vil; else, f_base = f_mot; end
                plot(ax_cur,wrpm,f_base(wrpm)*(1+r.scaling/100),'Color',c,'LineWidth',1.5, 'HandleVisibility','off');

                % 4. Thermal & Dynamic (ax_dyn, ax_tcu, ax_tcl, ax_irms, ax_qf)
                yyaxis(ax_dyn,'left');
                plot(ax_dyn, tt, r.rpm_7v, 'Color', c, 'LineWidth', 1.0, 'DisplayName', r.nom_configuracio);
                ylabel(ax_dyn,'RPM');
                yyaxis(ax_dyn,'right');
                if isfield(r,'I_rms_7v') && ~isempty(r.I_rms_7v)
                    n_ir = min(length(tt), length(r.I_rms_7v));
                    irms_data = r.I_rms_7v(1:n_ir);
                    plot(ax_dyn, tt(1:n_ir), irms_data, 'Color', c, 'LineStyle', ':', 'LineWidth', 1.2, 'HandleVisibility','off');
                    ylabel(ax_dyn,'I_{rms} (A)');
                    
                    % Línia Irms equivalent (ax_dyn)
                    i_eq = mean(irms_data);
                    v_align = ifElse(mod(k,2)==0, 'top', 'bottom');
                    yline(ax_dyn, i_eq, '--', 'Color', c, 'Label', sprintf('I_{rms,eq}=%.1fA', i_eq), 'LineWidth', 1.5, ...
                        'FontSize', 10, 'FontWeight', 'bold', 'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', v_align);
                else
                    plot(ax_dyn, tt, r.trq_7v, 'Color', c, 'LineStyle', ':', 'HandleVisibility','off');
                    ylabel(ax_dyn,'Parell (N\cdotm)');
                end
                plot(ax_tcu, tt, r.T_winding_7v, 'Color', c, 'LineWidth', 1.5, 'DisplayName', r.nom_configuracio);
                yline(ax_tcu, 120, ':k', 'T_{max}=120\circC', 'LabelHorizontalAlignment','left', 'HandleVisibility','off');
                plot(ax_tcl, tt, r.T_cool_out_7v, 'Color', c, 'LineWidth', 1.2, 'DisplayName', ['Out: ' r.nom_configuracio]);
                plot(ax_tcl, tt, r.T_cool_in_7v,  'Color', c, 'LineStyle', ':', 'DisplayName', ['In: '  r.nom_configuracio]);
                % I_rms subplot
                if isfield(r,'I_rms_7v') && ~isempty(r.I_rms_7v)
                    n_ir = min(length(tt), length(r.I_rms_7v));
                    irms_data = r.I_rms_7v(1:n_ir);
                    plot(ax_irms, tt(1:n_ir), irms_data, 'Color', c, 'LineWidth', 1.2, 'DisplayName', r.nom_configuracio);
                    
                    % Línia Irms equivalent (ax_irms)
                    i_eq = mean(irms_data);
                    v_align = ifElse(mod(k,2)==0, 'top', 'bottom');
                    yline(ax_irms, i_eq, '--', 'Color', c, 'Label', sprintf('I_{rms,eq}=%.1fA', i_eq), 'LineWidth', 2, ...
                        'FontSize', 11, 'FontWeight', 'bold', 'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'left', 'LabelVerticalAlignment', v_align);
                end
                plot(ax_qf, tt, r.Q_cool_7v, 'Color', c, 'DisplayName', r.nom_configuracio);
                
                % 5. Derating Maps (ax_dmot, ax_dbat)
                if isfield(r, 'k_mot_7v') && ~isempty(r.k_mot_7v)
                    plot(ax_dmot, tt, r.k_mot_7v, 'Color', c, 'LineWidth', 1.5, 'DisplayName', r.nom_configuracio);
                elseif isfield(r, 'factor_derat_7v')
                    plot(ax_dmot, tt, r.factor_derat_7v, 'Color', c, 'LineWidth', 1.5, 'DisplayName', r.nom_configuracio);
                end
                
                if isfield(r, 'k_bat_7v') && ~isempty(r.k_bat_7v)
                    plot(ax_dbat, tt, r.k_bat_7v, 'Color', c, 'LineWidth', 1.5, 'DisplayName', r.nom_configuracio);
                else
                    k_bat = interp1(r.applied_derat.bat_T, r.applied_derat.bat_k, T_b, 'linear', 'extrap');
                    plot(ax_dbat, tb, max(0,min(1,k_bat)), 'Color', c, 'LineWidth', 1.5, 'DisplayName', r.nom_configuracio);
                end
                
                % 6. Velocity & Laps (ax_v7v, ax_v1v, ax_gears)
                if isfield(r, 'velocitat_kmh_7v')
                    plot(ax_v7v, tt, r.velocitat_kmh_7v, 'Color', c, 'LineWidth', 1.5, 'DisplayName', r.nom_configuracio);
                    for v_id=1:length(r.laps_vel)
                        if ~isempty(r.laps_vel{v_id})
                            shade = c * (0.3+0.7*(v_id/7));
                            plot(ax_v1v, r.laps_dist{v_id}, r.laps_vel{v_id}, 'Color', shade, 'HandleVisibility', 'off');
                            if isfield(r, 'marxa_laps') && ~isempty(r.marxa_laps{v_id})
                                tl = r.laps_dist{v_id}(1:length(r.marxa_laps{v_id}));
                                plot(ax_gears, tl, r.marxa_laps{v_id}, 'Color', shade, 'HandleVisibility', 'off');
                            end
                        end
                    end
                    if isfield(r, 'total_canvis_race'), lbl_gears.Text = sprintf('Canvis: %d', r.total_canvis_race); end
                end

                % 8. Torque Limits tab (ax_trq_cmp, ax_vlim, ax_trqdiff)
                % Eix de distància compartit per totes les senyals mecàniques (7 voltes)
                trq_data = r.parell_motor;
                if isfield(r, 'trq_7v') && ~isempty(r.trq_7v), trq_data = r.trq_7v; end
                tmec = tt(1:length(trq_data));
                
                % Plot parell entregat
                plot(ax_trq_cmp, tmec, trq_data, 'Color', c, 'LineWidth', 1.0, ...
                    'DisplayName', [r.nom_configuracio ' - Entregat']);
                
                % Plot parell demanat (discontínua) i àrea de pèrdua
                if isfield(r, 'parell_demanat_7v') && ~isempty(r.parell_demanat_7v)
                    n_min = min(length(tmec), length(r.parell_demanat_7v));
                    plot(ax_trq_cmp, tmec(1:n_min), r.parell_demanat_7v(1:n_min), ...
                        'Color', c, 'LineWidth', 0.8, 'LineStyle', '--', ...
                        'DisplayName', [r.nom_configuracio ' - Demanat']);
                    delta_trq = r.parell_demanat_7v(1:n_min) - trq_data(1:n_min);
                    delta_trq(delta_trq < 0) = 0;
                    area(ax_trqdiff, tmec(1:n_min), delta_trq, 'FaceColor', c, ...
                        'FaceAlpha', 0.85, 'EdgeColor', c, ...
                        'DisplayName', r.nom_configuracio);
                end
                
                % Plot voltatge del model integrat (7 voltes acumulades, dt=0.01s)
                if isfield(r, 'V_batt_7v') && ~isempty(r.V_batt_7v)
                    tvb = tt(1:length(r.V_batt_7v));
                    plot(ax_vlim, tvb, r.V_batt_7v, 'Color', c, 'LineWidth', 1.2, ...
                        'DisplayName', r.nom_configuracio);
                    % Alinear el rang x de v amb el dels altres dos plots
                    xlim(ax_vlim, [0, tmec(end)]);
                elseif isfield(r, 'V_batt') && ~isempty(r.V_batt)
                    % Fallback: usar l'última volta si no hi ha l'acumulat
                    tvb = tt(1:min(length(tt), length(r.V_batt)));
                    plot(ax_vlim, tvb, r.V_batt, 'Color', c, 'LineWidth', 1.2, ...
                        'LineStyle', ':', 'DisplayName', [r.nom_configuracio ' (1 volta)']);
                end
                
                % 7. Data Tables
                m1=floor(r.temps_1_volta/60); s1=mod(r.temps_1_volta,60);
                data{k,1}=r.nom_configuracio; data{k,2}=r.motor; data{k,3}=sprintf('%.1f', r.M_total);
                if isfield(r, 'velocitat_kmh_7v'), data{k,4}=sprintf('%.1f', max(r.velocitat_kmh_7v)); else, data{k,4}='-'; end
                data{k,5}=sprintf('%d:%05.2f',m1,s1); data{k,6}=sprintf('%d-%d',r.RMin,r.RMax); data{k,7}=sprintf('%.1f',r.T_max_mot); 
                data{k,8}=sprintf('%.2f',r.Ah_1v); data{k,9}=sprintf('%.2f',r.consum_Ah); data{k,10}=sprintf('%.2f',r.consum_kWh); data{k,11}=r.bat_status;

                row_idx = (k-1)*3 + 1;
                data_laps{row_idx, 1} = r.nom_configuracio; data_laps{row_idx, 2} = 'Temps';
                data_laps{row_idx+1, 1} = r.nom_configuracio; data_laps{row_idx+1, 2} = 'Consum (Ah)';
                data_laps{row_idx+2, 1} = r.nom_configuracio; data_laps{row_idx+2, 2} = 'Consum (kWh)';
                
                if isfield(r, 'laps_time_array')
                    for v_idx=1:7
                        if length(r.laps_time_array) >= v_idx && r.laps_time_array(v_idx) > 0
                            tv = r.laps_time_array(v_idx); 
                            data_laps{row_idx, v_idx+2} = sprintf('%d:%05.2f',floor(tv/60),mod(tv,60));
                            
                            if isfield(r, 'laps_Ah_array')
                                data_laps{row_idx+1, v_idx+2} = sprintf('%.2f', r.laps_Ah_array(v_idx));
                                data_laps{row_idx+2, v_idx+2} = sprintf('%.2f', r.laps_kWh_array(v_idx));
                            end
                        end
                    end
                    v_v = find(r.laps_time_array > 0); plot(ax_lt, v_v, r.laps_time_array(v_v), 'Marker','o', 'Color',c, 'DisplayName', r.nom_configuracio);
                    
                    data_laps{row_idx, 10} = sprintf('%d:%05.2f',floor(r.temps_total/60),mod(r.temps_total,60));
                    if isfield(r, 'consum_Ah')
                        data_laps{row_idx+1, 10} = sprintf('%.2f', r.consum_Ah);
                        data_laps{row_idx+2, 10} = sprintf('%.2f', r.consum_kWh);
                    end
                end
            catch ME
                fprintf('Error dibuixant sim %d (%s): %s\n', k, r.nom_configuracio, ME.message);
            end
        end
        
        % Restaurar taula de specs de derating (usant dades del primer target si n'hi ha)
        if ~isempty(targs)
            r1 = targs{1};
            if isfield(r1, 'applied_derat')
                uit_derat_specs.ColumnName = {'Transmissió', 'Sistema', 'Estat', 'Temp Pts (°C)', 'K Factors'};
                
                dm_st = 'ACTIVE (ON)'; if isfield(r1.applied_derat, 'active_mot') && ~r1.applied_derat.active_mot, dm_st = 'DISABLED (OFF)'; end
                db_st = 'ACTIVE (ON)'; if isfield(r1.applied_derat, 'active_bat') && ~r1.applied_derat.active_bat, db_st = 'DISABLED (OFF)'; end
                
                uit_derat_specs.Data = {
                    'SELECTED', 'MOTOR', dm_st, num2str(r1.applied_derat.mot_T), num2str(r1.applied_derat.mot_k);
                    'SELECTED', 'BATERIA', db_st, num2str(r1.applied_derat.bat_T), num2str(r1.applied_derat.bat_k)
                };
            end
        end
        
        % Afegir Línies Verticals per delimitar les Voltes (excepte axes de Lap Overlay / idq / etc)
        if ~isempty(targs)
            r1 = targs{1};
            if isfield(r1, 'laps_dist')
                bounds = [];
                curr_dist = 0;
                for v_id = 1:length(r1.laps_dist)
                    if ~isempty(r1.laps_dist{v_id})
                        curr_dist = curr_dist + max(r1.laps_dist{v_id});
                        bounds(end+1) = curr_dist;
                    end
                end
                
                % Llista d'eixos basats en distància acumulada (7 voltes)
                axs_v = [ax_pb_c, ax_pb_1, ax_pb_2, ax_pm_c, ax_pm_1, ax_pm_2, ax_pw_c, ax_pw_1, ax_pw_2, ...
                         ax_v, ax_i, ax_soc, ax_tmp, ax_res, ax_trq, ax_rpm, ax_tcu, ax_dyn, ax_tcl, ...
                         ax_irms, ax_qf, ax_dmot, ax_dbat, ax_v7v, ax_trq_cmp, ax_vlim, ax_trqdiff];
                         
                if length(bounds) > 1
                    for b = bounds(1:end-1) % Ocultar l'última marca (meta final)
                        for a = axs_v
                            xline(a, b, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.2, 'HandleVisibility', 'off');
                        end
                    end
                end
            end
        end
        
        uit_res.Data=data; uit_laps.Data=data_laps; for a=axs, hold(a,'off'); legend(a,'Location','best','FontSize',9,'Interpreter','none'); end
    end

    function export_to_excel()
        sel = lst_conf.Value; if isempty(sel), uialert(fig,'No hi ha cap simulació seleccionada per exportar.','Error'); return; end
        if ischar(sel), sel={sel}; end
        
        if ~ensure_output_folder(), return; end
        
        t_exp = table();
        for i=1:length(targs_full)
            if any(strcmp(targs_full{i}.nom_configuracio, sel))
                r = targs_full{i};
                nr = table({r.nom_configuracio}, {r.motor}, r.scaling, r.is_caja, r.M_total, r.temps_1_volta, r.temps_total, r.consum_kWh, r.T_max_mot, ...
                    'VariableNames', {'Config', 'Motor', 'Scaling', 'Gearbox', 'Mass', 'Lap1_Time', 'Total_Time', 'Energy_kWh', 'Max_Temp_Mot'});
                t_exp = [t_exp; nr];
            end
        end
        
        xlsx_path = fullfile(export_folder, 'Resum_Comparatiu_DOE.xlsx');
        writetable(t_exp, xlsx_path);
        uialert(fig, ['Dades exportades correctament a:\n', xlsx_path], 'Exportació OK');
    end

    function save_session_data(res, fv, fm, dc, dd)
        if ~ensure_output_folder(), return; end
        resultats = res; f_vil = fv; f_mot = fm; derat_c = dc; derat_d = dd;
        mat_path = fullfile(export_folder, 'Simulacio_DOE5.mat');
        save(mat_path, 'resultats', 'f_vil', 'f_mot', 'derat_c', 'derat_d');
        uialert(fig, ['Sessió guardada correctament a:\n', mat_path], 'OK');
    end

    % =========================================================================
    % CARPETA DE SESSIÓ: demana nom una sola vegada i crea CONCLUSIONS/<nom>
    % =========================================================================
    function ok = ensure_output_folder()
        ok = false;
        if ~isempty(export_folder) && exist(export_folder, 'dir')
            ok = true; return;
        end
        % CONCLUSIONS es 2 nivells amunt del Dashboard (DOE_Final\CONCLUSIONS)
        script_dir = fileparts(mfilename('fullpath'));
        conclusions_dir = fullfile(script_dir, '..', '..', 'CONCLUSIONS');
        conclusions_dir = char(java.io.File(conclusions_dir).getCanonicalPath());
        if ~exist(conclusions_dir, 'dir'), mkdir(conclusions_dir); end
        
        default_nm = ['DOE5_' datestr(now, 'yyyymmdd_HHMMSS')];
        answer = inputdlg( ...
            sprintf('Nom de la carpeta on guardar els resultats:\n(es crear\u00e0 a CONCLUSIONS\\<nom>)'), ...
            'Nova Carpeta de Conclusions', [1 55], {default_nm});
        if isempty(answer) || isempty(strtrim(answer{1})), return; end
        
        folder_name = strtrim(answer{1});
        folder_name = regexprep(folder_name, '[<>:"/\\|?*]', '_');
        export_folder = fullfile(conclusions_dir, folder_name);
        if ~exist(export_folder, 'dir'), mkdir(export_folder); end
        fprintf('Carpeta de conclusions: %s\n', export_folder);
        
        % Actualitzar etiqueta del panel
        try
            lbl = findobj(fig, 'Type', 'uilabel', '-regexp', 'Text', '^.Carpeta:');
            if ~isempty(lbl), lbl(1).Text = sprintf('\U0001F4C1 %s', folder_name); end
        catch, end
        ok = true;
    end

    % =========================================================================
    % EXPORTACIÓ AUTOMÀTICA DE GRÀFICS PNG
    % =========================================================================
    function export_all_plots()
        if ~ensure_output_folder(), return; end
        % Les fotos es guarden a la subcarpeta Graphs/
        out_dir = fullfile(export_folder, 'Graphs');
        if ~exist(out_dir, 'dir'), mkdir(out_dir); end
        
        % Mapa de pestanyes: {nom, tab_object, {{'nom_ax', ax_handle}, ...}}
        tab_map = {
            'BattPower',     t1a, {{'Comparatiu',ax_pb_c},{'Config1',ax_pb_1},{'Config2',ax_pb_2}};
            'EnginePower',   t1b, {{'Comparatiu',ax_pm_c},{'Config1',ax_pm_1},{'Config2',ax_pm_2}};
            'WheelPower',    t1c, {{'Comparatiu',ax_pw_c},{'Config1',ax_pw_1},{'Config2',ax_pw_2}};
            'BatteryDeep',   t2,  {{'Voltage',ax_v},{'Current',ax_i},{'SOC',ax_soc},{'Temp',ax_tmp},{'Resistance',ax_res}};
            'MotorAnalysis', t4,  {{'Torque',ax_trq},{'RPM',ax_rpm},{'DQCurrent',ax_idq},{'Envelope',ax_cur}};
            'ThermalMotor',  t6,  {{'DynProfile',ax_dyn},{'Winding',ax_tcu},{'Coolant',ax_tcl},{'Irms',ax_irms},{'Dissipation',ax_qf}};
            'Derating',      t8,  {{'Motor',ax_dmot},{'Battery',ax_dbat}};
            'VelocityProf',  t9,  {{'Velocity7Laps',ax_v7v}};
            'LapOverlay',    t10, {{'LapOverlay',ax_v1v}};
            'GearShifts',    t11, {{'GearOverlay',ax_gears}};
            'TorqueLimits',  t12, {{'TorqueComparison',ax_trq_cmp},{'VoltageBus',ax_vlim},{'TorqueDelta',ax_trqdiff}};
        };
        
        original_tab = tg.SelectedTab;
        n_tabs = size(tab_map, 1);
        d_prog = uiprogressdlg(fig, 'Title', 'Exportant gràfics...', 'Cancelable', 'on', 'Value', 0);
        drawnow;
        tmp_fig = []; % Per cleanup en cas d'error
        
        try
            n_files_saved = 0;
            for ti = 1:n_tabs
                if d_prog.CancelRequested, break; end
                
                tab_name  = tab_map{ti, 1};
                tab_obj   = tab_map{ti, 2};
                axes_list = tab_map{ti, 3};  % Cell de {{'nom',ax}, ...}
                n_ax      = length(axes_list);
                
                d_prog.Message = sprintf('Renderitzant: %s (%d/%d)...', tab_name, ti, n_tabs);
                
                % *** CLAU: seleccionar la pestanya per forçar el render dels uiaxes ***
                tg.SelectedTab = tab_obj;
                drawnow; pause(0.15);
                
                            % --- A. Exportació INDIVIDUAL de cada axes (SEMPRE, incl. n_ax==1) ---
                % exportgraphics directament sobre uiaxes (la pestanya ja esta seleccionada)
                % -> evita copyobj -> funciona per LapOverlay, GearShifts, etc.
                for ai = 1:n_ax
                    ax_nm  = axes_list{ai}{1};
                    ax_obj = axes_list{ai}{2};
                    if ~isvalid(ax_obj), continue; end
                    ax_png = fullfile(out_dir, sprintf('%02d_%s__%s.png', ti, tab_name, ax_nm));
                    try
                        % Amagar llegenda temporalment per no tapar les dades
                        leg_hdl = ax_obj.Legend;
                        leg_was_visible = '';
                        if ~isempty(leg_hdl) && isvalid(leg_hdl)
                            leg_was_visible = leg_hdl.Visible;
                            leg_hdl.Visible = 'off';
                        end
                        exportgraphics(ax_obj, ax_png, 'Resolution', 200);
                        % Restaurar llegenda
                        if ~isempty(leg_hdl) && isvalid(leg_hdl) && ~isempty(leg_was_visible)
                            leg_hdl.Visible = leg_was_visible;
                        end
                        n_files_saved = n_files_saved + 1;
                    catch ME_ax
                        fprintf('Avis axes %s_%s: %s\n', tab_name, ax_nm, ME_ax.message);
                    end
                end
                
                % --- B. PNG COMBINAT de la pestanya (tots els axes junts) ---
                tmp_fig = figure('Visible', 'off', 'Color', 'w', ...
                    'Units', 'pixels', 'Position', [100 100 1400 900]);
                
                if     n_ax == 1, nr = 1; nc = 1;
                elseif n_ax <= 2, nr = 1; nc = 2;
                elseif n_ax <= 3, nr = 1; nc = 3;
                elseif n_ax <= 4, nr = 2; nc = 2;
                elseif n_ax <= 6, nr = 2; nc = 3;
                else,             nr = 3; nc = 3;
                end
                
                for ai = 1:n_ax
                    src_ax = axes_list{ai}{2};
                    if ~isvalid(src_ax), continue; end
                    
                    dst_ax = subplot(nr, nc, ai, 'Parent', tmp_fig);
                    copyobj(src_ax.Children, dst_ax);
                    axis(dst_ax, 'auto');
                    
                    try
                        dst_ax.XLabel.String = src_ax.XLabel.String;
                        dst_ax.YLabel.String = src_ax.YLabel.String;
                        dst_ax.Title.String  = src_ax.Title.String;
                        dst_ax.Title.FontSize = 11;
                        dst_ax.FontSize = 9;
                        xl = src_ax.XLim; yl = src_ax.YLim;
                        if (xl(2)-xl(1)) > 0, dst_ax.XLim = xl; end
                        if (yl(2)-yl(1)) > 0, dst_ax.YLim = yl; end
                        grid(dst_ax, 'on');
                        legend(dst_ax, 'Location', 'southoutside', 'FontSize', 7, 'Interpreter', 'none', 'NumColumns', 2);
                    catch
                    end
                end
                
                sgtitle(tmp_fig, sprintf('DOE 5 - %s', strrep(tab_name,'_',' ')), ...
                    'FontSize', 14, 'FontWeight', 'bold');
                tab_png = fullfile(out_dir, sprintf('%02d_%s_TAB.png', ti, tab_name));
                exportgraphics(tmp_fig, tab_png, 'Resolution', 200);
                close(tmp_fig); tmp_fig = [];
                n_files_saved = n_files_saved + 1;
                
                d_prog.Value = ti / n_tabs;
                drawnow;
            end
            
            tg.SelectedTab = original_tab;
            close(d_prog);
            uialert(fig, sprintf('✅ %d fitxers PNG guardats a:\n%s', n_files_saved, out_dir), 'Exportació completada');
        catch ME
            try, tg.SelectedTab = original_tab; catch, end
            try, close(d_prog); catch, end
            try, if ~isempty(tmp_fig) && ishandle(tmp_fig), close(tmp_fig); end; catch, end
            uialert(fig, sprintf('Error exportant: %s', ME.message), 'Error');
            fprintf('ERROR export_all_plots: %s\n', ME.message);
        end
    end

    % =========================================================================
    % GUARDAR FITXER DE PARÀMETRES BASE
    % =========================================================================
    function save_params_file()
        if ~ensure_output_folder(), return; end
        out_dir = export_folder;
        
        params_path = fullfile(out_dir, 'Parametres_Base_Simulacio.txt');
        fid = fopen(params_path, 'w');
        if fid == -1
            uialert(fig, 'No s''ha pogut crear el fitxer de paràmetres.', 'Error');
            return;
        end
        
        fprintf(fid, '================================================================\n');
        fprintf(fid, '  DOE 5 - PARÀMETRES BASE DE SIMULACIÓ\n');
        fprintf(fid, '  Generat: %s\n', datestr(now, 'dd/mm/yyyy HH:MM:SS'));
        fprintf(fid, '================================================================\n\n');
        
        % --- Paràmetres Base ---
        fprintf(fid, '--- PARÀMETRES BASE (p_base) ---\n');
        write_struct_fields(fid, p_base);
        
        % --- Paràmetres Caixa ---
        fprintf(fid, '\n--- PARÀMETRES CAIXA DE CANVIS (p_caixa) ---\n');
        write_struct_fields(fid, p_caixa);
        
        % --- Paràmetres Directe ---
        fprintf(fid, '\n--- PARÀMETRES TRANSMISSIÓ DIRECTA (p_dir) ---\n');
        write_struct_fields(fid, p_dir);
        
        % --- Configuracions simulades ---
        fprintf(fid, '\n--- CONFIGURACIONS SIMULADES ---\n');
        fprintf(fid, 'Nombre total de simulacions: %d\n\n', length(res_all));
        for k = 1:length(res_all)
            r = res_all{k};
            fprintf(fid, '[%d] %s\n', k, r.nom_configuracio);
            if isfield(r, 'M_total'),      fprintf(fid, '    Massa total: %.2f kg\n', r.M_total); end
            if isfield(r, 'RMin'),         fprintf(fid, '    RPM Min/Max: %d / %d\n', r.RMin, r.RMax); end
            if isfield(r, 'temps_1_volta'),fprintf(fid, '    Temps 1 volta: %.2f s\n', r.temps_1_volta); end
            if isfield(r, 'consum_kWh'),   fprintf(fid, '    Consum total: %.3f kWh / %.2f Ah\n', r.consum_kWh, r.consum_Ah); end
            if isfield(r, 'T_max_mot'),    fprintf(fid, '    Temp. max motor: %.1f °C\n', r.T_max_mot); end
            if isfield(r, 'SOC_fin'),      fprintf(fid, '    SOC final: %.1f%%\n', r.SOC_fin); end
            fprintf(fid, '\n');
        end
        
        fclose(fid);
        uialert(fig, sprintf('✅ Paràmetres guardats a:\n%s', params_path), 'Paràmetres exportats');
    end
    
    function write_struct_fields(fid, s)
        if isempty(fieldnames(s))
            fprintf(fid, '  (buit)\n');
            return;
        end
        fn = fieldnames(s);
        for i = 1:length(fn)
            val = s.(fn{i});
            if isnumeric(val) && isscalar(val)
                fprintf(fid, '  %-30s = %g\n', fn{i}, val);
            elseif isnumeric(val) && numel(val) <= 6
                fprintf(fid, '  %-30s = [%s]\n', fn{i}, num2str(val(:)'));
            elseif ischar(val) || isstring(val)
                fprintf(fid, '  %-30s = %s\n', fn{i}, char(val));
            elseif islogical(val) && isscalar(val)
                fprintf(fid, '  %-30s = %s\n', fn{i}, mat2str(val));
            else
                fprintf(fid, '  %-30s = [%dx%d %s]\n', fn{i}, size(val,1), size(val,2), class(val));
            end
        end
    end

    % =========================================================================
    % GENERAR POWERPOINT
    % =========================================================================
    function generate_pptx()
        if ~ensure_output_folder(), return; end
        % PNGs guardats a subcarpeta Graphs/
        png_dir = fullfile(export_folder, 'Graphs');
        
        % Ruta de l'script Python -> GENERADOR POWERPOINT (2 nivells amunt)
        script_doe_dir = fileparts(mfilename('fullpath'));
        py_script = fullfile(script_doe_dir, '..', '..', 'GENERADOR POWERPOINT', 'generate_doe5_pptx.py');
        py_script = char(java.io.File(py_script).getCanonicalPath());
        
        if ~exist(py_script, 'file')
            uialert(fig, sprintf('No es troba l''script Python:\n%s\n\nCopia generate_doe5_pptx.py al directori correcte.', py_script), 'Error');
            return;
        end
        
        % Nom del fitxer de sortida
        [~, fold_nm] = fileparts(png_dir);
        out_pptx = fullfile(png_dir, sprintf('DOE5_%s.pptx', fold_nm));
        
        % Python executable
        py_exe = 'python';
        pe = pyenv;
        if ~isempty(pe.Executable), py_exe = char(pe.Executable); end
        
        cmd = sprintf('"%s" "%s" "%s" "%s"', py_exe, py_script, png_dir, out_pptx);
        
        d_pptx = uiprogressdlg(fig, 'Title', 'Generant PowerPoint...', ...
            'Message', 'Executant script Python...', 'Indeterminate', 'on');
        drawnow;
        
        [status, result] = system(cmd);
        close(d_pptx);
        
        if status == 0
            uialert(fig, sprintf('✅ PowerPoint generat correctament:\n%s', out_pptx), 'Èxit');
            % Obrir directament
            try, winopen(out_pptx); catch, end
        else
            uialert(fig, sprintf('Error generant PPTX (codi %d):\n%s', status, result), 'Error Python');
            fprintf('ERROR generate_pptx:\n%s\n', result);
        end
    end

    % =========================================================================
    % EXPORTAR TOT D'UN COP
    % =========================================================================
    function export_everything()
        if ~ensure_output_folder(), return; end
        
        d_all = uiprogressdlg(fig, 'Title', 'Exportant tot...', ...
            'Message', 'Iniciant...', 'Value', 0, 'Cancelable', 'off');
        drawnow;
        
        try
            d_all.Message = '(1/5) Guardant paràmetres base...'; d_all.Value = 0.05; drawnow;
            save_params_file();
            
            d_all.Message = '(2/5) Exportant gràfics PNG...'; d_all.Value = 0.10; drawnow;
            export_all_plots();
            
            d_all.Message = '(3/5) Exportant Excel...'; d_all.Value = 0.85; drawnow;
            export_to_excel();
            
            d_all.Message = '(4/5) Guardant sessió .MAT...'; d_all.Value = 0.90; drawnow;
            save_session_data(res_all, f_vil, f_mot, derat_c, derat_d);
            
            d_all.Message = '(5/5) Generant PowerPoint...'; d_all.Value = 0.92; drawnow;
            generate_pptx();
            
            close(d_all);
            uialert(fig, sprintf(['Tot exportat correctament a:\n%s\n\n' ...
                '  • Graphs/  \u2192 tots els PNGs\n' ...
                '  • Parametres_Base_Simulacio.txt\n' ...
                '  • Resum_Comparatiu_DOE.xlsx\n' ...
                '  • Simulacio_DOE5.mat\n' ...
                '  • DOE5_*.pptx'], export_folder), ...
                'Exportació completada!', 'Icon', 'success');
        catch ME
            try, close(d_all); catch, end
            uialert(fig, sprintf('Error durant l''exportació:\n%s', ME.message), 'Error');
            fprintf('ERROR export_everything: %s\n', ME.message);
        end
    end

    function p_c(ax,t,y,c,s,nm), plot(ax,t(:),y(:),'Color',c,'LineStyle',s,'LineWidth',1.2,'DisplayName',nm); end
    
    function out = ifElse(cond, true_val, false_val)
        if cond, out = true_val; else, out = false_val; end
    end
    
    filter_changed();
    
end
