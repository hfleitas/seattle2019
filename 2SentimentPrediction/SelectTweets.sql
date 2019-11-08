use twitterdata
go
select  top 100 * 
from    dbo.tweets
where   screen_name = 'TechRepublic'
or      text like '%Microsoft%'
order by num_followers desc
