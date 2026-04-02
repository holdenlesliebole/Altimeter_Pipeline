function registry = deployment_registry()
% DEPLOYMENT_REGISTRY  Returns a map of deployment names to config functions.
%
%   registry = deployment_registry()
%
%   Usage:
%       reg = deployment_registry();
%       cfg = reg('TP24')();    % returns Torrey Pines 2024 config
%       cfg = reg('SIO25')();   % returns SIO Pier 2025 config
%
%   Deployment naming convention:
%     SITE + year(s)
%     SIO24    = SIO Pier Mar-Dec 2024 (MOP511, 6m, altimeter + echosounder)
%     SIO25    = SIO Pier Jan-Dec 2025
%     SIO26    = SIO Pier Jan-Mar 2026
%     TP24     = Torrey Pines Feb-Nov 2024 (altimeters + echosounders, multi-depth)
%     TP25     = Torrey Pines Nov 2024-Jun 2025
%     SOL24    = Solana Beach Jan 2024 + Nov 2024-Feb 2025
%     SOL25    = Solana Beach Mar-Jun 2025
%     SOL26    = Solana Beach Dec 2025-Feb 2026

    registry = containers.Map();

    % --- SIO Pier (MOP511, 6m, monthly swaps) ---
    registry('SIO24') = @SIO24_config;    % Mar-Dec 2024
    registry('SIO25') = @SIO25_config;    % Jan-Dec 2025
    registry('SIO26') = @SIO26_config;    % Jan-Mar 2026

    % --- Torrey Pines (MOP586, multi-depth) ---
    registry('TP24')  = @TP24_config;     % Feb-Nov 2024
    registry('TP25')  = @TP25_config;     % Nov 2024-Jun 2025

    % --- Solana Beach (MOP654, 7m) ---
    registry('SOL24') = @SOL24_config;    % Jan 2024 + Nov 2024-Feb 2025
    registry('SOL25') = @SOL25_config;    % Mar-Jun 2025
    registry('SOL26') = @SOL26_config;    % Dec 2025-Feb 2026

end
