function cfg = copy_raw_to_local(cfg, localRoot)
% COPY_RAW_TO_LOCAL  Copy raw deployment files from server to local disk.
%
%   cfg = copy_raw_to_local(cfg)
%   cfg = copy_raw_to_local(cfg, localRoot)
%
%   Copies all raw files for every deployment in the config from the lab
%   server (cfg.rawDataRoot) to a local directory for fast processing.
%   Returns an updated cfg with cfg.localDataRoot set, so subsequent calls
%   to process_deployment read from the fast local copy.
%
%   Files already present locally with matching size are skipped (safe to
%   re-run).
%
%   INPUTS
%     cfg        - deployment config struct (from e.g. TP24_config)
%     localRoot  - (optional) root directory for local cache.
%                  Default: Altimeter_Pipeline/raw_cache
%
%   OUTPUT
%     cfg        - same config with cfg.localDataRoot set
%
%   USAGE
%     cfg = TP24_config();
%     cfg = copy_raw_to_local(cfg);   % copy files, update cfg
%     % then run ALT_L1_driver or process_deployment

    if nargin < 2
        localRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'raw_cache');
    end

    cfg.localDataRoot = fullfile(localRoot, cfg.name);

    fprintf('\n=== Copying raw files for %s ===\n', cfg.name);
    fprintf('  Source : %s\n', cfg.rawDataRoot);
    fprintf('  Dest   : %s\n', cfg.localDataRoot);

    totalBytes = 0;
    totalCopied = 0;
    totalSkipped = 0;
    tStart = tic;

    for k = 1:numel(cfg.deployments)
        dep = cfg.deployments(k);
        allFiles = [dep.altimeterFiles(:); dep.echosounderFiles(:)];

        if isempty(allFiles)
            continue
        end

        fprintf('\n  [%d/%d] %s — %d files\n', k, numel(cfg.deployments), ...
            dep.label, numel(allFiles));

        for f = 1:numel(allFiles)
            relPath = allFiles{f};
            srcFile  = fullfile(cfg.rawDataRoot, relPath);
            destFile = fullfile(cfg.localDataRoot, relPath);

            if ~isfile(srcFile)
                warning('copy_raw_to_local:srcNotFound', ...
                    'Source file not found, skipping:\n  %s', srcFile);
                continue
            end

            % Ensure destination directory exists
            destDir = fileparts(destFile);
            if ~exist(destDir, 'dir'), mkdir(destDir); end

            srcInfo = dir(srcFile);
            fileMB  = srcInfo.bytes / 1e6;

            if isfile(destFile)
                destInfo = dir(destFile);
                if destInfo.bytes == srcInfo.bytes
                    fprintf('    skip  %-50s (%.0f MB, already present)\n', ...
                        relPath, fileMB);
                    totalSkipped = totalSkipped + 1;
                    continue
                end
            end

            fprintf('    copy  %-50s (%.0f MB) ...', relPath, fileMB);
            t1 = tic;
            copyfile(srcFile, destFile);
            fprintf(' %.1fs\n', toc(t1));

            totalBytes  = totalBytes  + srcInfo.bytes;
            totalCopied = totalCopied + 1;
        end
    end

    fprintf('\nDone. Copied %d files (%.1f GB), skipped %d, in %.1f min.\n', ...
        totalCopied, totalBytes/1e9, totalSkipped, toc(tStart)/60);
    fprintf('cfg.localDataRoot set to:\n  %s\n\n', cfg.localDataRoot);
end
