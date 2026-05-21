% VERIFY_ISSUE001  Standalone verification sweep for the ISSUE-001 timezone fix.
% Reads the (already reprocessed) L1 instrument temperatures and the co-located
% PUV temperatures, cross-correlates hourly, and writes a PASS/FAIL report.
% Every reliable (r>0.6) row should now read lag 0 (UTC).
clear; clc;
codeDir = fileparts(mfilename('fullpath'));
addpath(codeDir);
outRoot = fullfile(codeDir,'..','outputs','all');
reportPath = fullfile(codeDir,'..','outputs','ISSUE001_verification_report.txt');

sites(1)=struct('tag','SouthSIOPier','puv',{{'SIO24A','SIO24B','SIO24C','SIO25A','SIO25B','SIO25C','SIO25D','SIO25E'}});
sites(2)=struct('tag','TorreyPines', 'puv',{{'TBR23','TOR23W','TOR24S','TOR24W','TOR25S'}});
sites(3)=struct('tag','SolanaBeach', 'puv',{{'SOL23','SOL24','SOL25A','SOL25B'}});
puvL2='/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';

fid = fopen(reportPath,'w');
fprintf(fid,'ISSUE-001 verification report  (generated %s)\n', datestr(now));
fprintf(fid,'Expect every reliable (r>0.6) row to read lag 0 (UTC).\n\n');
fprintf(fid,'%-34s %-5s %5s %5s  %s\n','deployment','instr','lag','r','result');
nPass=0; nFailV=0; nWeak=0;
for s=1:numel(sites)
    recs={};
    for j=1:numel(sites(s).puv)
        dd=dir(fullfile(puvL2,sites(s).puv{j},'*_L2.mat'));
        for k=1:numel(dd)
            try P=load(fullfile(dd(k).folder,dd(k).name)); fn=fieldnames(P); L2=P.(fn{1});
                if ~isfield(L2,'time')||~isfield(L2,'Tmean'); continue; end
                tp=L2.time; tp.TimeZone=''; Tp=L2.Tmean(:); gp=isfinite(Tp); if nnz(gp)<50; continue; end
                [u,~,ii]=unique(dateshift(tp(gp),'start','hour')); rr.t=u; rr.T=accumarray(ii,Tp(gp),[],@mean); recs{end+1}=rr; %#ok
            catch; end
        end
    end
    L1=dir(fullfile(outRoot,sites(s).tag,'*_L1.mat'));
    for f=1:numel(L1)
        S=load(fullfile(L1(f).folder,L1(f).name));
        cand={};
        if isfield(S,'TTa')&&~isempty(S.TTa)&&any(strcmp(S.TTa.Properties.VariableNames,'Temperature_C'))
            tt=S.TTa.Time; tt.TimeZone=''; T=S.TTa.Temperature_C; g=isfinite(T);
            if nnz(g)>50; cand{end+1}=struct('instr','alt','t',tt(g),'T',T(g)); end %#ok
        end
        if isfield(S,'Eall')&&~isempty(S.Eall)&&isfield(S.Eall,'temperature_C')
            te=S.Eall.time; te.TimeZone=''; T=S.Eall.temperature_C(:); g=isfinite(T);
            if nnz(g)>50; cand{end+1}=struct('instr','echo','t',te(g),'T',T(g)); end %#ok
        end
        for cc=1:numel(cand)
            [lag,r]=xc(cand{cc}.t,cand{cc}.T,recs);
            if isnan(lag); res='no-PUV'; nWeak=nWeak+1;
            elseif r<0.6; res=sprintf('weak r=%.2f',r); nWeak=nWeak+1;
            elseif lag==0; res='PASS (UTC)'; nPass=nPass+1;
            else; res=sprintf('*** FAIL lag=%+d ***',lag); nFailV=nFailV+1; end
            fprintf(fid,'%-34s %-5s %+5d %5.2f  %s\n', L1(f).name, cand{cc}.instr, lag, max(r,0), res);
        end
    end
end
try
    E=load(fullfile(codeDir,'..','outputs','L4','L4_SOL_7m.mat')); u=unique(string(E.L4.deploymentID));
    fprintf(fid,'\nL4_SOL deployments: %s\n', strjoin(cellstr(u),' | '));
    if any(contains(u,'NN24')); fprintf(fid,'*** FAIL: NN24 still present ***\n'); nFailV=nFailV+1; end
    if any(contains(u,'_0m_')); fprintf(fid,'*** WARN: 0m label still present (orphan not cleaned) ***\n'); end
catch ME; fprintf(fid,'L4_SOL check failed: %s\n', ME.message); end
fprintf(fid,'\nSUMMARY: %d PASS, %d FAIL, %d weak/no-PUV.\n', nPass, nFailV, nWeak);
if nFailV==0; fprintf(fid,'OVERALL: PASS (no UTC failures)\n'); else; fprintf(fid,'OVERALL: FAIL (%d failures)\n', nFailV); end
fclose(fid);
fprintf('\n=== DONE. Report: %s ===\n', reportPath);
fprintf('SUMMARY: %d PASS, %d FAIL, %d weak/no-PUV\n', nPass, nFailV, nWeak);

function [lag,best]=xc(t,T,recs)
    [uA,~,iA]=unique(dateshift(t,'start','hour')); mA=accumarray(iA,T,[],@mean);
    best=-inf; lag=NaN;
    for p=1:numel(recs)
        r=recs{p}; t0=max(min(uA),min(r.t)); t1=min(max(uA),max(r.t)); if t1-t0<hours(72); continue; end
        hg=(t0:hours(1):t1)'; A=interp1(uA,mA,hg,'linear',NaN); B=interp1(r.t,r.T,hg,'linear',NaN);
        v=isfinite(A)&isfinite(B); if nnz(v)<72; continue; end
        A=A-mean(A(v)); B=B-mean(B(v)); A(~v)=0; B(~v)=0;
        for L=-14:14
            B2=circshift(B,-L); if L>0,B2(end-L+1:end)=0; elseif L<0,B2(1:-L)=0; end
            m=(A~=0)&(B2~=0); if nnz(m)>40, rr=corr(A(m),B2(m)); if rr>best,best=rr;lag=L;end;end
        end
    end
end
