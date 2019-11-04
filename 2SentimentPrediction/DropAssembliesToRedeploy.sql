select compatibility_level, name from sys.databases
if exists (select distinct 1 from sys.databases where compatibility_level=150)
begin 
	print N'proceed 😀!' --if 150, proceed!
end 
else begin
	print N'rollup your compat, may need to update stats, if comming from < 2016.' 
end

use FleitasArts
-- use tpcxbb_1gb
go
drop procedure if exists sp_rxPredict;

drop assembly if exists [Microsoft.MachineLearning.RServerScoring.Sql]
drop assembly if exists [System.Windows.Forms.DataVisualization]
drop assembly if exists [System.Windows.Forms]
drop assembly if exists Accessibility

drop assembly if exists [Microsoft.CSharp]
drop assembly if exists [Microsoft.RServer.NativeScorer]
drop assembly if exists [Microsoft.RServer.ScoringLibrary.SqlServer]
drop assembly if exists [Microsoft.RServer.ScoringLibrary]

--drop assembly if exists [Microsoft.SqlServer.Types] -- not permitted for system assemblies, only user ones.
drop assembly if exists [System.Runtime.Serialization]
drop assembly if exists [SMDiagnostics]
drop assembly if exists [system.drawing]
drop assembly if exists [System.Dynamic]

drop assembly if exists [System.IO.Compression.FileSystem]
drop assembly if exists [System.IO.Compression]
drop assembly if exists [System.Runtime.Serialization.Formatters.soap]
drop assembly if exists [System.ServiceModel.Internals]

--wohoo!!!
--done!!