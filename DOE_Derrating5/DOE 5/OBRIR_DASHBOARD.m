%% SCRIPT PER REVISAR RESULTATS DE SIMULACIONS GUARDADES
% Este script permet carregar un arxiu .mat de resultats i obrir el Dashboard interactiu.

clear; clc;

% Afegir carpetes al Path (per si de cas)
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

% Seleccionar l'arxiu de resultats
[file, path] = uigetfile('*.mat', 'Selecciona el fitxer de resultats del DOE');

if isequal(file,0)
    disp('Usuari ha cancel·lat la selecció.');
else
    full_path = fullfile(path, file);
    fprintf('Carregant dades de: %s...\n', file);
    
    % Carregar les dades
    data = load(full_path);
    
    % Verificar que conté els resultats (mínim necessari)
    if isfield(data, 'resultats')
        % Gestionar variables opcionals per compatibilitat amb fitxers antics
        res = data.resultats;
        
        if isfield(data, 'f_vil'), fv = data.f_vil; else, fv = @(rpm) 100 + 0*rpm; disp('Avís: Corba f_vil no trobada, usant valors per defecte.'); end
        if isfield(data, 'f_mot'), fm = data.f_mot; else, fm = @(rpm) 120 + 0*rpm; disp('Avís: Corba f_mot no trobada, usant valors per defecte.'); end
        if isfield(data, 'derat_c'), dc = data.derat_c; else, dc = struct('mot_T',0,'mot_k',1,'bat_T',0,'bat_k',1); end
        if isfield(data, 'derat_d'), dd = data.derat_d; else, dd = struct('mot_T',0,'mot_k',1,'bat_T',0,'bat_k',1); end
        
        % Obrir el Dashboard
        Dashboard_DOE_Integrated(res, fv, fm, dc, dd);
        fprintf('Dashboard obert correctament.\n');
    else
        error('L''arxiu seleccionat no conté la variable ''resultats''. No es pot obrir.');
    end
end
