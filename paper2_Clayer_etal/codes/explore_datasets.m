files = dir('.');

id = [];
idx = [];

for i = 1:size(files,1)
    if files(i).name(end) == 'v'
    else
        id = [id ; i];
    end
end

files(id) = [];

[~,name,~]=fileparts(pwd);
if contains(name,'Vansj')
    del = ';';
else
    del = ',';
end

clear i
messages = {};

for i = 1:size(files,1)
    if files(i).name(end-2:end) == 'csv'
        vars{i} = readtable(files(i).name,'Delimiter',del);
        %vars{1,i}{:,2}= double(string(vars{1,i}{:,2})); 
        VN = vars{1,i}.Properties.VariableNames;
        for j = 2:size(VN,2)
            if isnumeric(vars{1,i}.(VN{j}))
            else
                vars{1,i}.(VN{j}) = str2double(vars{1,i}.(VN{j}));
            end
            if contains(files(i).name,'temp','IgnoreCase',true)
                vars{1,i}.(VN{j})(abs(vars{1,i}.(VN{j}))>60)=NaN;
            end
        end
        if size(VN,2)>=28
            avg =[nanmean(table2array(vars{1,i}(:,2))); nanmean(table2array(vars{1,i}(:,3))); nanmean(nanmean(table2array(vars{1,i}(:,4:28))),2)];
        else
            avg =nanmean(table2array(vars{1,i}(:,2:end)));
        end
        if any(avg-nanmean(avg) > 0.7*nanmean(avg))
            message = strcat('Mismatch in numbers in variable',{' '},files(i).name);
            disp(message)
            messages(i) = message;
            idx = [idx;i];
        end
        clear VN avg
    end 
end
%stats
for i = 1:size(files,1)
    vars{1,i}.Properties.VariableNames(1:3)={'date','obs','ERA5'};
    vars{1,i}.date = datetime(vars{1,i}.date);
    [table_sp_terc, table_su_terc, table_au_terc, table_wi_terc, table_su_, table_wi_, table_au_, table_sp_]=stat_terc_test(vars{1,i}, 1994, 2016);
    [summary_sp, summary_su, summary_au,summary_wi]= stats_all_calc(table_sp_, table_su_, table_au_,table_wi_);
    var_ = files(i).name(1:end-4);
    [diff_sp, S_sp]=write_summary(summary_sp,'spring',var_);
    [diff_su, S_su]=write_summary(summary_su,'summer',var_);
    [diff_au, S_au]=write_summary(summary_au,'autumn',var_);
    [diff_wi, S_wi]=write_summary(summary_wi,'winter',var_);
    Diff_all = [diff_sp;diff_su;diff_au;diff_wi];
    Diff_all.Properties.VariableNames = {'NS_ratio','R_2_diff','RMSE_diff','RMSE_sd_diff','bias_abs_diff'};
    Diff_all.Properties.RowNames = {'spring','summer','autumn','winter'};
    writetable(Diff_all,strcat('Diff_stats','_',var_,'.txt'),'Delimiter','\t','WriteRowNames',true);
    Season_ERA = array2table([table2array(S_wi(4,:));table2array(S_sp(4,:)); table2array(S_su(4,:)); table2array(S_au(4,:))]);
    Season_ERA.Properties.RowNames = {'winter','spring','summer','autumn'};
    Season_ERA.Properties.VariableNames = {'NS','R_2','RMSE','RMSE_sd','bias'};
    writetable(Season_ERA,strcat('Seasons_ERA5_stats','_',var_,'.txt'),'Delimiter','\t','WriteRowNames',true);
    Season_obs = array2table([table2array(S_wi(2,:));table2array(S_sp(2,:)); table2array(S_su(2,:)); table2array(S_au(2,:))]);
    Season_obs.Properties.RowNames = {'winter','spring','summer','autumn'};
    Season_obs.Properties.VariableNames = {'NS','R_2','RMSE','RMSE_sd','bias'};
    writetable(Season_obs,strcat('Seasons_obs_stats','_',var_,'.txt'),'Delimiter','\t','WriteRowNames',true);

end




% figure
ff = figure('units','normalized','outerposition',[0 0 1 1]); 
for i = 1:size(files,1)
    VN = vars{1,i}.Properties.VariableNames;
    
    subplot(size(files,1),1,i);
    if size(VN,2)>=28
        yy = 1;
        p = line(table2array(vars{1,i}(:,1)),table2array(vars{1,i}(:,4:28)),'Color',[0.4 0.7 0.2 0.2]); 
        hold on; 
        q = plot(table2array(vars{1,i}(:,1)),table2array(vars{1,i}(:,2)),'b.'); 
        hold on;
        r = plot(table2array(vars{1,i}(:,1)),table2array(vars{1,i}(:,3)),'r-');
    else
        yy = 0;
        p = line(table2array(vars{1,i}(:,1)),table2array(vars{1,i}(:,2:end)),'Color',[0.4 0.7 0.2 0.2]); 
    end
    title(files(i).name,'Interpreter','none');
    
    if any(idx == i)
        text(0.2,0.5,messages(i),'Units','normalized','Color','red','FontSize',14);
    end
    
end
if yy ==1
    legend([p(1) q(1) r(1)],'SEAS5','obs','ERA5');
end

filename = strcat('Overview_',name,'_data_paper2.png');
saveas(ff,filename,'png')
clear name filename

function [diff, S_0]= write_summary(struct,season, variable)

    S_(1:3,:) = struct.S_obs(1:3,:);
    S_(2,:) = table(nanmean(table2array(struct.S_obs(2:end,1))),nanmean(table2array(struct.S_obs(2:end,2))),...
        nanmean(table2array(struct.S_obs(2:end,3))),nanmean(table2array(struct.S_obs(2:end,4))),nanmean(table2array(struct.S_obs(2:end,5))));
    S_(3,:) = table(nanstd(table2array(struct.S_obs(2:end,1))),nanstd(table2array(struct.S_obs(2:end,2))),...
        nanstd(table2array(struct.S_obs(2:end,3))),nanstd(table2array(struct.S_obs(2:end,4))),nanstd(table2array(struct.S_obs(2:end,5))));
    S_(4,:) = table(nanmean(table2array(struct.S_era(2:end,1))),nanmean(table2array(struct.S_era(2:end,2))),...
        nanmean(table2array(struct.S_era(2:end,3))),nanmean(table2array(struct.S_era(2:end,4))),nanmean(table2array(struct.S_era(2:end,5))));
    S_(5,:) = table(nanstd(table2array(struct.S_era(2:end,1))),nanstd(table2array(struct.S_era(2:end,2))),...
        nanstd(table2array(struct.S_era(2:end,3))),nanstd(table2array(struct.S_era(2:end,4))),nanstd(table2array(struct.S_era(2:end,5))));
    S_.Properties.RowNames = {'ERA5_vs_Obs','SEAS5_avg_vs_Obs','SEAS5_std _vs_obs','SEAS5_avg_vs_ERA5','SEAS5_std_vs_ERA5'};
    S_.Properties.VariableNames = {'NS','R_2','RMSE','RMSE_sd','bias'};
    S_0 = S_;
    writetable(S_,strcat('Summary_All',season,'_',variable,'.txt'),'Delimiter','\t','WriteRowNames',true);
    diff = table(gt(S_.NS(2), S_.NS(4)),gt(S_.R_2(2),S_.R_2(4)),S_.RMSE(2) - S_.RMSE(4),S_.RMSE_sd(2) - S_.RMSE_sd(4),abs(S_.bias(2)) - abs(S_.bias(4)));

end
