function [AcAire, AcAigua, AcAire_ref, AcAigua_ref] = radiador_params()
% RADIADOR_PARAMS - Geometria del Radiador M3 MOTOSPIRIT (Font Única de Veritat)
% Calcula les àrees de contacte del radiador a partir de la geometria física de les aletes i tubs.
%
% IMPORTANT: Totes les modificacions de geometria (canvi de radiador, aletes, etc.)
%            s'han de fer ÚNICAMENT aquí. Els canvis es propaguen automàticament a:
%   - simulacio_moto_canut.m
%   - Validacio_Id_Iq.m
%   - Validacio_Comparativa_DOE5.m
%   - M3_CIRCUIT_vDEF_OGv4.m
%
% Outputs:
%   AcAire    - Àrea de contacte costat aire [m²]
%   AcAigua   - Àrea de contacte costat aigua [m²]
%   AcAire_ref   - Àrea de referència aire per calibratge ANSYS [m²]
%   AcAigua_ref  - Àrea de referència aigua per calibratge ANSYS [m²]

    % ── GEOMETRIA FÍSICA DEL RADIADOR (Mesures reals del component) ──────────
    % Costat aire (aletes)
    AmpladaSup       = (400-3) * 1e-3;  % [m] amplada nucli superior
    AmpladaInf       = 210e-3;          % [m] amplada nucli inferior
    pasAleta         = 2.5e-3;          % [m] pas entre aletes
    EspessorRadiador = 27e-3;           % [m] profunditat nucli
    nFilesSupAL      = 30;              % Nombre de files aletes superior
    nFilesInfAL      = 30;              % Nombre de files aletes inferior
    pAleta           = 23.359e-3;       % [m] perímetre mullat d'1 canal d'aleta

    % Costat aigua (tubs)
    nFilesSupTubs    = nFilesSupAL + 1;
    nFilesInfTubs    = nFilesInfAL + 1;
    pTub             = 45.446e-3;       % [m] perímetre mullat interior d'1 tub

    % ── CÀLCUL D'ÀREES ────────────────────────────────────────────────────────
    nSup    = AmpladaSup / pasAleta * nFilesSupAL;
    nInf    = AmpladaInf / pasAleta * nFilesInfAL;
    nAletes = nSup + nInf;
    AcAire  = pAleta * nAletes * EspessorRadiador;      % [m²] costat aire

    nTubsSup = AmpladaSup / pasAleta * nFilesSupTubs;
    nTubsInf = AmpladaInf / pasAleta * nFilesInfTubs;
    nTubs    = nTubsSup + nTubsInf;
    AcAigua  = pTub * nTubs * EspessorRadiador;         % [m²] costat aigua

    % ── REFERÈNCIES DE CALIBRATGE ANSYS ───────────────────────────────────────
    AcAire_ref  = 4.6167;  % [m²] àrea de referència aire (model ANSYS calibrat)
    AcAigua_ref = 9.2813;  % [m²] àrea de referència aigua (model ANSYS calibrat)
end
