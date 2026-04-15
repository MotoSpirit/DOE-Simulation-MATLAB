%% GENERATE BASE PARAMETERS - MotoSpirit
% Aquest script serveix per definir i actualitzar els paràmetres base de la moto
% que s'utilitzen en tots els scripts de simulació i DOE.
clear; clc;

% 1. Paràmetres Base (Aerodinàmica i Física)
p_base = struct();
p_base.rho                 = 1.2;
p_base.Cd                  = 0.467;
p_base.Area_Frontal        = 0.45;
p_base.parell_fre_motor    = 3;
p_base.Coeficient_Friccio  = 1.2;
p_base.Coeficient_rodadura = 0.02;
p_base.Massa_moto_nua      = 92;
p_base.M_pilot             = 73;
p_base.Radi_roda           = 0.301;
p_base.dist_cgx            = 0.635;
p_base.dist_cgy            = 0.64;

% 2. Paràmetres Transmissió: CAIXA DE CANVIS
p_caixa = struct();
p_caixa.Rendiment_total    = 0.797;
p_caixa.Ratio_primaria      = 1.409091;
p_caixa.Ratio_secundaria   = 2.0625;
p_caixa.Ratio_primera      = 2.75;
p_caixa.Ratio_segona       = 1.75;
p_caixa.Ratio_tercera      = 1.3125;
p_caixa.Ratio_quarta       = 1.045455;
p_caixa.Ratio_cinquena     = 0.875;
p_caixa.massa_efectiva1    = 7.27;
p_caixa.massa_efectiva2    = 7.28;
p_caixa.massa_efectiva3    = 7.29;
p_caixa.massa_efectiva4    = 7.30;
p_caixa.massa_efectiva5    = 7.31;
p_caixa.extra_mass         = 8;

% 3. Paràmetres Transmissió: DIRECTA
p_dir = struct();
p_dir.Rendiment_total      = 0.95;
p_dir.Ratio_primaria        = 3.5;
p_dir.massa_efectiva       = 7.26;
p_dir.extra_mass           = 0;

% Guardar el fitxer .mat
file_path = fullfile(fileparts(mfilename('fullpath')), 'Parametres_Base_Moto.mat');
save(file_path, 'p_base', 'p_caixa', 'p_dir');

fprintf('Fitxer de paràmetres generat correctament a:\n%s\n', file_path);
