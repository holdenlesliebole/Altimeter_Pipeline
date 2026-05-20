% TZ VERIFICATION SWEEP v2 — select the PUV giving the HIGHEST correlation
% per deployment (robust to mis-pairing), report lag + r + implied frame.
allRoot = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/all';
puvL2   = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';

sites(1).name='SouthSIOPier'; sites(1).puv={'SIO24A','SIO24B','SIO24C','SIO25A','SIO25B','SIO25C','SIO25D','SIO25E'};
sites(2).name='TorreyPines';  sites(2).puv={'TBR23','TOR23W','TOR24S','TOR24W','TOR25S'};
sites(3).name='SolanaBeach';  sites(3).puv={'SOL23','SOL24','SOL25A','SOL25B'};

puvCache = struct();
for s=1:numel(sites)
  key=sites(s).name; puvCache.(key)={};
  for j=1:numel(sites(s).puv)
    dd=dir(fullfile(puvL2,sites(s).puv{j},'*_L2.mat'));
    for k=1:numel(dd)
      try
        P=load(fullfile(dd(k).folder,dd(k).name)); fn=fieldnames(P); L2=P.(fn{1});
        if ~isfield(L2,'time')||~isfield(L2,'Tmean'); continue; end
        tp=L2.time; tp.TimeZone=''; Tp=L2.Tmean(:); gp=isfinite(Tp);
        if nnz(gp)<50; continue; end
        rec.name=string(sites(s).puv{j})+"/"+string(dd(k).name);
        [u,~,ii]=unique(dateshift(tp(gp),'start','hour')); rec.t=u; rec.T=accumarray(ii,Tp(gp),[],@mean);
        puvCache.(key){end+1}=rec;
      catch; end
    end
  end
end

xcorrLag=@(A,B) deal(0,0); %#ok placeholder
fprintf('\n%-30s %-5s %4s  %-22s %6s %7s %6s  %s\n','deployment','instr','dep','best-r PUV','n_hrs','lag','r','implied frame');
fprintf('%s\n',repmat('-',1,110));
results={};
for s=1:numel(sites)
  key=sites(s).name; L1f=dir(fullfile(allRoot,key,'*_L1.mat'));
  for f=1:numel(L1f)
    S=load(fullfile(L1f(f).folder,L1f(f).name));
    depth=NaN; if isfield(S,'dep')&&isfield(S.dep,'Depth_m'); depth=S.dep.Depth_m; end
    cand={};
    if isfield(S,'TTa')&&~isempty(S.TTa)&&any(strcmp(S.TTa.Properties.VariableNames,'Temperature_C'))
      ta=S.TTa.Time; ta.TimeZone=''; Ta=S.TTa.Temperature_C; g=isfinite(Ta);
      if nnz(g)>50; cand{end+1}=struct('instr','alt','t',ta(g),'T',Ta(g)); end
    end
    if isfield(S,'Eall')&&~isempty(S.Eall)&&isfield(S.Eall,'temperature_C')
      te=S.Eall.time; te.TimeZone=''; Te=S.Eall.temperature_C(:); g=isfinite(Te);
      if nnz(g)>50; cand{end+1}=struct('instr','echo','t',te(g),'T',Te(g)); end
    end
    for c=1:numel(cand)
      [uA,~,iA]=unique(dateshift(cand{c}.t,'start','hour')); mA=accumarray(iA,cand{c}.T,[],@mean);
      bestR=-inf; bestLag=NaN; bestN=0; bestPUV='(none)';
      for p=1:numel(puvCache.(key))
        r=puvCache.(key){p};
        t0=max(min(uA),min(r.t)); t1=min(max(uA),max(r.t));
        if t1-t0<hours(48); continue; end
        hg=(t0:hours(1):t1)';
        Aa=interp1(uA,mA,hg,'linear',NaN); Bb=interp1(r.t,r.T,hg,'linear',NaN);
        v=isfinite(Aa)&isfinite(Bb); if nnz(v)<48; continue; end
        Aa=Aa-mean(Aa(v)); Bb=Bb-mean(Bb(v)); Aa(~v)=0; Bb(~v)=0;
        for L=-14:14
          B2=circshift(Bb,-L); if L>0,B2(end-L+1:end)=0; elseif L<0,B2(1:-L)=0; end
          m=(Aa~=0)&(B2~=0);
          if nnz(m)>40, rr=corr(Aa(m),B2(m)); if rr>bestR, bestR=rr;bestLag=L;bestN=nnz(m);bestPUV=char(r.name); end; end
        end
      end
      off=-bestLag;
      if isnan(bestLag); fr='(no match)';
      elseif off==-8, fr='local PST (UTC-8)'; elseif off==-7, fr='local PDT (UTC-7)';
      elseif off==0, fr='UTC'; elseif off>=6&&off<=9, fr=sprintf('UTC+%d (over-offset)',off);
      else, fr=sprintf('UTC%+d',off); end
      flag=''; if bestR<0.6, flag=' [LOW r - unreliable]'; end
      fprintf('%-30s %-5s %4g  %-22s %6d %+7d %6.3f  %s%s\n', L1f(f).name,cand{c}.instr,depth,bestPUV,bestN,bestLag,bestR,fr,flag);
      results(end+1,:)={L1f(f).name,cand{c}.instr,depth,bestPUV,bestN,bestLag,bestR,fr}; %#ok<SAGROW>
    end
  end
end
save('/tmp/tz_sweep_results.mat','results');
fprintf('\nSaved /tmp/tz_sweep_results.mat\n');
