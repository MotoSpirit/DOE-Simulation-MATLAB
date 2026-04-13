function cfg = battery_config(c_type)
% BATTERY_CONFIG - Propietats i Termodinàmica de la Bateria (Font Única de Veritat)
% Retorna totes les propietats electroquímiques i taules (LUTs) de la bateria.
%
% IMPORTANT: Totes les modificacions de les cel·les o LUTs tèrmiques
%            s'han de fer ÚNICAMENT aquí.
%
% Inputs:
%   c_type  - Tipus de cel·la: 1=SA88, 2=SA124, 3=TenPower 50GX
%
% Outputs:
%   cfg - Struct amb tots els paràmetres i LUTs

    %% 1. PROPIETATS ELÈCTRIQUES PER TIPUS DE CEL·LA
    switch c_type
        case 1  % SA88
            cfg.cell_name = 'SA88';
            cfg.Voc_LUT   = [2.8, 3.4,  3.5,  3.6,  3.65, 3.7,  3.75, 3.8,  3.9,  4.0,  4.2];
            cfg.Cap_Ah    = 10.5;
            cfg.R_mOhm    = 4;
            cfg.Weight_g  = 96.5;
            cfg.Max_I     = 105;
            cfg.Max_C     = 20;

        case 2  % SA124
            cfg.cell_name = 'SA124';
            cfg.Voc_LUT   = [2.5, 3.3,  3.45, 3.55, 3.6,  3.65, 3.7,  3.85, 3.95, 4.05, 4.2];
            cfg.Cap_Ah    = 5.0;
            cfg.R_mOhm    = 9;
            cfg.Weight_g  = 69.0;
            cfg.Max_I     = 50;
            cfg.Max_C     = 10;

        case 3  % TenPower 50GX
            cfg.cell_name = 'TenPower 50GX';
            cfg.Voc_LUT   = [2.5, 3.15, 3.35, 3.45, 3.55, 3.65, 3.75, 3.85, 3.95, 4.05, 4.2];
            cfg.Cap_Ah    = 5.0;
            cfg.R_mOhm    = 8;
            cfg.Weight_g  = 69.0;
            cfg.Max_I     = 60;
            cfg.Max_C     = 15;

        otherwise
            error('battery_config: Tipus de cel·la invàlid (%d). Valors acceptats: 1, 2, 3.', c_type);
    end

    %% 2. TAULES TERMODINÀMIQUES I DE RESISTÈNCIA (LUTs) Comuns
    % Corba termoelèctrica (entropia reversible de la reacció electroquímica)
    cfg.SOC_LUT    = [0,    0.1,  0.2,   0.3,  0.4, 0.5, 0.6, 0.7,  0.8,   0.9,  1.0];
    cfg.dU_dT_LUT  = [-0.4, -0.2, -0.05, 0.05, 0.1, 0.1, 0.1, 0.05, -0.05, -0.2, -0.4] * 1e-3;

    % Efecte de la temperatura sobre la resistència interna
    cfg.Temp_LUT   = [0,   10,  20,  25,  30,  40,   50,   60,   70,   80,   90];
    cfg.R_Mult_T   = [1.8, 1.4, 1.1, 1.0, 0.9, 0.75, 0.70, 0.72, 0.75, 0.80, 0.90];

    % Efecte del estat de càrrega sobre la resistència interna
    cfg.SOC_R_LUT  = [0.00, 0.05, 0.10, 0.15, 0.20, 0.30, 0.50, 0.80, 1.00];
    cfg.R_Mult_SOC = [3.00, 2.00, 1.50, 1.20, 1.05, 1.00, 1.00, 1.00, 1.00];

end
