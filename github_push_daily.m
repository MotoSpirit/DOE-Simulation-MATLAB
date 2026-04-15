function github_push_daily()
    % GITHUB_PUSH_DAILY Sincronitza tots els canvis del projecte a GitHub
    % de manera totalment automatica amb un sol clic.

    fprintf('========================================================\n');
    fprintf('  INICIANT SINCRONITZACIÓ AUTOMÀTICA AMB GITHUB\n');
    fprintf('========================================================\n\n');

    % Hem d'assegurar-nos que Git est\u00e0 al PATH
    % (A Windows pot ser que des de MATLAB no agafi la ruta de sistema directament depenent de quan es va obrir)
    % Per aixo construim un command system que llegeix les variables entorn primer
    path_setup = 'set PATH=%PATH%;C:\Program Files\Git\cmd;C:\Program Files\GitHub CLI & ';

    % 1. Detectar si hi ha canvis per afegir
    fprintf('[1/4] Detectant fitxers modificats...\n');
    cmd_add = [path_setup 'git add .'];
    [status_add, result_add] = system(cmd_add);
    if status_add ~= 0
        disp(result_add);
        error('Error executant "git add". Assegurat que Git esta ben installat.');
    end

    % Veure què s'ha canviat exactament per fer el missatge descriptiu
    cmd_diff = [path_setup 'git diff --cached --name-status'];
    [~, result_diff] = system(cmd_diff);
    
    if isempty(strtrim(result_diff))
        fprintf('\n[OK] SUCCESS: No hi ha cap canvi nou per pujar. El repositori ja esta actualitzat!\n\n');
        return;
    end

    % Netejar llista per al missatge
    files_changed = splitlines(strtrim(result_diff));
    num_files = length(files_changed);
    
    fprintf('S''han detectat %d fitxers modificats/nous:\n', num_files);
    for i = 1:min(num_files, 10)
        fprintf('  - %s\n', files_changed{i});
    end
    if num_files > 10
        fprintf('  - ... i %d mes.\n', num_files - 10);
    end

    % 2. Crear un Commit interactiu i autogenerat
    fprintf('\n[2/4] Guardant historial (Commit)...\n');
    
    % Veure estadístiques de línies canviades per ajudar l'usuari
    cmd_stat = [path_setup 'git diff --stat --cached'];
    [~, result_stat] = system(cmd_stat);
    if isempty(strtrim(result_stat))
        result_stat = 'No hi ha detalls estadístics de línies (poden ser fitxers binaris o nous).';
    end

    % Finestra emergent per demanar el detall a l'usuari
    % Preparar un resum visual dels fitxers modificats per a la finestra
    info_fitxers = sprintf('RESUM DE CANVIS:\n%s\n----------------------------------------------------------\nFitxers detectats (%d):', result_stat, num_files);
    for i = 1:min(num_files, 7)
        info_fitxers = [info_fitxers char(10) '  - ' files_changed{i}];
    end
    if num_files > 7
        info_fitxers = [info_fitxers char(10) '  ... i ' num2str(num_files - 7) ' més.'];
    end
    
    prompt = {sprintf('%s\n\nESCRIU AQUÍ ABAIX els CANVIS FETS en aquesta versió i el PERQUÈ:', info_fitxers)};
    dlgtitle = 'Diari de Canvis per GitHub';
    dims = [12 90]; % Ampliem una mica la finestra per veure les estadístiques
    definput = {''};
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    
    % Si l'usuari col·lapsa la finestra
    if isempty(answer)
        fprintf('\n[AVÍS] Operació col·lapsada per l''usuari. No s''ha pujat res.\n');
        return;
    end
    
    % Converteix la matriu 2D de caràcters (si hi ha múltiples línies) a un sol text amb intro
    user_justification = strjoin(cellstr(answer{1}), char(10));
    user_justification = strtrim(user_justification);
    
    if isempty(user_justification)
        user_justification = 'Canvis genèrics sense descripció detallada.';
    end
    
    % Per evitar qualsevol error de sintaxi estrany a Windows amb caràcters, cometes o salts de línia, 
    % crearem un fitxer temporal de text amb el missatge.
    msg_file = fullfile(pwd, 'temp_commit_msg.txt');
    fid = fopen(msg_file, 'w', 'n', 'UTF-8');
    fprintf(fid, 'Actualització versio: %s\n\n', datestr(now, 'dd-mm-yyyy HH:MM'));
    fprintf(fid, 'DETALL DELS CANVIS I MOTIUS:\n%s\n\n', user_justification);
    fprintf(fid, 'RESUM AUTOMÀTIC DEL SISTEMA:\nS''han detectat %d fitxers modificats/nous.\n', num_files);
    fclose(fid);
    
    % Fem el commit llegint el fitxer
    cmd_commit = sprintf('%sgit commit -F "%s"', path_setup, msg_file);
    [status_commit, result_commit] = system(cmd_commit);
    
    % Esborrar fitxer temporal netament
    if exist(msg_file, 'file')
        delete(msg_file);
    end
    
    if status_commit ~= 0 && ~contains(result_commit, 'nothing to commit')
        disp(result_commit);
        error('Error fent commit.');
    end

    % 3. Empentar (Push) a GitHub
    fprintf('[3/4] Pujant al núvol (GitHub). Això pot trigar uns segons...\n');
    
    % Verify auth status loosely to warn if they aren't logged in
    cmd_auth = [path_setup 'gh auth status'];
    [auth_stat, ~] = system(cmd_auth);
    if auth_stat ~= 0
        warning('ATENCIÓ: Sembla que no estas connectat a GitHub. Ves al terminal i escriu: "gh auth login". Si ja ho vas fer, ignora aquest missatge o asigura''t que estigui logejat.');
    end

    cmd_push = [path_setup 'git push -u origin main'];
    [status_push, result_push] = system(cmd_push);
    
    if status_push ~= 0
        disp(result_push);
        error('Error empentant dades a GitHub. Comprova la connexio i que la teva compta tingui permisos.');
    end

    % 4. Finalitzat!
    fprintf('\n========================================================\n');
    fprintf(' * TOT FET! Canvis pujats correctament a GitHub. *\n');
    fprintf('Motiu registrat: %s\n', user_justification);
    fprintf('========================================================\n');

    % Mostrar un missatge tipus Popup de Windows (opcional)
    try
        msgbox(sprintf('La pujada a GitHub s''ha completat!\n\nHistorial desat:\n%s', user_justification), 'GitHub completat', 'help');
    catch
    end
end
