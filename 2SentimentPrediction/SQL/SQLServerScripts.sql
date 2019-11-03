-- blog: https://blogs.msdn.microsoft.com/sqlserverstorageengine/2017/11/01/sentiment-analysis-with-python-in-sql-server-machine-learning-services/
--  + --------------------- +
--  | 1. restore sample db. |
--  + --------------------- +
--The database used for this sample can be downloaded here: https://sqlchoice.blob.core.windows.net/sqlchoice/static/tpcxbb_1gb.bak
restore filelistonly from disk = 'c:\users\hfleitas\downloads\tpcxbb_1gb.bak'
go
restore database [tpcxbb_1gb] from disk = 'c:\users\hfleitas\downloads\tpcxbb_1gb.bak' with replace,
move 'tpcxbb_1gb' to 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\tpcxbb_1gb.mdf', 
move 'tpcxbb_1gb_log' to 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\tpcxbb_1gb.ldf'
go
waitfor delay '00:00:05'
go
alter database [tpcxbb_1gb] set compatibility_level = 150 --2019
GO
exec sp_configure 'external scripts enabled', 1
reconfigure with override
go

declare @sql nvarchar(max);
-- only need to grant connect permissions!
select @sql = N'if not exists (select 1 from syslogins where name ='''+ @@servername +'\SQLRUserGroup'') 
begin
	create login ['+ @@servername +'\SQLRUserGroup] from windows
end
--grant EXECUTE ANY EXTERNAL SCRIPT to ['+ @@servername +'\SQLRUserGroup];
--alter server role sysadmin add member ['+ @@servername +'\SQLRUserGroup];
--use FleitasArts;
--if not exists (select 1 from sysusers where name ='''+ @@servername +'\SQLRUserGroup'')
--begin
--	create user ['+ @@servername +'\SQLRUserGroup] from login ['+ @@servername +'\SQLRUserGroup];
--end
--alter role db_datawriter add member ['+ @@servername +'\SQLRUserGroup]' 
print @sql; exec sp_executesql @sql;
go
-- Restart SQL Service & LAUNCHPAD.
-- Run PS as admin: .\Install-MLModels.ps1 MSSQLSERVER
-- Install Latest SQL Server CU, Reboot.
-- Run CMD as admin: AddToSQL-PreTrainedModels.cmd. It downloads & installs the pre-trained models.

--  + ------------------------ +
--  | 2. use pre-trained model | 
--  + ------------------------ + 
-- Create stored procedure that uses a pre-trained model to determine sentiment of a given text
use [tpcxbb_1gb]
go
create or alter proc GetSentiment (@text nvarchar(max))
as 
declare @script nvarchar(max);

--The Python script we want to execute
set @script = N'
import pandas as p
from microsoftml import rx_featurize, get_sentiment

analyze_this = text

# Create the data
text_to_analyze = p.DataFrame(data=dict(Text=[analyze_this]))

# Get the sentiment scores
sentiment_scores = rx_featurize(data=text_to_analyze,ml_transforms=[get_sentiment(cols=dict(scores="Text"))])

# Lets translate the score to something more meaningful
sentiment_scores["Sentiment"] = sentiment_scores.scores.apply(lambda score: "Positive" if score > 0.6 else "Negative")
';
 
exec sp_execute_external_script @language = N'Python'
	,@script = @script
	,@output_data_1_name = N'sentiment_scores'
	,@params = N'@text nvarchar(max)'
	,@text = @text
with result sets (("Text" nvarchar(max), "Score" float, "Sentiment" nvarchar(30)));   
go

--  + -----------------+
--  | 3. Test the proc |
--  + -----------------+
-- The below examples test a negative and a positive review text
exec GetSentiment N'These are not a normal stress reliever. First of all, they got sticky, hairy and dirty on the first day I received them. Second, they arrived with tiny wrinkles in their bodies and they were cold. Third, their paint started coming off. Fourth when they finally warmed up they started to stick together. Last, I thought they would be foam but, they are a sticky rubber. If these were not rubber, this review would not be so bad.';
exec GetSentiment N'These are the cutest things ever!! Super fun to play with and the best part is that it lasts for a really long time. So far these have been thrown all over the place with so many of my friends asking to borrow them because they are so fun to play with. Super soft and squishy just the perfect toy for all ages.'
exec GetSentiment N'I really did not like the taste of it' 
exec GetSentiment N'It was surprisingly quite good!'
exec GetSentiment N'I will never ever ever go to that place again!!' 
exec GetSentiment N'Destiny is a gift. Some go their entire lives, living existence as a quiet desperation. Never learning the truth that what feels as though a burden pushing down upon our shoulders, is actually, a sense of purpose that lifts us to greater heights. Never forget that fear is but the precursor to valor, that to strive and triumph in the face of fear, is what it means to be a hero. Don''t think, Master Jim. Become!'
--0.5	Negative. Why...Not enough?
-- https://azure.microsoft.com/en-us/services/cognitive-services/text-analytics/ 
-- Language: English, Sentiment: 78%.
-- Key phrases: face of fear, existence, triumph, valor, sense of purpose, entire lives, quiet desperation, shoulders, greater heights, precursor, Destiny, gift, Master Jim, burden, truth, hero. 
go

--  + ------------------------------------ +
--  | 4. create schema to train own model. |
--  + ------------------------------------ +
use [tpcxbb_1gb]
go
drop table if exists models
go
create table models (
	 language		varchar(30) not null --default('Python')
	,model_name		varchar(30) not null
	,model			varbinary(max) 
	,create_time	datetime default(getdate())
	,created_by		nvarchar(500) default(suser_sname())
 primary key clustered (language, model_name)
)
go

drop view if exists product_reviews_training_data;
go
create or alter view product_reviews_training_data
as
	select	top(select cast(count(*)*.9 as int) from product_reviews)
			cast(pr_review_content as nvarchar(4000)) as pr_review_content
			,case
				when pr_review_rating < 3 then 1 
				when pr_review_rating = 3 then 2 else 3 
			end as tag 
	from	product_reviews;
go

drop view if exists product_reviews_test_data;
go
create or alter view product_reviews_test_data
as 
	select	top(select cast(count(*)*.1 as int) from product_reviews)
			cast(pr_review_content as nvarchar(4000)) as pr_review_content
			,case
				when pr_review_rating < 3 then 1 
				when pr_review_rating = 3 then 2 else 3 
			end as tag 
	from	product_reviews;
go

-- 1 = Negative, 2 = Neutral, 3 = Positive
create or alter proc create_text_classification_model
as
	declare @model varbinary(max), @train_script nvarchar(max);
	
	--The Python script we want to execute
	set @train_script = N'
##Import necessary packages
from microsoftml import rx_logistic_regression, featurize_text, n_gram
import pickle
## Defining the tag column as a categorical type
training_data["tag"] = training_data["tag"].astype("category")

## Create a machine learning model for multiclass text classification. 
## We are using a text featurizer function to split the text in features of 2-word chunks

#ngramLength=2: include not only "Word1", "Word2", but also "Word1 Word2"
#weighting="TfIdf": Term frequency & inverse document frequency
model = rx_logistic_regression(formula = "tag ~ features", data = training_data, method = "multiClass", ml_transforms=[
                        featurize_text(language="English",
                                     cols=dict(features="pr_review_content"),
                                      word_feature_extractor=n_gram(2, weighting="TfIdf"))]) 

## Serialize the model so that we can store it in a table
modelbin = pickle.dumps(model)';

	execute sp_execute_external_script @language = N'Python'
		,@script = @train_script
		,@input_data_1 = N'select * from product_reviews_training_data'
		,@input_data_1_name = N'training_data'
		,@params  = N'@modelbin varbinary(max) OUTPUT' 
		,@modelbin = @model output;
 
	--Save model to DB Table
	delete from models where model_name = 'rx_logistic_regression' and language = 'Python';
	insert into models (language, model_name, model) values('Python', 'rx_logistic_regression', @model);
go
exec create_text_classification_model;
select * from dbo.models;
go

create or alter proc predict_review_sentiment 
as
	declare @model_bin varbinary(max), @prediction_script nvarchar(max);
	select @model_bin = model from dbo.models where model_name = 'rx_logistic_regression' and language = 'Python';
 
	set @prediction_script = N'
from microsoftml import rx_predict
from revoscalepy import rx_data_step 
import pickle

model = pickle.loads(model_bin)
predictions = rx_predict(model = model, data = test_data, extra_vars_to_write = ["pr_review_content"], overwrite = True)

result = rx_data_step(predictions)
## print(result)';
 
	exec sp_execute_external_script @language = N'Python'
		,@script = @prediction_script
		,@input_data_1 = N'select * from product_reviews_test_data'
		,@input_data_1_name = N'test_data'
		,@output_data_1_name = N'result'
		,@params  = N'@model_bin varbinary(max)'
		,@model_bin = @model_bin
	with result sets(("Review" nvarchar(max), "PredictedLabel" float, "Predicted_Score_Negative" float, "Predicted_Score_Neutral" float, "Predicted_Score_Positive" float)); 
go

-- The predicted score of Negative means the statement is (x percent Negative), and so on for the other sentiment categories. 
-- Ie. since there all tag 3 positive, they will have very low negative scores, low neutral scores and very high positive scores. 
exec predict_review_sentiment
go

-- Create new model for realtime_scoring_only.
create or alter proc CreatePyModelRealtimeScoringOnly as
	
	declare @model varbinary(max), @train_script nvarchar(max);
	delete top(1) from models where model_name = 'RevoMMLRealtimeScoring' and language = 'Py';
	
	set @train_script = N'
from microsoftml import rx_logistic_regression, featurize_text, n_gram
from revoscalepy import rx_serialize_model, RxOdbcData, rx_write_object, RxInSqlServer, rx_set_compute_context, RxLocalSeq
#import pickle

connection_string = "Driver=SQL Server;Server=localhost;Database=tpcxbb_1gb;Trusted_Connection=true;"
dest = RxOdbcData(connection_string, table = "models")
 
training_data["tag"] = training_data["tag"].astype("category")

#ngramLength=2: include not only "Word1", "Word2", but also "Word1 Word2"
#weighting="TfIdf": Term frequency & inverse document frequency

modelpy = rx_logistic_regression(formula = "tag ~ features",
								 data = training_data, 
								 method = "multiClass", 
								 ml_transforms=[featurize_text(language="English",
															   cols=dict(features="pr_review_content"),
															   word_feature_extractor=n_gram(2, weighting="TfIdf"))],
								 train_threads=1)

## Serialize and write the model
modelbin = rx_serialize_model(modelpy, realtime_scoring_only = True)
#modelbin = pickle.dumps(model)
rx_write_object(dest, key_name="model_name", key="RevoMMLRealtimeScoring", value_name="model", value=modelbin, serialize=False, compress=None, overwrite=False)'; --overwrite=false on 2019, true on 2017.

	exec sp_execute_external_script @language = N'Python'
		,@script = @train_script
		,@input_data_1 = N'select * from product_reviews_training_data'
		,@input_data_1_name = N'training_data'
go

-- STEP 9 Execute the stored procedure that creates and saves the machine learning model in a table
exec  CreatePyModelRealtimeScoringOnly; --00:01:14.560 desktop, 00:02:40.351 laptop.
--Take a look at the model object saved in the model table
select *, datalength(model) as Datalen from dbo.models; --(6MB w/rx_write_object vs 55MB w/pickle.dump)
GO
-- incase of OutOfMemoryException: https://docs.microsoft.com/sql/advanced-analytics/r/how-to-create-a-resource-pool-for-r?view=sql-server-2017
-- 1. Limit SQL Server memory usage to 60% of the value in the 'max server memory' setting.
-- 2. Increase Limit memory by external processes to 40% of total computer resources. It defaults to 20%.
-- 3. Reconfigure and restart RG to force changes or restart sql svc.
--ALTER RESOURCE POOL "default" WITH (max_memory_percent = 60); --hmmm...maybe not.
--ALTER EXTERNAL RESOURCE POOL "default" WITH (max_memory_percent = 40); --okay
--ALTER RESOURCE GOVERNOR RECONFIGURE;
go
-- STEP 10 Execute the multi class prediction using the realtime_scoring_only model we trained now.
exec uspPredictSentiment @model='RevoMMLRealtimeScoring'
go
/*Msg 39051, Level 16, State 2, Procedure uspPredictSentiment, Line 304
Error occurred during execution of the builtin function 'PREDICT' with HRESULT 0x80070057. Model is corrupt or invalid.

This is currently not supported.
'rx_logistic_regression' is an algorithm from the mml package, not revoscalepy package.
Cannot demo TSQL PREDICT with a model from 'rx_logistic_regression'.
For now batch predictions by calling rx_predict. 
Use another example instead for native scoring. This sample is good for showing PREDICT:
https://github.com/Microsoft/r-server-hospital-length-of-stay
*/
-- Try sp_rxPredict, if missing, enable it: https://docs.microsoft.com/sql/advanced-analytics/r/how-to-do-realtime-scoring?view=sql-server-2017#bkmk_enableRtScoring
sp_configure 'show advanced options', 1;  
reconfigure;
go
sp_configure 'clr enabled', 1;  
reconfigure with override;
go  
alter database tpcxbb_1gb set trustworthy on; 
exec sp_changedbowner @loginame = sa, @map = false;
go
-- Run cmd as admin: EnableRealtimePredictions.cmd
declare @model_bin varbinary(max)=null
select	@model_bin = model from models where model_name = 'RevoMMLRealtimeScoring';
if @model_bin is not null begin
exec sp_rxPredict @model = @model_bin, @inputData = N'select pr_review_content, cast(tag as varchar(1)) as tag from product_reviews_test_data' end;
go --8,999 rows: sp_rxPredict 3-9sec vs python microsoftml rx_predict 11-25sec.
/*
Known issue: sp_rxPredict returns an inaccurate message when a NULL value is passed as the model.

Msg 6522, Level 16, State 1, Procedure sp_rxPredict, Line 334
A .NET Framework error occurred during execution of user-defined routine or aggregate "sp_rxPredict": 
System.InvalidOperationException: Expect a column 'tag' of type: 'String'. Actual type is: 'System.Int32'
System.InvalidOperationException: 
   at Microsoft.MachineLearning.RServerScoring.DataViewAdapter.CheckSame(IEnumerator`1 cols1, IEnumerator`1 cols2)
   at Microsoft.MachineLearning.RServerScoring.DataViewAdapter.Retarget(IDataTable newSource)
   at Microsoft.MachineLearning.RServerScoring.Model.Score(IDataTable inputData)
   at Microsoft.MachineLearning.RServerScoring.Scorer.Score(IModel model, IDataTable inputData, IDictionary`2 scoringParameters, IScoreContext scoreContext)
   at Microsoft.RServer.ScoringLibrary.ScoringHost.ScoreDispatcher.Score(ModelId modelId, IDataTable inputData, IDictionary`2 scoringParameters, IScoreContext scoreContext)
.*/