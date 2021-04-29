function[summary_sp, summary_su, summary_au,summary_wi]= stats_all_calc(table_sp, table_su, table_au,table_wi)

varnames ={'NS____________________','R_2____________________','RMSE____________________','RMSE_sd____________________','bias____________________'};
rownames ={'era5', 'm1','m2','m3','m4','m5',...
                   'm6','m7','m8','m9','m10',...
                   'm11','m12','m13','m14','m15',...
                   'm16','m17','m18','m19','m20',...
                   'm21','m22','m23','m24','m25'};
S_ = table(NaN(size(rownames,2),1),NaN(size(rownames,2),1),NaN(size(rownames,2),1),NaN(size(rownames,2),1),NaN(size(rownames,2),1),'RowNames',rownames, 'VariableNames',varnames);

[summary_sp.S_obs, summary_sp.S_era]=all_stats(table_sp, S_);
[summary_su.S_obs, summary_su.S_era]=all_stats(table_su, S_);
[summary_au.S_obs, summary_au.S_era]=all_stats(table_au, S_);
[summary_wi.S_obs, summary_wi.S_era]=all_stats(table_wi, S_);

    function[S_o, S_e]= all_stats(table__, S_)
        S0 = S_;
        for j = 1:2
           S_ = S0;
           T_measured = table2array(table__(:,j));
           day_measured = table__.date;
           DNS_obs(:,1)=datenum(day_measured);  DNS_obs(:,2)=T_measured;
           DNS_obs(isnan(DNS_obs(:,2)),:)=[];
           if isempty(DNS_obs)
                 S_(1:26,1)=table(NaN);
                 S_(1:26,2)=table(NaN);
                 S_(1:26,3)=table(NaN);
                 S_(1:26,4)=table(NaN);
                 S_(1:26,5)=table(NaN);       
           else    
               for i = 1:26
                   if j ==2 && i ==1
                   else 

                    Temp_mod = table2array(table__(:,i+1));
                    Date = table__.date;
                    [T_date,loc_sim, loc_obs] = intersect(Date, day_measured);

                    DNS_mod(:,1)=datenum(Date); DNS_mod(:,2)=Temp_mod;

                    DNS_mod(isnan(DNS_mod(:,2)),:)=[];
                    if isempty(DNS_mod)
                         S_(i,1)=table(NaN);
                         S_(i,2)=table(NaN);
                         S_(i,3)=table(NaN);
                         S_(i,4)=table(NaN);
                         S_(i,5)=table(NaN);                        
                    else
                        RR = RMSE(Temp_mod(loc_sim, 1), T_measured(loc_obs, 1));
                        [NSE drd ede]=nashsutcliffe(DNS_obs,DNS_mod);
                        R = corrcoef(ede(:,2),ede(:,3)) ;
                        if size(R)~=[2 2]
                            R_squared=NaN;
                        else
                            R_squared=R(2,1).*R(2,1);
                        end
                        R_sd = RR./ std(DNS_obs(:,2));
                        bias = nanmean(Temp_mod(loc_sim, 1)- T_measured(loc_obs, 1));
                         S_(i,1)=table(NSE);
                         S_(i,2)=table(R_squared);
                         S_(i,3)=table(RR);
                         S_(i,4)=table(R_sd);
                         S_(i,5)=table(bias);
                    end
                   end
                   clear RR R NSE drd ede R_squared DNS_mod Temp_mod Date

               end
           end
           if j == 1
                S_o=S_;
           elseif j ==2
                S_e=S_;
           end
           clear DNS_obs T_measured day_measured
        end
        
    end

function r = RMSE(y, yhat)
    r = sqrt(nanmean((y-yhat).^2));
end

end