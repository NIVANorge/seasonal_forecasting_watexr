function [table_sp_terc, table_su_terc, table_au_terc, table_wi_terc, table_su_, table_wi_, table_au_, table_sp_]=stat_terc_test(tableN, y1, y2)

tableN(tableN.date<strcat('01.03.',num2str(y1)),:)=[];
tableN(tableN.date>=strcat('01.03.',num2str(y2+1)),:)=[];

tableN = table2timetable(tableN);

tableN.month = month(tableN.date);

table_wi = tableN(tableN.month <= 2 | tableN.month >=12,:);
table_wi.date = datetime(datenum(table_wi.date)-120,'ConvertFrom','datenum');
table_sp = tableN(tableN.month <= 5 & tableN.month >=3,:);
table_su = tableN(tableN.month <= 8 & tableN.month >=6,:);
table_au = tableN(tableN.month <= 11 & tableN.month >=9,:);

[table_sp_terc, table_sp_] = calc_terc(table_sp);
[table_su_terc, table_su_] = calc_terc(table_su);
[table_au_terc, table_au_] = calc_terc(table_au);
[table_wi_terc, table_wi_] = calc_terc(table_wi);


function [table_terc, table__] = calc_terc(table_)
    yrs_ = unique(table_.date.Year);

    for ii = 1:length(yrs_)
        %% removing seasons with months without data
        jj = yrs_(ii,1);
        temp = table_(table_.date.Year==jj,:);
        temp = retime(temp,'monthly','mean');
        month_avg = temp.obs;
            if any(isnan(month_avg))
                table_(table_.date.Year==jj,1)=table(NaN);
            end
        clear temp
    end
    
   for iii = 1:27
       %% detrending
       temp_ = table2array(table_(:,iii));
       dates_ = datenum(table_.date);
       avg_ = nanmean(temp_);
       res_ = temp_ - avg_;
       mdl = fitlm(dates_,res_);
       table_(:,iii) = table(table2array(table_(:,iii)) - (mdl.Coefficients.Estimate(1) + mdl.Coefficients.Estimate(2).*dates_ ));
       clear temp_ avg_ res_ mdl dates_
       
   end
   table_yr = retime(table_,'yearly','mean');
    for jj = 1:length(yrs_)
        yr = yrs_(jj);
        avg = nanmean(table_.ERA5(table_.date.Year == yr));
        table_yr.month(jj) = avg;
        clear year avg
    end
 
    table_ = table_yr;

    if any(table_.month-table_.ERA5~=0)
        disp('Error in seasonal averages calculations')
    end
    
    
    table__ = table_;
    terc_bds_ = quantile(table2array(table_),2);

    table_terc = table_;

    table_terc(~isnan(table_terc.ERA5),2:end)=table(0);
    table_terc(~isnan(table_terc.obs),1)=table(0);

    for k = 1:27
        table_terc(table2array(table_(:,k))< terc_bds_(1,k),k) = table(-1);
        table_terc(table2array(table_(:,k))> terc_bds_(2,k),k) = table(1);
    end

end
end