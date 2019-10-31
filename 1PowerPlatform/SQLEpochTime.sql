declare @m smallint = 15;

select  datediff(s, '01/01/1970', dateadd(minute, -@m, getdate())) as Before,
        datediff(s, '01/01/1970', getdate()) as Now, 
        datediff(s, '01/01/1970', dateadd(minute, @m, getdate())) as After
